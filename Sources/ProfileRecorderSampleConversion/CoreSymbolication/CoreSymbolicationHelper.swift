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

#if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
import Darwin
import Foundation
import CProfileRecorderDarwin

extension Sym {
    static let CSArchitectureGetArchitectureForName:
    @convention(c) (UnsafePointer<CChar>) -> CSArchitecture =
    symbol(coreSymbolicationHandle, "CSArchitectureGetArchitectureForName")
    
    // CSSymbolicator
    static let CSSymbolicatorGetSymbolOwner:
    @convention(c) (CSSymbolicatorRef) -> CSSymbolOwnerRef =
    symbol(coreSymbolicationHandle, "CSSymbolicatorGetSymbolOwner")
    static let CSSymbolicatorGetSymbolWithAddressAtTime:
    @convention(c) (CSSymbolicatorRef, vm_address_t, CSMachineTime) -> CSSymbolRef =
    symbol(coreSymbolicationHandle, "CSSymbolicatorGetSymbolWithAddressAtTime")
    static let CSSymbolicatorCreateWithPathAndArchitecture:
    @convention(c) (UnsafePointer<CChar>, CSArchitecture) -> CSSymbolicatorRef =
    symbol(coreSymbolicationHandle, "CSSymbolicatorCreateWithPathAndArchitecture")
}

// .. CSSymbolicator ...........................................................
func SymbolicatorCreateWithDynamicLibMapping(
    _ library: DynamicLibMapping
) -> CSSymbolicatorRef
{
    return library.path.withCString { path in
        library.architecture.withCString { arch in
            let CSarch = Sym.CSArchitectureGetArchitectureForName(arch)
            return Sym.CSSymbolicatorCreateWithPathAndArchitecture(path, CSarch)
        }
    }
}

func CSSymbolicatorGetSymbolOwnerWithAddress(
  _ symbolicator: CSSymbolicatorRef,
  _ addr: vm_address_t
) -> CSSymbolOwnerRef {
  return Sym.CSSymbolicatorGetSymbolOwnerWithAddressAtTime(symbolicator,
                                                           addr, kCSBeginningOfTime)
}

func CSSymbolicatorGetSymbolOwner(
    _ symbolicator: CSSymbolicatorRef
) -> CSSymbolOwnerRef {
    var owner: CSSymbolOwnerRef = kCSNull
    
    let count = CSSymbolicatorForeachSymbolOwnerAtTime(symbolicator, kCSAllTimes) { symbolOwner in
        owner = symbolOwner
    }
    
    if count == 1 {
        return owner
    }
    
    return kCSNull
}

func CSSymbolicatorGetSymbolWithAddressAtTime(
  _ symbolicator: CSSymbolicatorRef,
  _ address: vm_address_t
  ) ->  CSSymbolRef {
      return Sym.CSSymbolicatorGetSymbolWithAddressAtTime(symbolicator, address, kCSBeginningOfTime)
}
#endif

