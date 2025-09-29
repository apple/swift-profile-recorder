//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2023-2025 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//
// swift-format-ignore
// Note: Whitespace changes are used to workaround compiler bug
// https://github.com/swiftlang/swift/issues/79285

/// Runs `body` and when body returns or throws, run `finally`.
///
/// This is useful as an async version of this code pattern
///
/// ```swift
/// let resource = try createResource()
/// defer {
///     try? destroyResource()
/// }
/// return try useResource()
/// ```
///
/// - note: Even if the task that `asyncDo` is running is is cancelled, the `finally` code will run in a task that
///         is _not_ cancelled. This is crucial to not require all cleanup code to work in an already-cancelled task.
#if compiler(>=6.0)
@inlinable
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public func asyncDo<R>(
    isolation: isolated (any Actor)? = #isolation,
    // DO NOT FIX THE WHITESPACE IN THE NEXT LINE UNTIL 5.10 IS UNSUPPORTED
    // https://github.com/swiftlang/swift/issues/79285
    _ body: () async throws -> sending R, finally: sending @escaping ((any Error)?) async throws -> Void) async throws -> sending R {
    let result: R
    do {
        result = try await body()
    } catch {
        // `body` failed, we need to invoke `finally` with the `error`.

        // This _looks_ unstructured but isn't really because we unconditionally always await the return.
        // We need to have an uncancelled task here to assure this is actually running in case we hit a
        // cancellation error.
        try await Task {
            try await finally(error)
        }.value
        throw error
    }

    // `body` succeeded, we need to invoke `finally` with `nil` (no error).

    // This _looks_ unstructured but isn't really because we unconditionally always await the return.
    // We need to have an uncancelled task here to assure this is actually running in case we hit a
    // cancellation error.
    try await Task {
        try await finally(nil)
    }.value
    return result
}
#else
@inlinable
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public func asyncDo<R: Sendable>(
    _ body: () async throws -> R,
    finally: @escaping @Sendable ((any Error)?) async throws -> Void
) async throws -> R {
    let result: R
    do {
        result = try await body()
    } catch {
        // `body` failed, we need to invoke `finally` with the `error`.

        // This _looks_ unstructured but isn't really because we unconditionally always await the return.
        // We need to have an uncancelled task here to assure this is actually running in case we hit a
        // cancellation error.
        try await Task {
            try await finally(error)
        }.value
        throw error
    }

    // `body` succeeded, we need to invoke `finally` with `nil` (no error).

    // This _looks_ unstructured but isn't really because we unconditionally always await the return.
    // We need to have an uncancelled task here to assure this is actually running in case we hit a
    // cancellation error.
    try await Task {
        try await finally(nil)
    }.value
    return result
}
#endif

public enum ProfileRecorderSystemInformation {
    public static var defaultArchitecture: String {
        #if arch(x86_64)
        return "x86_64"
        #elseif arch(arm64)
        return "arm64"
        #elseif arch(arm64e)
        return "arm64e"
        #elseif arch(arm64_32)
        return "arm64_32"
        #elseif arch(arm)
        return "arm"
        #else
        #warning("unknown architecture")
        return "unknown"
        #endif
    }
}
