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
public func withUncancelledTask<R: Sendable>(
    returning: R.Type = R.self,
    _ body: @Sendable @escaping () async throws -> R
) async throws -> R {
    // This looks unstructured but it isn't, please note that we `await` `.value` of this task.
    // The reason we need this separate `Task` is that in general, we cannot assume that code performs to our
    // expectations if the task we run it on is already cancelled. However, in some cases we need the code to
    // run regardless -- even if our task is already cancelled. Therefore, we create a new, uncancelled task here.
    try await Task {
        try await body()
    }.value
}

public func withUncancelledTask<R: Sendable>(
    returning: R.Type = R.self,
    _ body: @Sendable @escaping () async -> R
) async -> R {
    // This looks unstructured but it isn't, please note that we `await` `.value` of this task.
    // The reason we need this separate `Task` is that in general, we cannot assume that code performs to our
    // expectations if the task we run it on is already cancelled. However, in some cases we need the code to
    // run regardless -- even if our task is already cancelled. Therefore, we create a new, uncancelled task here.
    await Task {
        await body()
    }.value
}
