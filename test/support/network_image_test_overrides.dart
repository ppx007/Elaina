import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mocktail/mocktail.dart';

Future<T> withMockedNetworkImages<T>(
  Future<T> Function() body, {
  void Function(Uri uri)? onGetUrl,
}) {
  return HttpOverrides.runZoned<Future<T>>(
    body,
    createHttpClient: (_) => _TestImageHttpClient(onGetUrl: onGetUrl),
  );
}

final class _TestImageHttpClient extends Fake implements HttpClient {
  _TestImageHttpClient({this.onGetUrl});

  final void Function(Uri uri)? onGetUrl;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    onGetUrl?.call(url);
    return _TestImageHttpClientRequest();
  }

  @override
  void close({bool force = false}) {}
}

final class _TestImageHttpClientRequest extends Fake
    implements HttpClientRequest {
  @override
  HttpHeaders get headers => _TestImageHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _TestImageHttpClientResponse();
}

final class _TestImageHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  static final List<int> _transparentPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMA'
    'AQAABQABDQottAAAAABJRU5ErkJggg==',
  );

  @override
  X509Certificate? get certificate => null;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  int get contentLength => _transparentPngBytes.length;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  HttpHeaders get headers => _TestImageHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  int get statusCode => HttpStatus.ok;

  @override
  Future<Socket> detachSocket() {
    throw UnsupportedError('The test image client does not expose sockets.');
  }

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) async {
    return this;
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentPngBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

final class _TestImageHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}
