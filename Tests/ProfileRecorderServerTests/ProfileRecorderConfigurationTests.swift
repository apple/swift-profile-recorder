//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2022-2025 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if compiler(>=6.0) // As swift-testing only ships in the toolchain since 6.0

#if compiler(>=6.2)
import Configuration
#endif
import Logging
import NIOCore
import NIOPosix
import ProfileRecorderServer
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("Profile Recorder Configuration")
struct ProfileRecorderConfigurationTests {

    // MARK: Core Logic

    @Test("Parse UNIX socket")
    func bindTargetUnixSchemeParses() throws {
        let cfg = try ProfileRecorderServerConfiguration.parseBindTarget(
            from: "unix:///tmp/rfservice-profiler.sock",
            pattern: false
        )
        #expect(unixPath(cfg.bindTarget) == "/tmp/rfservice-profiler.sock")
    }

    @Test("Parse percent-encoded UNIX socket")
    func bindTargetHttpUnixSchemeParses() throws {
        let path = "/tmp/rfservice-profiler.sock"
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let cfg = try ProfileRecorderServerConfiguration.parseBindTarget(
            from: "http+unix://\(encoded)",
            pattern: false
        )
        #expect(unixPath(cfg.bindTarget) == path)
    }

    @Test("Parse HTTP TCP bind")
    func bindTargetHttpHostPortParses() throws {
        let cfg = try ProfileRecorderServerConfiguration.parseBindTarget(
            from: "http://127.0.0.1:6060",
            pattern: false
        )
        let parsed = tcpHostPort(cfg.bindTarget)
        #expect(parsed?.0 == "127.0.0.1")
        #expect(parsed?.1 == 6060)
    }

    @Test("Pattern expands {PID} and {UUID}")
    func bindTargetPatternExpansion() throws {
        let cfg = try ProfileRecorderServerConfiguration.parseBindTarget(
            from: "unix:///{PID}-{UUID}.sock",
            pattern: true
        )
        let path = try #require(unixPath(cfg.bindTarget))
        #expect(path.contains("\(getpid())"))
        #expect(path.hasSuffix(".sock"))

        if let dash = path.firstIndex(of: "-"),
            let dot = path.lastIndex(of: "."),
            dash < dot
        {
            let uuidStr = String(path[path.index(after: dash)..<dot])
            #expect(UUID(uuidString: uuidStr) != nil, "Expected valid UUID, got '\(uuidStr)'")
        } else {
            #expect(Bool(false), "Unexpected path format: \(path)")
        }
    }

    @Test("Unsupported scheme throws")
    func bindTargetUnsupportedSchemeThrows() {
        #expect(throws: Error.self) {
            _ = try ProfileRecorderServerConfiguration.parseBindTarget(
                from: "ftp://example.com:21",
                pattern: false
            )
        }
    }

    @Test("Malformed http+unix throws (missing host)")
    func bindTargetMalformedHttpUnixThrows() {
        #expect(throws: Error.self) {
            _ = try ProfileRecorderServerConfiguration.parseBindTarget(
                from: "http+unix://",
                pattern: false
            )
        }
    }

    @Test("Malformed unix throws (missing path)")
    func bindTargetMalformedUnixThrows() {
        #expect(throws: Error.self) {
            _ = try ProfileRecorderServerConfiguration.parseBindTarget(
                from: "unix://",
                pattern: false
            )
        }
    }

    @Test("Empty or nil input yields default")
    func bindTargetEmptyInputReturnsDefault() throws {
        let cfg1 = try ProfileRecorderServerConfiguration.parseBindTarget(from: "", pattern: false)
        let cfg2 = try ProfileRecorderServerConfiguration.parseBindTarget(from: nil, pattern: false)
        #expect(cfg1.bindTarget == nil)
        #expect(cfg2.bindTarget == nil)
    }

    @Test("Http resolution error throws")
    func bindTargetHttpResolutionErrorThrows() {
        #expect(throws: Error.self) {
            _ = try ProfileRecorderServerConfiguration.parseBindTarget(
                from: "http://😄:8080",
                pattern: false
            )
        }
    }

    // MARK: Environment vars

    @Test("Env: direct URL takes precedence over pattern")
    func envDirectBeatsPattern() throws {
        let cfg = try ProfileRecorderServerConfiguration._parseFromEnvironment([
            "PROFILE_RECORDER_SERVER_URL": "unix:///tmp/direct.sock",
            "PROFILE_RECORDER_SERVER_URL_PATTERN": "unix:///{PID}.sock",
        ])
        #expect(unixPath(cfg.bindTarget) == "/tmp/direct.sock")
    }

    @Test("Env: pattern used when direct missing")
    func envPatternUsedWhenDirectMissing() throws {
        let cfg = try ProfileRecorderServerConfiguration._parseFromEnvironment([
            "PROFILE_RECORDER_SERVER_URL_PATTERN": "unix:///{PID}-{UUID}.sock"
        ])
        let path = try #require(unixPath(cfg.bindTarget))
        #expect(path.contains("\(getpid())"))
        #expect(path.hasSuffix(".sock"))
    }

    @Test("Env: defaults when no keys present")
    func envDefaultsWhenNoKeys() throws {
        let cfg = try ProfileRecorderServerConfiguration._parseFromEnvironment([:])
        #expect(cfg.bindTarget == nil)
    }

    // MARK: ConfigReader

    #if compiler(>=6.2)

    @Test("ConfigReader: direct URL key")
    @available(macOS 15, *)
    func configDirectURLKey() async throws {
        let reader = ConfigReader(
            provider: InMemoryProvider(values: [
                ["profile", "recorder", "server", "url"]: .init(stringLiteral: "unix:///tmp/cfg.sock")
            ])
        )
        let cfg = try await ProfileRecorderServerConfiguration.parseFromConfig(reader)
        #expect(unixPath(cfg.bindTarget) == "/tmp/cfg.sock")
    }

    @Test("ConfigReader: pattern key")
    @available(macOS 15, *)
    func configPatternURLKey() async throws {
        let reader = ConfigReader(
            provider: InMemoryProvider(values: [
                ["profile", "recorder", "server", "url", "pattern"]: .init(stringLiteral: "unix:///{PID}-{UUID}.sock")
            ])
        )
        let cfg = try await ProfileRecorderServerConfiguration.parseFromConfig(reader)
        let path = try #require(unixPath(cfg.bindTarget))
        #expect(path.contains("\(getpid())"))
        #expect(path.hasSuffix(".sock"))
    }

    @Test("ConfigReader: direct key takes precedence")
    @available(macOS 15, *)
    func configDirectPrecedenceOverPattern() async throws {
        let reader = ConfigReader(
            provider: InMemoryProvider(values: [
                ["profile", "recorder", "server", "url"]: .init(stringLiteral: "unix:///tmp/direct.cfg.sock"),
                ["profile", "recorder", "server", "url", "pattern"]: .init(stringLiteral: "unix:///{PID}.sock"),
            ])
        )
        let cfg = try await ProfileRecorderServerConfiguration.parseFromConfig(reader)
        #expect(unixPath(cfg.bindTarget) == "/tmp/direct.cfg.sock")
    }

    @Test("ConfigReader: defaults when neither key present")
    @available(macOS 15, *)
    func configDefaultsWhenMissingKeys() async throws {
        let reader = ConfigReader(provider: InMemoryProvider(values: [:]))
        let cfg = try await ProfileRecorderServerConfiguration.parseFromConfig(reader)
        #expect(cfg.bindTarget == nil)
    }

    #endif

    private func unixPath(_ addr: SocketAddress?) -> String? {
        guard let addr, case .unixDomainSocket(let path) = addr else { return nil }
        return withUnsafeBytes(of: path.address.sun_path) { raw in
            let u8 = raw.prefix { $0 != 0 } // until first '\0'
            return String(decoding: u8, as: UTF8.self)
        }
    }

    private func tcpHostPort(_ addr: SocketAddress?) -> (String, Int)? {
        guard let a = addr, let host = a.ipAddress, let port = a.port else { return nil }
        return (host, port)
    }
}

#endif
