import 'failure.dart';

/// A minimal Either-style result type: either a [Failure] on the left, or a
/// success value of type [T] on the right. We hand-roll this instead of
/// depending on `dartz` because this is the only Either-like use case in the
/// app, and a 30-line type is cheaper than a whole functional-programming
/// dependency.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// Returns the success value, or `null` if this is an [Err].
  T? get valueOrNull => switch (this) {
        Ok<T>(:final T value) => value,
        Err<T>() => null,
      };

  /// Returns the failure, or `null` if this is an [Ok].
  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final Failure failure) => failure,
      };

  /// Pattern-match both branches and produce a value of type [R].
  R fold<R>(R Function(Failure failure) onErr, R Function(T value) onOk) {
    return switch (this) {
      Ok<T>(:final T value) => onOk(value),
      Err<T>(:final Failure failure) => onErr(failure),
    };
  }
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}
