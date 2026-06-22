import 'dart:io';

import 'tool_exception.dart';

final class ToolPaths {
  const ToolPaths._();

  static String join(String first, String second) {
    if (first.endsWith('/') || first.endsWith(r'\')) {
      return '$first$second';
    }
    return '$first${Platform.pathSeparator}$second';
  }

  static String normalizeToken(String path) {
    return path.replaceAll(r'\', '/').trim();
  }

  static String resolveProjectPath(String projectRoot, String relativePath) {
    return join(
        projectRoot, relativePath.replaceAll('/', Platform.pathSeparator));
  }

  static bool matchesGlob(String path, String pattern) {
    final String normalizedPath = normalizeToken(path);
    final String normalizedPattern = normalizeToken(pattern);
    final StringBuffer regex = StringBuffer('^');
    for (int index = 0; index < normalizedPattern.length; index += 1) {
      final String character = normalizedPattern[index];
      if (character == '*') {
        regex.write('.*');
      } else {
        regex.write(RegExp.escape(character));
      }
    }
    regex.write(r'$');
    return RegExp(regex.toString()).hasMatch(normalizedPath);
  }

  static String requireExistingProjectRoot(String? candidate) {
    final String root = candidate == null || candidate.trim().isEmpty
        ? Directory.current.path
        : candidate;
    final Directory directory = Directory(root);
    if (!directory.existsSync()) {
      throw ToolException('Project root does not exist: $root');
    }
    return directory.absolute.path;
  }

  static void assertInsideTemp(String path) {
    final String tempRoot = Directory.systemTemp.absolute.path;
    final String target = Directory(path).absolute.path;
    if (!target.toLowerCase().startsWith(tempRoot.toLowerCase())) {
      throw ToolException('Refusing to clean non-temp path: $target');
    }
  }
}
