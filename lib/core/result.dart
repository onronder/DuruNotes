/// A type that represents either a success value or a failure error.
///
/// This is a sealed class that ensures exhaustive pattern matching and
/// provides a type-safe way to handle both success and failure cases.
///
/// Example usage:
/// ```dart
/// Future<Result<User, AppError>> getUser(String id) async {
///   try {
///     final user = await api.fetchUser(id);
///     return Result.success(user);
///   } catch (e, stack) {
///     return Result.failure(NetworkError(
///       message: 'Failed to fetch user',
///       originalError: e,
///       stackTrace: stack,
///     ));
///   }
/// }
///
/// // Usage in UI
/// final result = await getUser('123');
/// result.when(
///   success: (user) => showUser(user),
///   failure: (error) => showError(error),
/// );
/// ```
sealed class Result<T, E> {
  const Result();

  /// Creates a successful result with the given value.
  factory Result.success(T value) = Success<T, E>;

  /// Creates a failure result with the given error.
  factory Result.failure(E error) = Failure<T, E>;

  /// Returns true if this is a success result.
  bool get isSuccess;

  /// Returns true if this is a failure result.
  bool get isFailure;

  /// Returns the success value if this is a success result, otherwise null.
  T? get valueOrNull;

  /// Returns the error if this is a failure result, otherwise null.
  E? get errorOrNull;

  /// Pattern matches on the result, calling the appropriate function.
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  });

  /// Pattern matches on the result with optional handlers.
  R? whenOrNull<R>({
    R Function(T value)? success,
    R Function(E error)? failure,
  });

  /// Maps the success value to a new value.
  Result<U, E> map<U>(U Function(T value) transform);

  /// Maps the error to a new error.
  Result<T, F> mapError<F>(F Function(E error) transform);

  /// Flat maps the success value to a new Result.
  Future<Result<U, E>> flatMap<U>(
    Future<Result<U, E>> Function(T value) transform,
  );

  /// Returns the success value or the provided default value.
  T getOrElse(T defaultValue);

  /// Returns the success value or computes a default value.
  T getOrElseCompute(T Function() compute);

  /// Returns the success value or throws the error.
  T getOrThrow();

  /// Executes a side effect if this is a success.
  Result<T, E> onSuccess(void Function(T value) action);

  /// Executes a side effect if this is a failure.
  Result<T, E> onFailure(void Function(E error) action);
}

/// Represents a successful result containing a value.
class Success<T, E> extends Result<T, E> {
  /// Creates a successful result with the given value.
  const Success(this.value);

  /// The success value.
  final T value;

  @override
  bool get isSuccess => true;

  @override
  bool get isFailure => false;

  @override
  T? get valueOrNull => value;

  @override
  E? get errorOrNull => null;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  }) {
    return success(value);
  }

  @override
  R? whenOrNull<R>({
    R Function(T value)? success,
    R Function(E error)? failure,
  }) {
    return success?.call(value);
  }

  @override
  Result<U, E> map<U>(U Function(T value) transform) {
    return Success<U, E>(transform(value));
  }

  @override
  Result<T, F> mapError<F>(F Function(E error) transform) {
    return Success<T, F>(value);
  }

  @override
  Future<Result<U, E>> flatMap<U>(
    Future<Result<U, E>> Function(T value) transform,
  ) async {
    return transform(value);
  }

  @override
  T getOrElse(T defaultValue) => value;

  @override
  T getOrElseCompute(T Function() compute) => value;

  @override
  T getOrThrow() => value;

  @override
  Result<T, E> onSuccess(void Function(T value) action) {
    action(value);
    return this;
  }

  @override
  Result<T, E> onFailure(void Function(E error) action) {
    return this;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success<T, E> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// Represents a failure result containing an error.
class Failure<T, E> extends Result<T, E> {
  /// Creates a failure result with the given error.
  const Failure(this.error);

  /// The error.
  final E error;

  @override
  bool get isSuccess => false;

  @override
  bool get isFailure => true;

  @override
  T? get valueOrNull => null;

  @override
  E? get errorOrNull => error;

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  }) {
    return failure(error);
  }

  @override
  R? whenOrNull<R>({
    R Function(T value)? success,
    R Function(E error)? failure,
  }) {
    return failure?.call(error);
  }

  @override
  Result<U, E> map<U>(U Function(T value) transform) {
    return Failure<U, E>(error);
  }

  @override
  Result<T, F> mapError<F>(F Function(E error) transform) {
    return Failure<T, F>(transform(error));
  }

  @override
  Future<Result<U, E>> flatMap<U>(
    Future<Result<U, E>> Function(T value) transform,
  ) async {
    return Failure<U, E>(error);
  }

  @override
  T getOrElse(T defaultValue) => defaultValue;

  @override
  T getOrElseCompute(T Function() compute) => compute();

  @override
  T getOrThrow() {
    if (error is Exception) {
      throw error as Exception;
    }
    throw Exception(error.toString());
  }

  @override
  Result<T, E> onSuccess(void Function(T value) action) {
    return this;
  }

  @override
  Result<T, E> onFailure(void Function(E error) action) {
    action(error);
    return this;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Failure<T, E> && other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}

/// Extension methods for Result with nullable values.
extension ResultNullableExtensions<T, E> on Result<T?, E> {
  /// Converts a Result<T?, E> to Result<T, E> by providing a default value for null.
  Result<T, E> notNull(E Function() onNull) {
    return when(
      success: (value) =>
          value != null ? Result.success(value) : Result.failure(onNull()),
      failure: Result.failure,
    );
  }
}

/// Extension methods for Future<Result>.
extension FutureResultExtensions<T, E> on Future<Result<T, E>> {
  /// Maps the success value of a Future<Result>.
  Future<Result<U, E>> mapAsync<U>(U Function(T value) transform) async {
    final result = await this;
    return result.map(transform);
  }

  /// Maps the error of a Future<Result>.
  Future<Result<T, F>> mapErrorAsync<F>(F Function(E error) transform) async {
    final result = await this;
    return result.mapError(transform);
  }

  /// Flat maps the success value of a Future<Result>.
  Future<Result<U, E>> flatMapAsync<U>(
    Future<Result<U, E>> Function(T value) transform,
  ) async {
    final result = await this;
    return result.flatMap(transform);
  }
}
