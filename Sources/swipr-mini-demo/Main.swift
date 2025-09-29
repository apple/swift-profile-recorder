//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Profile Recorder open source project
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift Profile Recorder project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift Profile Recorder project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ArgumentParser
import ProfileRecorder
import Dispatch
import Foundation
import ProfileRecorderServer
import Logging

@main
struct ProfileRecorderMiniDemo: ParsableCommand & Sendable {
    @Flag(inversion: .prefixedNo, help: "Should we run a blocking function?")
    var blocking: Bool = false

    @Flag(inversion: .prefixedNo, help: "Should we burn a bit of CPU?")
    var burnCPU: Bool = true

    @Flag(inversion: .prefixedNo, help: "Should we burn do a bunch of Array.appends?")
    var arrayAppends: Bool = false

    @Flag(inversion: .prefixedNo, help: "Start profile recording server?")
    var profilingServer: Bool = false

    @Option(help: "How many samples?")
    var sampleCount: Int = 100

    @Option(help: "How many ms between samples?")
    var msBetweenSamples: Int64 = 10

    @Option(help: "Where to write the samples to?")
    var output: String = "-"

    @Option(help: "How many iterations?")
    var iterations: Int = 10

    @Option(help: "Run multi-threaded")
    var threads: Int = 1

    @Option(help: "Run travelling salesman")
    var tsp: Bool = false

    func run() throws {
        let logger = Logger(label: "swipr-mini-demo")
        var profilingServerTask: Task<Void, any Error>? = nil
        if self.profilingServer {
            // We are using an unstructured `Task` here such that we can keep the main function synchronous
            // which makes some profiler demonstrations easier because we'll not immediately spawn more threads.
            //
            // In real code please just use
            //
            //   async let _ = ProfileRecorderServer(
            //       configuration: try await .parseFromEnvironment()
            //   ).runIgnoringFailures(logger: logger)
            //
            // at the beginning of your main function.
            profilingServerTask = Task {
                async let _ = ProfileRecorderServer(
                    configuration: try await .parseFromEnvironment()
                ).runIgnoringFailures(logger: logger)
                while !Task.isCancelled {
                    // sleep until cancelled
                    try? await Task.sleep(nanoseconds: 100_000_000_000)
                }
            }
        }
        defer {
            profilingServerTask?.cancel()
        }
        ProfileRecorderSampler.sharedInstance.requestSamples(
            outputFilePath: self.output,
            failIfFileExists: false,
            count: self.sampleCount,
            timeBetweenSamples: .milliseconds(
                self.msBetweenSamples
            ),
            queue: DispatchQueue.global(),
            { result in
                print("- collected samples: \(result)")
                print("- ./swipr-sample-conv \(result) | swift demangle --compact > /tmp/samples.perf")
                print("- open in a visualisation tool (such as https://speedscope.app or https://profiler.firefox.com)")
            }
        )

        print(
            """
            STARTING to \(self.iterations) iterations \
            \(self.burnCPU ? ", burn CPU" : "") \
            \(self.arrayAppends ? ", array appends" : "") \
            \(self.blocking ? ", blocking" : "")
            """
        )
        let queue = DispatchQueue.global()
        for _ in 0..<self.iterations {
            if self.threads > 1 {
                let g = DispatchGroup()
                for _ in 0..<self.threads {
                    queue.async(group: g) {
                        self.runIteration()
                    }
                }
                g.wait()
            } else {
                self.runIteration()
            }
        }
        print("DONE")
        fflush(stdout)
    }

    func runIteration() {
        if self.arrayAppends {
            var xs: [Int] = []
            for x in 0..<4_000_000 {
                xs.append(x)
            }
            precondition(xs.count == xs.count - 1 + 1)
        }
        if self.burnCPU {
            doBurnCPU()
        }
        if self.blocking {
            func hideBlocking() {
                Thread.sleep(forTimeInterval: 0.2)
            }
            hideBlocking()
        }
        if self.tsp {
            runTravellingSalesman()
        }
    }
}

func doBurnCPU() {
    #if DEBUG
    let notRotated = Array(1...400)
    #else
    let notRotated = Array(1...10_000)
    #endif
    var rotated = notRotated
    rotated.rotate(toStartAt: 1)

    while notRotated != rotated {
        rotated.rotate(toStartAt: 1)
    }
}

extension Array {
    mutating func rotate(toStartAt index: Int) {
        let tmp = self[0..<index]
        self[0...] = self[index...]
        self.append(contentsOf: tmp)
    }
}

@discardableResult
@inline(never)
func runTravellingSalesman() -> Double {
    // For demo purposes only, AI written.
    struct City {
        let name: String
        let x: Double
        let y: Double
    }

    struct Route {
        let cities: [City]
        let totalDistance: Double
    }

    // MARK: - Distance Calculations

    func distanceBetweenCities(_ first: City, _ second: City) -> Double {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return (dx * dx + dy * dy).squareRoot()
    }

    func calculateTotalRouteDistance(for cities: [City]) -> Double {
        guard cities.count > 1 else { return 0.0 }
        var sum = 0.0
        for i in 0..<(cities.count - 1) {
            sum += distanceBetweenCities(cities[i], cities[i + 1])
        }
        sum += distanceBetweenCities(cities.last!, cities.first!) // close the loop
        return sum
    }

    // MARK: - Recursive Search

    func exploreRoutesRecursively(
        from currentCity: City,
        remainingCities: [City],
        visitedCities: [City]
    ) -> Route {
        if remainingCities.isEmpty {
            let fullRoute = visitedCities + [currentCity]
            return Route(
                cities: fullRoute,
                totalDistance: calculateTotalRouteDistance(for: fullRoute)
            )
        }

        var bestRoute: Route? = nil
        for (index, nextCity) in remainingCities.enumerated() {
            let newRemainingCities = Array(
                remainingCities[0..<index] + remainingCities[(index + 1)...]
            )
            let candidateRoute = exploreRoutesRecursively(
                from: nextCity,
                remainingCities: newRemainingCities,
                visitedCities: visitedCities + [currentCity]
            )
            if bestRoute == nil || candidateRoute.totalDistance < bestRoute!.totalDistance {
                bestRoute = candidateRoute
            }
        }
        return bestRoute!
    }

    func solveTravelingSalesmanProblem(for cities: [City]) -> Route {
        guard let startingCity = cities.first else {
            fatalError("No cities provided")
        }
        let remainingCities = Array(cities.dropFirst())
        return exploreRoutesRecursively(
            from: startingCity,
            remainingCities: remainingCities,
            visitedCities: []
        )
    }

    // MARK: - Demo Data

    let demoCities: [City] = [
        City(name: "London", x: 0.0, y: 0.0),
        City(name: "Paris", x: 2.0, y: 1.0),
        City(name: "Berlin", x: 5.0, y: 1.5),
        City(name: "Rome", x: 6.0, y: -2.0),
        City(name: "Madrid", x: -2.0, y: -1.5),
        City(name: "Vienna", x: 6.0, y: 0.0),
        City(name: "Prague", x: 5.5, y: 0.5),
        City(name: "Amsterdam", x: 2.0, y: 2.0),
        City(name: "Brussels", x: 1.5, y: 1.2),
        City(name: "Zurich", x: 4.0, y: -0.5),
    ]

    // MARK: - Run

    let bestRoute = solveTravelingSalesmanProblem(for: demoCities)
    return bestRoute.totalDistance
}
