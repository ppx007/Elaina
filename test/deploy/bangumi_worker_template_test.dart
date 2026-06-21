import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('Bangumi Worker template keeps route and allowlist contract', () {
    final String source =
        File('deploy/bangumi-worker/worker.js').readAsStringSync();

    expect(source, contains("const BANGUMI_API_ORIGIN = 'https://api.bgm.tv'"));
    expect(source, contains("const API_ROUTE_PREFIX = '/api'"));
    expect(source, contains("const IMAGE_ROUTE_PATH = '/image'"));
    expect(source, contains("const IMAGE_URL_PARAMETER = 'url'"));
    expect(source, contains("new Set(['lain.bgm.tv'])"));
    expect(source, contains('ALLOWED_IMAGE_HOSTS.has(imageUrl.hostname)'));
    expect(source, contains('IMAGE_METHODS.has(request.method)'));
    expect(source, contains('Image host is not allowed'));
  });
}
