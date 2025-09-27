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
import AsyncHTTPClient
import Logging
import NIO
import ProfileRecorderServer
import XCTest

final class ProfileRecorderServerTests: XCTestCase {
    func testDefaultSampleRouteWorks() async throws {
        let server = ProfileRecorderServer(
            configuration: try ProfileRecorderServerConfiguration.makeTCPListener(host: "127.0.0.1", port: 0)
        )
        try await server.withProfileRecordingServer(logger: Logger(label: "")) { server in
            guard case .successful(let serverAddress) = server.startResult else {
                XCTFail("failed to start server")
                return
            }

            let response1 = try await HTTPClient.shared.post(
                url: "http://127.0.0.1:\(serverAddress.port!)/",
                body: .string(#"{"numberOfSamples":1,"timeInterval":"10 ms"}"#)
            ).get()
            XCTAssertEqual(.ok, response1.status)
            let body = response1.body.map { String(buffer: $0) }
            XCTAssert(body?.contains("NIO") ?? false, "\(body.debugDescription)")
        }
    }

    func testSampleRouteWorks() async throws {
        let server = ProfileRecorderServer(
            configuration: try ProfileRecorderServerConfiguration.makeTCPListener(host: "127.0.0.1", port: 0)
        )
        try await server.withProfileRecordingServer(logger: Logger(label: "")) { server in
            guard case .successful(let serverAddress) = server.startResult else {
                XCTFail("failed to start server")
                return
            }

            let response1 = try await HTTPClient.shared.post(
                url: "http://127.0.0.1:\(serverAddress.port!)/sample",
                body: .string(#"{"numberOfSamples":1,"timeInterval":"10 ms"}"#)
            ).get()
            XCTAssertEqual(.ok, response1.status)
            let body = response1.body.map { String(buffer: $0) }
            XCTAssert(body?.contains("NIO") ?? false, "\(body.debugDescription)")
        }
    }

    func testUserExtraHandlerBasic() async throws {
        let server = ProfileRecorderServer(
            configuration: try ProfileRecorderServerConfiguration.makeTCPListener(host: "127.0.0.1", port: 0)
        )
        server._registerExtraRouteHandler(
            verb: .GET,
            matchingSlugs: [["hello"]],
            .makeSimple { request, context in
                return .init(
                    head: .init(version: request.head.version, status: .ok),
                    body: ByteBuffer(string: "world")
                )
        })
        server._registerExtraRouteHandler(
            verb: .POST,
            matchingSlugs: [["post"]],
            .makeSimple { request, context in
                return .init(
                    head: .init(version: request.head.version, status: .ok),
                    body: ByteBuffer(string: "post")
                )
        })
        server._registerExtraRouteHandler(
            verb: .GET,
            matchingSlugs: [["clash", "on", "this", "slug"]],
            .makeSimple { request, context in
                return nil // can't be bothered
        })
        server._registerExtraRouteHandler(
            verb: .GET,
            matchingSlugs: [["clash", "on", "this", "slug"], ["no", "clash"]],
            .makeSimple { request, context in
                return .init(
                    head: .init(version: request.head.version, status: .ok),
                    body: ByteBuffer(string: "hi")
                )
        })
        try await server.withProfileRecordingServer(logger: Logger(label: "")) { server in
            guard case .successful(let serverAddress) = server.startResult else {
                XCTFail("failed to start server")
                return
            }

            let response1 = try await HTTPClient.shared.get(
                url: "http://127.0.0.1:\(serverAddress.port!)/hello"
            ).get()
            XCTAssertEqual(.ok, response1.status)
            XCTAssertEqual(ByteBuffer(string: "world"), response1.body)

            let response2 = try await HTTPClient.shared.get(
                url: "http://127.0.0.1:\(serverAddress.port!)/clash/on/this/slug"
            ).get()
            XCTAssertEqual(.ok, response2.status)
            XCTAssertEqual(ByteBuffer(string: "hi"), response2.body)

            let response3 = try await HTTPClient.shared.get(
                url: "http://127.0.0.1:\(serverAddress.port!)/no/clash"
            ).get()
            XCTAssertEqual(.ok, response3.status)
            XCTAssertEqual(ByteBuffer(string: "hi"), response3.body)

            let response4 = try await HTTPClient.shared.get(
                url: "http://127.0.0.1:\(serverAddress.port!)/not/found"
            ).get()
            XCTAssertEqual(.notFound, response4.status)

            let response5 = try await HTTPClient.shared.post(
                url: "http://127.0.0.1:\(serverAddress.port!)/post"
            ).get()
            XCTAssertEqual(.ok, response5.status)
            XCTAssertEqual(ByteBuffer(string: "post"), response5.body)
        }
    }
}
