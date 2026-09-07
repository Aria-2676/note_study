import 'app_error.dart';
import 'result.dart';

class ErrorHandler {
  static String getErrorMessage(AppError error) {
    switch (error.type) {
      case AppErrorType.databaseError:
        return '数据库操作失败，请稍后重试';
      case AppErrorType.networkError:
        return '网络连接异常，请检查网络设置';
      case AppErrorType.validationError:
        return error.message;
      case AppErrorType.authError:
        return '认证失败，请重新登录';
      case AppErrorType.businessError:
        return error.message;
      case AppErrorType.unknownError:
        return '系统繁忙，请稍后重试';
    }
  }

  static AppError handleException(dynamic exception) {
    if (exception is AppError) {
      return exception;
    }

    if (exception is ArgumentError) {
      return AppError.validation(exception.message ?? '参数验证失败');
    }

    if (exception is FormatException) {
      return AppError.validation('数据格式错误');
    }

    if (exception is Exception) {
      final message = exception.toString();
      if (message.contains('database') || message.contains('sqlite')) {
        return AppError.database('数据库操作失败');
      }
      if (message.contains('network') || message.contains('socket')) {
        return AppError.network('网络连接失败');
      }
    }

    return AppError.unknown();
  }

  static Result<T> wrapResult<T>(T Function() action) {
    try {
      return Result.success(action());
    } catch (e) {
      return Result.error(handleException(e));
    }
  }

  static Future<Result<T>> wrapAsyncResult<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return Result.success(result);
    } catch (e) {
      return Result.error(handleException(e));
    }
  }
}