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

struct SampleAggregator: Sendable {
    struct Location: Sendable {
        var id: Int
        var address: UInt
        var functions: [Int]
    }

    struct Function: Sendable & HasID {
        var id: Int
        var name: String

        init(id: Int, name: String) {
            self.id = id
            self.name = name
        }

        init(id: Int, value: String) {
            self = .init(id: id, name: value)
        }

        var value: String {
            return self.name
        }

        func updatingID(_ newID: Int) -> Self {
            var new = self
            new.id = newID
            return new
        }
    }

    struct ThreadInfo: Sendable, Hashable {
        var tid: Int
        var name: String
    }

    struct SampleKey: Sendable, Hashable {
        var locationIDs: [Int]
        var threadInfo: ThreadInfo
    }

    var locations: [UInt: Location] = [:]
    var functions: [String: Function] = [:]
    var samples: [SampleKey: Int] = [:]

    mutating func add(_ sample: [SymbolisedStackFrame], threadInfo: ThreadInfo) {
        let locationIDs = self.resolveLocationIDs(sample)
        let key = SampleKey(locationIDs: locationIDs, threadInfo: threadInfo)
        self.samples[key, default: 0] += 1
    }

    private mutating func resolveLocationIDs(_ sample: [SymbolisedStackFrame]) -> [Int] {
        return sample.compactMap { stackFrame -> Int? in
            guard let address = stackFrame.allFrames.first?.address else {
                assertionFailure("empty stack? \(stackFrame)")
                return nil
            }

            if let location = self.locations[address] {
                return location.id
            }

            let nextID = self.locations.count + 1
            self.locations[address] = Location(
                id: nextID,
                address: address,
                functions: stackFrame.allFrames.map { frame in
                    self.functions.addAndGetID(frame.functionName, type: Function.self)
                }
            )
            return nextID
        }
    }
}

protocol HasID: Sendable {
    var id: Int { get }

    var value: String { get }

    init(id: Int, value: String)

    func updatingID(_ newID: Int) -> Self
}

extension HasID {
    mutating func spuriousMutation() -> Self {
        return self
    }
}

extension Dictionary where Key == String, Value: HasID {
    mutating func addAndGetID(_ key: Key, type: Value.Type = Value.self) -> Int {
        let nextID = self.count + 1
        return self[key, default: Value(id: nextID, value: key)].spuriousMutation().id
    }
}
