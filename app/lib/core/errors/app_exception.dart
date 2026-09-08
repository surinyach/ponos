abstract class AppException implements Exception {
  const AppException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class ConflictException extends AppException {
  const ConflictException(super.message);
}

class ServerException extends AppException {
  const ServerException(super.message);
}

class InvalidResponseException extends AppException {
  const InvalidResponseException(super.message);
}
