sealed class AppException implements Exception {
  const AppException({required this.code, required this.message, this.cause});

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'AppException($code): $message';
}

final class UnexpectedAppException extends AppException {
  UnexpectedAppException(Object cause)
    : super(
        code: 'unexpected',
        message: 'An unexpected error occurred.',
        cause: cause,
      );
}
