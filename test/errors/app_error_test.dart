import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/errors/app_error.dart';
import 'package:v5_app/core/errors/result.dart';
import 'package:v5_app/core/errors/error_handler.dart';

void main() {
  group('AppError', () {
    test('should create database error', () {
      final error = AppError.database('Database error');
      expect(error.type, AppErrorType.databaseError);
      expect(error.message, 'Database error');
      expect(error.isDatabaseError, isTrue);
    });

    test('should create validation error', () {
      final error = AppError.validation('Invalid input');
      expect(error.type, AppErrorType.validationError);
      expect(error.message, 'Invalid input');
      expect(error.isValidationError, isTrue);
    });

    test('should create business error with data', () {
      final error = AppError.business('Insufficient points', data: {'required': 100, 'current': 50});
      expect(error.type, AppErrorType.businessError);
      expect(error.message, 'Insufficient points');
      expect(error.data, {'required': 100, 'current': 50});
    });
  });

  group('Result', () {
    test('Success should return data', () {
      final result = Result.success('test');
      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
      expect(result.dataOrNull, 'test');
      expect(result.errorOrNull, isNull);
    });

    test('Error should return error', () {
      final error = AppError.unknown();
      final result = Result.error(error);
      expect(result.isSuccess, isFalse);
      expect(result.isError, isTrue);
      expect(result.errorOrNull, error);
      expect(result.dataOrNull, isNull);
    });

    test('fold should handle success', () {
      final result = Result.success(42);
      final value = result.fold(
        onSuccess: (data) => data * 2,
        onError: (error) => 0,
      );
      expect(value, 84);
    });

    test('fold should handle error', () {
      final result = Result.error(AppError.unknown());
      final value = result.fold(
        onSuccess: (data) => data * 2,
        onError: (error) => -1,
      );
      expect(value, -1);
    });
  });

  group('ErrorHandler', () {
    test('getErrorMessage should return correct message for database error', () {
      final error = AppError.database('DB error');
      expect(ErrorHandler.getErrorMessage(error), '数据库操作失败，请稍后重试');
    });

    test('getErrorMessage should return correct message for network error', () {
      final error = AppError.network('Network error');
      expect(ErrorHandler.getErrorMessage(error), '网络连接异常，请检查网络设置');
    });

    test('getErrorMessage should return original message for validation error', () {
      final error = AppError.validation('Field is required');
      expect(ErrorHandler.getErrorMessage(error), 'Field is required');
    });

    test('handleException should convert ArgumentError to validation error', () {
      final exception = ArgumentError('Invalid argument');
      final error = ErrorHandler.handleException(exception);
      expect(error.type, AppErrorType.validationError);
    });

    test('wrapResult should return success for successful operation', () {
      final result = ErrorHandler.wrapResult(() => 'success');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, 'success');
    });

    test('wrapResult should return error for exception', () {
      final result = ErrorHandler.wrapResult(() => throw Exception('Test error'));
      expect(result.isError, isTrue);
    });
  });
}