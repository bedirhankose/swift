//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Swift
@_implementationOnly import _SwiftConcurrencyShims

/// A partial task is a unit of scheduleable work.
@frozen
public struct PartialAsyncTask {
  private var context: Builtin.Job

  public func run() { }
}

@frozen
public struct UnsafeContinuation<T, E: Error> {
  @usableFromInline internal var context: Builtin.RawUnsafeContinuation

  @_alwaysEmitIntoClient
  internal init(_ context: Builtin.RawUnsafeContinuation) {
    self.context = context
  }

  @usableFromInline
  @_silgen_name("swift_continuation_resume")
  internal func _resume(returning value: __owned T)

  /// Resume the task awaiting the continuation by having it return normally
  /// from its suspension point.
  ///
  /// - Parameter value: The value to return from the continuation.
  ///
  /// A continuation must be resumed exactly once. If the continuation has
  /// already been resumed through this object, then the attempt to resume
  /// the continuation again will result in undefined behavior.
  ///
  /// After `resume` enqueues the task, control is immediately returned to
  /// the caller. The task will continue executing when its executor is
  /// able to reschedule it.
  @_alwaysEmitIntoClient
  public func resume(returning value: __owned T) where E == Never {
    self._resume(returning: value)
  }

  @usableFromInline
  @_silgen_name("swift_continuation_throwingResume")
  internal func _resume(returningToThrowingFunction: __owned T)

  /// Resume the task awaiting the continuation by having it return normally
  /// from its suspension point.
  ///
  /// - Parameter value: The value to return from the continuation.
  ///
  /// A continuation must be resumed exactly once. If the continuation has
  /// already been resumed through this object, then the attempt to resume
  /// the continuation again will result in undefined behavior.
  ///
  /// After `resume` enqueues the task, control is immediately returned to
  /// the caller. The task will continue executing when its executor is
  /// able to reschedule it.
  @_alwaysEmitIntoClient
  public func resume(returning value: __owned T) {
    self._resume(returningToThrowingFunction: value)
  }

  @usableFromInline
  @_silgen_name("swift_continuation_throwingResumeWithError")
  internal func _resume(throwing: __owned Error)

  /// Resume the task awaiting the continuation by having it throw an error
  /// from its suspension point.
  ///
  /// - Parameter error: The error to throw from the continuation.
  ///
  /// A continuation must be resumed exactly once. If the continuation has
  /// already been resumed through this object, then the attempt to resume
  /// the continuation again will result in undefined behavior.
  ///
  /// After `resume` enqueues the task, control is immediately returned to
  /// the caller. The task will continue executing when its executor is
  /// able to reschedule it.
  @_alwaysEmitIntoClient
  public func resume(throwing error: __owned E) {
    self._resume(throwing: error)
  }
}

extension UnsafeContinuation {
  /// Resume the task awaiting the continuation by having it either
  /// return normally or throw an error based on the state of the given
  /// `Result` value.
  ///
  /// - Parameter result: A value to either return or throw from the
  ///   continuation.
  ///
  /// A continuation must be resumed exactly once. If the continuation has
  /// already been resumed through this object, then the attempt to resume
  /// the continuation again will trap.
  ///
  /// After `resume` enqueues the task, control is immediately returned to
  /// the caller. The task will continue executing when its executor is
  /// able to reschedule it.
  @_alwaysEmitIntoClient
  public func resume<Er: Error>(with result: Result<T, Er>) where E == Error {
    switch result {
      case .success(let val):
        self.resume(returning: val)
      case .failure(let err):
        self.resume(throwing: err)
    }
  }

  /// Resume the task awaiting the continuation by having it either
  /// return normally or throw an error based on the state of the given
  /// `Result` value.
  ///
  /// - Parameter result: A value to either return or throw from the
  ///   continuation.
  ///
  /// A continuation must be resumed exactly once. If the continuation has
  /// already been resumed through this object, then the attempt to resume
  /// the continuation again will trap.
  ///
  /// After `resume` enqueues the task, control is immediately returned to
  /// the caller. The task will continue executing when its executor is
  /// able to reschedule it.
  @_alwaysEmitIntoClient
  public func resume(with result: Result<T, E>) {
    switch result {
      case .success(let val):
        self.resume(returning: val)
      case .failure(let err):
        self.resume(throwing: err)
    }
  }

  /// Resume the task awaiting the continuation by having it return normally
  /// from its suspension point.
  ///
  /// A continuation must be resumed exactly once. If the continuation has
  /// already been resumed through this object, then the attempt to resume
  /// the continuation again will trap.
  ///
  /// After `resume` enqueues the task, control is immediately returned to
  /// the caller. The task will continue executing when its executor is
  /// able to reschedule it.
  @_alwaysEmitIntoClient
  public func resume() where T == Void {
    self.resume(returning: ())
  }
}

#if _runtime(_ObjC)

// Intrinsics used by SILGen to resume or fail continuations.
@_alwaysEmitIntoClient
internal func _resumeUnsafeContinuation<T>(
  _ continuation: UnsafeContinuation<T, Never>,
  _ value: __owned T
) {
  continuation.resume(returning: value)
}

@_alwaysEmitIntoClient
internal func _resumeUnsafeThrowingContinuation<T>(
  _ continuation: UnsafeContinuation<T, Error>,
  _ value: __owned T
) {
  continuation.resume(returning: value)
}

@_alwaysEmitIntoClient
internal func _resumeUnsafeThrowingContinuationWithError<T>(
  _ continuation: UnsafeContinuation<T, Error>,
  _ error: __owned Error
) {
  continuation.resume(throwing: error)
}

#endif

/// The operation functions must resume the continuation *exactly once*.
///
/// The continuation will not begin executing until the operation function returns.
@_alwaysEmitIntoClient
public func withUnsafeContinuation<T>(
  _ fn: (UnsafeContinuation<T, Never>) -> Void
) async -> T {
  return await Builtin.withUnsafeContinuation {
    fn(UnsafeContinuation<T, Never>($0))
  }
}

/// The operation functions must resume the continuation *exactly once*.
///
/// The continuation will not begin executing until the operation function returns.
@_alwaysEmitIntoClient
public func withUnsafeThrowingContinuation<T>(
  _ fn: (UnsafeContinuation<T, Error>) -> Void
) async throws -> T {
  return try await Builtin.withUnsafeThrowingContinuation {
    fn(UnsafeContinuation<T, Error>($0))
  }
}
