
enum AppErrorType {
  databaseError,
  networkError,
  validationError,
  authError,
  businessError,
  unknownError,
}

class AppError {
  final AppErrorType type;
  final String message;
  final String? code;
  final dynamic data;

  AppError({
    required this.type,
    required this.message,
    this.code,
    this.data,
  });

  factory AppError.database(String message, {String? code}) {
    return AppError(
      type: AppErrorType.databaseError,
      message: message,
      code: code,
    );
  }

  factory AppError.network(String message, {String? code}) {
    return AppError(
      type: AppErrorType.networkError,
      message: message,
      code: code,
    );
  }

  factory AppError.validation(String message, {String? code}) {
    return AppError(
      type: AppErrorType.validationError,
      message: message,
      code: code,
    );
  }

  factory AppError.auth(String message, {String? code}) {
    return AppError(
      type: AppErrorType.authError,
      message: message,
      code: code,
    );
  }

  factory AppError.business(String message, {String? code, dynamic data}) {
    return AppError(
      type: AppErrorType.businessError,
      message: message,
      code: code,
      data: data,
    );
  }

  factory AppError.unknown([String message = '未知错误']) {
    return AppError(
      type: AppErrorType.unknownError,
      message: message,
    );
  }

  bool get isDatabaseError => type == AppErrorType.databaseError;
  bool get isNetworkError => type == AppErrorType.networkError;
  bool get isValidationError => type == AppErrorType.validationError;
  bool get isAuthError => type == AppErrorType.authError;
  bool get isBusinessError => type == AppErrorType.businessError;
  bool get isUnknownError => type == AppErrorType.unknownError;

  @override
  String toString() {
    return 'AppError{type: $type, message: $message, code: $code}';
  }
}