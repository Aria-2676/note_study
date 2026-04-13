import 'dart:async';
import 'app_error.dart';

abstract class Result<T> {
  const Result();

  factory Result.success(T data) = Success<T>;
  factory Result.error(AppError error) = Error<T>;

  R fold<R>({
    required R Function(T) onSuccess,
    required R Function(AppError) onError,
  });

  bool get isSuccess;
  bool get isError;

  T? get dataOrNull;
  AppError? get errorOrNull;
}

class Success<T> extends Result<T> {
  final T data;

  const Success(this.data);

  @override
  R fold<R>({
    required R Function(T) onSuccess,
    required R Function(AppError) onError,
  }) {
    return onSuccess(data);
  }

  @override
  bool get isSuccess => true;

  @override
  bool get isError => false;

  @override
  T? get dataOrNull => data;

  @override
  AppError? get errorOrNull => null;
}

class Error<T> extends Result<T> {
  final AppError error;

  const Error(this.error);

  @override
  R fold<R>({
    required R Function(T) onSuccess,
    required R Function(AppError) onError,
  }) {
    return onError(error);
  }

  @override
  bool get isSuccess => false;

  @override
  bool get isError => true;

  @override
  T? get dataOrNull => null;

  @override
  AppError? get errorOrNull => error;
}

extension ResultExtension<T> on Result<T> {
  Future<R> asyncFold<R>({
    required FutureOr<R> Function(T) onSuccess,
    required FutureOr<R> Function(AppError) onError,
  }) async {
    if (isSuccess) {
      final data = dataOrNull;
      if (data != null) {
        final result = onSuccess(data);
        return result is Future<R> ? await result : result;
      }
      throw StateError('Success result with null data');
    } else {
      final error = errorOrNull;
      if (error != null) {
        final result = onError(error);
        return result is Future<R> ? await result : result;
      }
      throw StateError('Error result with null error');
    }
  }

  Result<T> onSuccess(void Function(T) action) {
    if (isSuccess) {
      final data = dataOrNull;
      if (data != null) {
        action(data);
      }
    }
    return this;
  }

  Result<T> onError(void Function(AppError) action) {
    if (isError) {
      final error = errorOrNull;
      if (error != null) {
        action(error);
      }
    }
    return this;
  }

  T getOrThrow() {
    if (isSuccess) {
      final data = dataOrNull;
      if (data != null) {
        return data;
      }
      throw StateError('Success result with null data');
    }
    final error = errorOrNull;
    if (error != null) {
      throw error;
    }
    throw StateError('Error result with null error');
  }

  T getOrDefault(T defaultValue) {
    if (isSuccess) {
      final data = dataOrNull;
      if (data != null) {
        return data;
      }
    }
    return defaultValue;
  }

  T? getOrNull() {
    return dataOrNull;
  }
}

extension FutureResultExtension<T> on Future<Result<T>> {
  Future<R> thenFold<R>({
    required FutureOr<R> Function(T) onSuccess,
    required FutureOr<R> Function(AppError) onError,
  }) async {
    final result = await this;
    return result.fold(
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}