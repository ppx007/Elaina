final class ToolException implements Exception {
  const ToolException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class ToolExitCodes {
  const ToolExitCodes._();

  static const int success = 0;
  static const int failure = 1;
  static const int usage = 64;
}
