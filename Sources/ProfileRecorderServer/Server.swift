//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
import NIOHTTP1
import ProfileRecorder
import ProfileRecorderSampleConversion
import ProfileRecorderHelpers
import _NIOFileSystem
import Foundation
import NIOFoundationCompat
import NIOConcurrencyHelpers
import Logging

typealias ProfileRecorderServerRouteHandler = _ProfileRecorderServerRouteHandler

public struct _ProfileRecorderServerRouteHandler: Sendable {
    public struct Context: Sendable {
        public var symbolizer: (any Symbolizer)
        public var logger: Logger
    }

    enum UnderlyingHandler: Sendable {
        case simple(@Sendable (NIOHTTPServerRequestFull, Context) async -> NIOHTTPClientResponseFull?)
    }

    var underlyingHandler: UnderlyingHandler

    public static func makeSimple(
        _ handler: @Sendable @escaping (NIOHTTPServerRequestFull, Context) async -> NIOHTTPClientResponseFull?
    ) -> Self {
        return Self(underlyingHandler: .simple(handler))
    }

    func handle(
        request: NIOHTTPServerRequestFull,
        responseWriter: NIOAsyncChannelOutboundWriter<HTTPPart<HTTPResponseHead, ByteBuffer>>,
        symbolizer: any Symbolizer,
        logger: Logger
    ) async throws -> Bool {
        let context = Context(symbolizer: symbolizer, logger: logger)

        switch self.underlyingHandler {
        case .simple(let handler):
            if var response = await handler(request, context) {
                response.head.headers.replaceOrAdd(name: "connection", value: "close")
                try await responseWriter.write(.head(response.head))
                if let body = response.body {
                    try await responseWriter.write(.body(body))
                }
                try await responseWriter.write(.end(nil))
                return true
            } else {
                return false
            }
        }
    }
}

internal struct ServerRouteHandler: Sendable {
    var uuid: UUID
    var verb: HTTPMethod
    var userHandler: ProfileRecorderServerRouteHandler
    var matchingRoutes: [[String]]
}

/// The configuration for the in-process profile recording server.
public struct ProfileRecorderServerConfiguration: Sendable {
    /// The event loop group for the profile recording server.
    public var group: MultiThreadedEventLoopGroup
    /// The IP address and port bound for the profile recording server.
    public var bindTarget: Optional<SocketAddress>
    internal var unixDomainSocketPath: Optional<String>
    internal let pprofRootSlug = ["debug"]

    /// The default configuration for a profile recording server.
    public static var `default`: Self {
        return ProfileRecorderServerConfiguration(
            group: .singletonMultiThreadedEventLoopGroup,
            bindTarget: nil,
            unixDomainSocketPath: nil
        )
    }

    /// Creates a configuration
    /// - Parameters:
    ///   - host: The IP address to bind for providing traces.
    ///   - port: The port to use for providing traces.
    ///   - group: The event loop group to use for the profile recording server.
    /// - Returns: <#description#>
    public static func makeTCPListener(
        host: String,
        port: Int,
        group: MultiThreadedEventLoopGroup = .singletonMultiThreadedEventLoopGroup
    ) throws -> Self {
        return Self(
            group: group,
            bindTarget: try SocketAddress(ipAddress: host, port: port),
            unixDomainSocketPath: nil
        )
    }

    /// Returns the configuration parsed from environment variables.
    ///
    /// Checks for the environment variables `PROFILE_RECORDER_SERVER_URL` for a URL with a socket and port,
    /// or `PROFILE_RECORDER_SERVER_URL_PATTERN` to provide a UNIX domain socket over which to read the samples.
    public static func parseFromEnvironment() async throws -> Self {
        let serverURLString: String

        if let string = ProcessInfo.processInfo.environment["PROFILE_RECORDER_SERVER_URL"], !string.isEmpty {
            serverURLString = string
        } else if let string = ProcessInfo.processInfo.environment["PROFILE_RECORDER_SERVER_URL_PATTERN"],
            !string.isEmpty
        {
            serverURLString =
                string
                .replacingOccurrences(of: "{PID}", with: "\(getpid())")
                .replacingOccurrences(of: "{UUID}", with: "\(UUID().uuidString)")
        } else {
            return Self(group: .singleton, bindTarget: nil, unixDomainSocketPath: nil)
        }
        let serverURL = URL(string: serverURLString)
        let bindTarget: SocketAddress
        switch serverURL?.scheme {
        case "http":
            bindTarget = try SocketAddress.makeAddressResolvingHost(
                serverURL?.host ?? "127.0.0.1",
                port: serverURL?.port ?? 0
            )
        case "http+unix":
            guard let path = serverURL?.host?.removingPercentEncoding, path.count > 0 else {
                throw ProfileRecorderServer.Error(
                    message: "need UNIX Domain Socket path in host for \(serverURLString)"
                )
            }
            bindTarget = try SocketAddress(unixDomainSocketPath: path)
        case "unix":
            guard let path = serverURL?.path.removingPercentEncoding, path.count > 0 else {
                throw ProfileRecorderServer.Error(
                    message: "need UNIX Domain Socket path in path for \(serverURLString)"
                )
            }
            bindTarget = try SocketAddress(unixDomainSocketPath: path)
        default:
            throw ProfileRecorderServer.Error(message: "unsupported scheme in \(serverURLString)")
        }

        return Self(group: .singleton, bindTarget: bindTarget, unixDomainSocketPath: nil)
    }
}

/// A profile recording server that provides performance traces for your app.
public struct ProfileRecorderServer: Sendable {
    typealias Outbound = NIOAsyncChannelOutboundWriter<HTTPPart<HTTPResponseHead, ByteBuffer>>

    /// The configuration for the profile recording server.
    public let configuration: ProfileRecorderServerConfiguration
    private let state: NIOLockedValueBox<State> = NIOLockedValueBox(State())

    struct State: Sendable {
        var extraRouteHandlers: [(UUID, ServerRouteHandler)] = []
    }

    @_documentation(visibility: internal)
    public struct Error: Swift.Error {
        var message: String
    }

    /// The state of the profile recording server.
    public struct ServerInfo: Sendable {
        /// The result states from starting a profile recording server.
        public enum ServerStartResult: Sendable {
            /// The profile recording server hasn't yet been started.
            case notAttemptedToStartProfileRecordingServer
            /// The service started.
            case successful(SocketAddress)
            /// The service didn't start.
            case couldNotStart(any Swift.Error)
        }
        /// The result of starting the profile recording server.
        public var startResult: ServerStartResult
    }

    /// Creates a profile recording server with the configuration you provide.
    /// - Parameter configuration: <#configuration description#>
    public init(configuration: ProfileRecorderServerConfiguration) {
        self.configuration = configuration
    }

    @discardableResult
    public func _registerExtraRouteHandler(
        verb: HTTPMethod,
        matchingSlugs: [[String]],
        _ handler: _ProfileRecorderServerRouteHandler
    ) -> UUID {
        return self.state.withLockedValue { state in
            let uuid = UUID()
            state.extraRouteHandlers.append(
                (
                    uuid,
                    ServerRouteHandler(
                        uuid: uuid,
                        verb: verb,
                        userHandler: handler,
                        matchingRoutes: matchingSlugs
                    )
                )
            )
            return uuid
        }
    }

    @discardableResult
    public func _deregisterExtraRouteHandler(uuid: UUID) -> Bool {
        self.state.withLockedValue { state in
            state.extraRouteHandlers.removeAll { $0.0 == uuid }
        }
        return true
    }

    /// Runs the profile recording server.
    ///
    /// - warning: Make sure it's only reachable to users that you want to be able to sample your program. NEVER make it available on the internet.
    /// - Parameter logger: The logger instance to use for log messages.
    public func run(logger: Logger) async throws {
        try await self.withProfileRecordingServer(logger: logger) { info in
            switch info.startResult {
            case .couldNotStart(let error):
                logger.warning(
                    "could not start Swift Profile Recorder profile recording server",
                    metadata: ["error": "\(error)"]
                )
                throw error
            case .notAttemptedToStartProfileRecordingServer:
                logger.debug(
                    "profile recorder server start not requested via PROFILE_RECORDER_SERVER_URL env var",
                    metadata: ["example": "PROFILE_RECORDER_SERVER_URL=http://127.0.0.1:12345"]
                )
                return
            case .successful:
                ()
            }
            logger.info("profile recorder server up and running", metadata: ["info": "\(info)"])

            // Sleep until we're cancelled
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000_000)
            }
        }
    }

    /// Runs the profile recording server and ignore any failures.
    ///
    /// For this use case, it's recommended to ignore failures because profile recording is usually not your program's core functionality.
    ///
    /// - warning: Make sure it's only reachable to users that you want to be able to sample your program. NEVER make it available on the internet.
    /// - Parameter logger: The logger instance to use for log messages.
    public func runIgnoringFailures(logger: Logger) async {
        do {
            try await self.run(logger: logger)
        } catch {
            logger.info("profile recorder hit an error, continuing regardless", metadata: ["error": "\(error)"])
        }
    }

    /// Starts the profile recording server, providing a state of the server to the closure that you provide.
    /// - Parameters:
    ///   - logger: The logger instance to use for log messages.
    ///   - body: A closure with access to the state of the profile recording server.
    /// - Returns: The result of the closure you provide.
    public func withProfileRecordingServer<R: Sendable>(
        logger: Logger,
        _ body: @Sendable @escaping (ServerInfo) async throws -> R
    ) async throws -> R {
        guard let bindTarget = self.configuration.bindTarget else {
            return try await body(ServerInfo(startResult: .notAttemptedToStartProfileRecordingServer))
        }
        let serverChannel:
            NIOAsyncChannel<NIOAsyncChannel<NIOHTTPServerRequestFull, HTTPPart<HTTPResponseHead, ByteBuffer>>, Never>
        do {
            serverChannel = try await ServerBootstrap(group: self.configuration.group)
                .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
                .bind(
                    to: bindTarget,
                    childChannelInitializer: { channel in
                        do {
                            try channel.pipeline.syncOperations.configureHTTPServerPipeline()
                            try channel.pipeline.syncOperations.addHandlers(
                                NIOHTTPServerRequestAggregator(maxContentLength: 1024),
                                HTTPByteBufferResponsePartHandler()
                            )
                            return channel.eventLoop.makeSucceededFuture(
                                try NIOAsyncChannel<NIOHTTPServerRequestFull, HTTPPart<HTTPResponseHead, ByteBuffer>>(
                                    wrappingChannelSynchronously: channel
                                )
                            )
                        } catch {
                            return channel.eventLoop.makeFailedFuture(error)
                        }
                    }
                )
        } catch {
            logger.info(
                "failed to bind Swift Profile Recorder profile recording server",
                metadata: ["error": "\(error)"]
            )
            return try await (body(ServerInfo(startResult: .couldNotStart(error))))
        }

        let symbolizer = ProfileRecorderSampler._makeDefaultSymbolizer()
        try symbolizer.start()
        defer {
            try! symbolizer.shutdown()
        }

        return try await asyncDo {
            return try await serverChannel.executeThenClose { server in
                return try await withThrowingTaskGroup(of: R?.self) { group in
                    group.addTask {
                        return try await body(ServerInfo(startResult: .successful(serverChannel.channel.localAddress!)))
                    }
                    group.addTask {
                        await withTaskGroup(of: Void.self) { childGroup in
                            do {
                                for try await child in server {
                                    childGroup.addTask {
                                        var logger = logger
                                        logger[metadataKey: "peer"] = "\(child.channel.remoteAddress!)"
                                        do {
                                            logger.info("profile recorder server connection received")
                                            try await child.executeThenClose {
                                                inbound,
                                                outbound in
                                                for try await request in inbound {
                                                    logger.info(
                                                        "profile recorder server request",
                                                        metadata: ["request": "\(request)"]
                                                    )

                                                    try await handleRequest(
                                                        request,
                                                        outbound: outbound,
                                                        symbolizer: symbolizer,
                                                        logger: logger
                                                    )
                                                }
                                                outbound.finish()
                                            }
                                        } catch {
                                            logger.info(
                                                "failure whilst handling samples",
                                                metadata: ["error": "\(error)"]
                                            )
                                        }
                                    }
                                }
                                await childGroup.waitForAll()
                            } catch {
                                logger.debug(
                                    "profile recorder server failure or cancellation",
                                    metadata: ["error": "\(error)"]
                                )
                                guard error is CancellationError else {
                                    logger.info(
                                        "profile recorder server failure",
                                        metadata: ["error": "\(error)"]
                                    )
                                    return
                                }
                            }
                        }
                        return nil
                    }
                    defer {
                        group.cancelAll()
                    }
                    while let result = try await group.next() {
                        if let actualResult = result {
                            return actualResult
                        } else {
                            continue
                        }
                    }
                    fatalError("unreachable")
                }
            }
        } finally: { _ in
            if let udsPath = configuration.unixDomainSocketPath {
                _ = try? await FileSystem.shared.removeItem(at: FilePath(udsPath))
            }
        }
    }

    func respondWithFailure(string: String, code: HTTPResponseStatus, _ outbound: Outbound) async throws {
        try await outbound.write(
            .head(
                HTTPResponseHead(
                    version: .http1_1,
                    status: code,
                    headers: ["connection": "close"]
                )
            )
        )
        try await outbound.write(.body(ByteBuffer(string: string)))
        try await outbound.write(.body(ByteBuffer(string: "\n")))
        try await outbound.write(.end(nil))
    }

    func sendNotFoundErrorWithExplainer(_ outbound: Outbound) async throws {
        let example = SampleRequest(
            numberOfSamples: 100,
            timeInterval: TimeAmount.milliseconds(100),
            format: .perfSymbolized,
            symbolizer: .native
        )
        let exampleEncoded = String(decoding: try! JSONEncoder().encode(example), as: UTF8.self)
        let exampleURL: String
        var exampleCURLArgs: [String] = []
        let bindTarget = self.configuration.bindTarget! // will work, we received a request on it!
        switch bindTarget {
        case .v4:
            let ipAddress = bindTarget.ipAddress! // IPv4 has IP addresses
            guard ipAddress != "0.0.0.0" else {
                exampleURL = "http://127.0.0.1:\(bindTarget.port!)/sample"
                break
            }
            exampleURL = "http://\(ipAddress):\(bindTarget.port!)/sample"
        case .v6:
            let ipAddress = bindTarget.ipAddress! // IPv6 has IP addresses
            guard ipAddress != "::" else {
                exampleURL = "http://[::1]:\(bindTarget.port!)/sample"
                break
            }
            exampleURL = "http://\(ipAddress):\(bindTarget.port!)/sample"
        case .unixDomainSocket:
            let udsPath = bindTarget.pathname!
            exampleURL = "http+unix://\(udsPath.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)/sample"
            exampleCURLArgs.append(contentsOf: ["--unix-socket", udsPath, "http://127.0.0.1/sample"])
        }

        if exampleCURLArgs.isEmpty {
            exampleCURLArgs.append(contentsOf: [exampleURL])
        }
        exampleCURLArgs.insert(contentsOf: ["-s", "-d", "'" + exampleEncoded + "'"], at: 0)
        try await self.respondWithFailure(
            string: """
                # Welcome to the Swift Profile Recorder Server!

                To request samples, please send POST request to \(exampleURL)

                ## Details

                URL: \(exampleURL)
                Is this a supported platform? \(ProfileRecorderSampler.isSupportedPlatform ? "yes" : "no")

                ## Examples

                Example body: \(exampleEncoded)

                If you're using curl, you could run

                ```
                curl \(exampleCURLArgs.joined(separator: " ")) > /tmp/samples.perf
                ```

                To also immediately demangle the symbols, run

                ```
                curl \(exampleCURLArgs.joined(separator: " ")) | swift demangle --simplified > /tmp/samples.perf
                ```

                Once you have `/tmp/samples.perf`, you can then visualise it.


                ## Visualisation

                ### FlameGraphs

                Repository: https://github.com/brendangregg/Flamegraph

                ```
                FlameGraph/stackcollapse-perf.pl < /tmp/samples.perf | FlameGraph/flamegraph.pl > /tmp/samples.svg
                open /tmp/samples.svg
                ```

                ### Firefox Profiler (https://profiler.firefox.com):

                How to use it?

                1. Open https://profiler.firefox.com and drag /tmp/samples.svg onto it.
                2. Click "Show all tracks" in "tracks" menu on the top left
                3. Slightly further down, select the first thread (track), hold Shift and select the last thread.
                4. Open the "Flame Graph" tab

                ### Other options

                Check https://profilerpedia.markhansen.co.nz/formats/linux-perf-script/#converts-to-transitive for
                a list of visualisation options for the "Linux perf script" format that Swift Profile Recorder produces.

                """,
            code: .notFound,
            outbound
        )
    }

    struct DecodedURL: Sendable {
        var components: [String]
        var queryParams: [String: String?]
    }

    func decodeURI(_ uri: String) -> DecodedURL? {
        guard let url = URL(string: "http://127.0.0.1:6060" + uri) else {
            return nil
        }
        let components = url.path.split(separator: "/")
        let kvPairs: [(String, String?)] =
            url.query?
            .split(separator: "&")
            .compactMap { (queryItem: Substring) -> (String, String?)? in
                let kv = queryItem.split(separator: "=", maxSplits: 1)
                guard let key = kv.first else {
                    // no key or value
                    return nil
                }
                assert(kv.count < 3, "max spilt 1 of lead to \(kv)")
                return (String(key), kv.dropFirst().first.map { String($0) })
            } ?? []
        return DecodedURL(
            components: components.map(String.init),
            queryParams: Dictionary(kvPairs, uniquingKeysWith: { l, r in r })
        )
    }

    func handleRequest(
        _ request: NIOHTTPServerRequestFull,
        outbound: NIOAsyncChannelOutboundWriter<HTTPPart<HTTPResponseHead, ByteBuffer>>,
        symbolizer: any Symbolizer,
        logger: Logger
    ) async throws {
        do {
            let sampleRequest: SampleRequest
            switch (request.head.method, self.decodeURI(request.head.uri)) {
            case (.GET, .some(let decodedURI))
            where decodedURI.components.matches(
                prefix: self.configuration.pprofRootSlug,
                oneOfPaths: [["pprof", "profile"], ["pprof", "symbolizer=fake", "profile"]]
            ) != nil:
                let seconds = (Int(decodedURI.queryParams["seconds"].flatMap { $0 } ?? "not set") ?? 30)
                    .clamping(to: 0...1000) // 30 s seems to be Golang's default
                let symbolizerKind =
                    decodedURI.queryParams["symbolizer"].flatMap { kind in
                        ProfileRecorderSymbolizerKind(rawValue: kind ?? "n/a")
                    } ?? (decodedURI.components.contains("symbolizer=fake") ? .fake : .native)
                let sampleRate = 100.clamping(to: 0...1000) // 100 Hz, seems to be Golang's default
                let numberOfSamples = seconds * sampleRate
                let timeIntervalBetweenSamplesMS = (1000 / sampleRate).clamping(to: 1...100_000)

                sampleRequest = SampleRequest(
                    numberOfSamples: numberOfSamples,
                    timeInterval: .milliseconds(Int64(timeIntervalBetweenSamplesMS)),
                    format: .pprofSymbolized,
                    symbolizer: symbolizerKind
                )
            case (.POST, .some(let decodedURI))
            where decodedURI.components.isEmpty
                || decodedURI.components.matches(
                    prefix: [],
                    oneOfPaths: [["sample"], ["samples"]]
                ) != nil:
                // Native Swift Profile Recorder Sampling server
                sampleRequest = try JSONDecoder().decode(SampleRequest.self, from: request.body ?? ByteBuffer())
            case (let verb, .some(let decodedURI)):
                let extraRouteHandlers = self.state.withLockedValue { state in
                    state.extraRouteHandlers
                }

                for (_, handler) in extraRouteHandlers {
                    guard handler.verb == verb else {
                        continue
                    }
                    if decodedURI.components.matches(oneOfPaths: handler.matchingRoutes) != nil {
                        let handled = try await handler.userHandler.handle(
                            request: request,
                            responseWriter: outbound,
                            symbolizer: symbolizer,
                            logger: logger
                        )
                        if handled {
                            return
                        }
                    }
                }
                try await self.sendNotFoundErrorWithExplainer(outbound)
                return
            default:
                try await self.sendNotFoundErrorWithExplainer(outbound)
                return
            }
            try await ProfileRecorderSampler.sharedInstance._withSamples(
                sampleCount: sampleRequest.numberOfSamples,
                timeBetweenSamples: sampleRequest.timeInterval,
                format: sampleRequest.format,
                symbolizer: sampleRequest.symbolizer == .native ? symbolizer : _ProfileRecorderFakeSymbolizer(),
                logger: logger
            ) { samples in
                try await FileSystem.shared.withFileHandle(forReadingAt: FilePath(samples)) { handle in
                    try await outbound.write(
                        .head(
                            HTTPResponseHead(
                                version: .http1_1,
                                status: .ok,
                                headers: [
                                    "connection": "close",
                                    "content-disposition": "filename=\"samples-\(getpid())-\(time(nil)).perf\"",
                                    "content-type": "application/octet-stream",
                                ]
                            )
                        )
                    )
                    var reader = handle.bufferedReader()
                    while true {
                        let chunk = try await reader.read(.mebibytes(4))
                        guard chunk.readableBytes > 0 else { break }
                        do {
                            try await outbound.write(.body(chunk))
                        } catch {
                            break
                        }
                    }
                    try? await outbound.write(.end(nil))
                }
            }
        } catch {
            try await self.respondWithFailure(string: "\(error)", code: .internalServerError, outbound)
            return
        }
    }
}

enum ProfileRecorderSymbolizerKind: String, Sendable & Codable {
    case native
    case fake
}

struct SampleRequest: Sendable & Codable {
    var numberOfSamples: Int
    var timeInterval: TimeAmount
    var format: ProfileRecorderOutputFormat
    var symbolizer: ProfileRecorderSymbolizerKind

    typealias SampleFormat = ProfileRecorderOutputFormat

    private enum CodingKeys: CodingKey {
        case numberOfSamples
        case timeInterval
        case format
        case symbolizer
    }

    internal init(
        numberOfSamples: Int,
        timeInterval: TimeAmount,
        format: SampleFormat,
        symbolizer: ProfileRecorderSymbolizerKind
    ) {
        self.numberOfSamples = numberOfSamples
        self.timeInterval = timeInterval
        self.format = format
        self.symbolizer = symbolizer
    }

    init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<SampleRequest.CodingKeys> = try decoder.container(
            keyedBy: SampleRequest.CodingKeys.self
        )

        self.numberOfSamples = try container.decode(Int.self, forKey: SampleRequest.CodingKeys.numberOfSamples)
        let timeIntervalString = try container.decode(String.self, forKey: SampleRequest.CodingKeys.timeInterval)
        self.timeInterval = try TimeAmount(timeIntervalString, defaultUnit: "ms")
        self.format = try container.decodeIfPresent(SampleFormat.self, forKey: .format) ?? .perfSymbolized
        self.symbolizer =
            try container.decodeIfPresent(ProfileRecorderSymbolizerKind.self, forKey: .symbolizer) ?? .native
    }

    func encode(to encoder: any Encoder) throws {
        var container: KeyedEncodingContainer<SampleRequest.CodingKeys> = encoder.container(
            keyedBy: SampleRequest.CodingKeys.self
        )

        try container.encode(self.numberOfSamples, forKey: SampleRequest.CodingKeys.numberOfSamples)
        try container.encode(self.timeInterval.prettyPrint, forKey: SampleRequest.CodingKeys.timeInterval)
        if self.format != .perfSymbolized {
            try container.encode(self.format, forKey: .format)
        }
        if self.symbolizer != .native {
            try container.encode(self.symbolizer, forKey: .symbolizer)
        }
    }
}

final class HTTPByteBufferResponsePartHandler: ChannelOutboundHandler {
    typealias OutboundIn = HTTPPart<HTTPResponseHead, ByteBuffer>
    typealias OutboundOut = HTTPServerResponsePart

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let part = self.unwrapOutboundIn(data)
        switch part {
        case .head(let head):
            context.write(self.wrapOutboundOut(.head(head)), promise: promise)
        case .body(let buffer):
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: promise)
        case .end(let trailers):
            context.write(self.wrapOutboundOut(.end(trailers)), promise: promise)
        }
    }
}

struct TimeAmountConversionError: Error {
    var message: String
}

extension TimeAmount {
    init(_ userProvidedString: String, defaultUnit: String) throws {
        let string = String(userProvidedString.filter { !$0.isWhitespace }).lowercased()
        let parsedNumbers = string.prefix(while: { $0.isWholeNumber || $0.isPunctuation })
        let parsedUnit = string.dropFirst(parsedNumbers.count)

        guard let numbers = Int64(parsedNumbers) else {
            throw TimeAmountConversionError(message: "'\(userProvidedString)' cannot be parsed as number and unit")
        }
        let unit = parsedUnit.isEmpty ? defaultUnit : String(parsedUnit)

        switch unit {
        case "h", "hr":
            self = .hours(numbers)
        case "min":
            self = .minutes(numbers)
        case "s":
            self = .seconds(numbers)
        case "ms":
            self = .milliseconds(numbers)
        case "us":
            self = .microseconds(numbers)
        case "ns":
            self = .nanoseconds(numbers)
        default:
            throw TimeAmountConversionError(message: "Unknown unit '\(unit)' in '\(userProvidedString)")
        }
    }

    var prettyPrint: String {
        let fullNS = self.nanoseconds
        let (fullUS, remUS) = fullNS.quotientAndRemainder(dividingBy: 1_000)
        let (fullMS, remMS) = fullNS.quotientAndRemainder(dividingBy: 1_000_000)
        let (fullS, remS) = fullNS.quotientAndRemainder(dividingBy: 1_000_000_000)

        if remS == 0 {
            return "\(fullS) s"
        } else if remMS == 0 {
            return "\(fullMS) ms"
        } else if remUS == 0 {
            return "\(fullUS) us"
        } else {
            return "\(fullNS) ns"
        }
    }
}

extension Array where Element == String {
    func matches(prefix: [String] = [], oneOfPaths possiblePaths: [[String]]) -> [String]? {
        guard self.starts(with: prefix) else {
            return nil
        }
        let remainder = Array(self.dropFirst(prefix.count))

        for path in possiblePaths {
            if let match = remainder.matches(path) {
                return match
            }
        }

        return nil
    }

    func matches(prefix: [String] = [], _ path: [String]) -> [String]? {
        guard self.starts(with: prefix) else {
            return nil
        }
        let remainder = self.dropFirst(prefix.count)
        if remainder == path[...] {
            return path
        } else {
            return nil
        }
    }
}

extension BinaryInteger {
    func clamping(to: ClosedRange<Self>) -> Self {
        if self < to.lowerBound {
            return to.lowerBound
        }
        if self > to.upperBound {
            return to.upperBound
        }
        return self
    }
}
