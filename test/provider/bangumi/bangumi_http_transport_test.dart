import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:elaina/src/provider/bangumi/bangumi_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
  });

  test('writes JSON request bodies as UTF-8 bytes', () async {
    final _MockHttpClient httpClient = _MockHttpClient();
    final _MockHttpClientRequest httpRequest = _MockHttpClientRequest();
    final _MockHttpHeaders headers = _MockHttpHeaders();
    final _StaticHttpClientResponse response = _StaticHttpClientResponse(
      statusCode: HttpStatus.ok,
      body: '{}',
    );
    final Uri uri = Uri.parse('https://api.bgm.tv/v0/search/subjects');
    when(() => httpClient.openUrl('POST', uri))
        .thenAnswer((_) async => httpRequest);
    when(() => httpRequest.headers).thenReturn(headers);
    when(() => httpRequest.add(any<List<int>>())).thenReturn(null);
    when(() => httpRequest.close()).thenAnswer((_) async => response);

    final HttpBangumiApiTransport transport = HttpBangumiApiTransport(
      httpClient: httpClient,
    );
    final String body = jsonEncode(<String, Object?>{
      'keyword': '电视',
      'sort': bangumiApiSubjectSearchHeatSort,
      'filter': <String, Object?>{
        'type': <int>[bangumiAnimeSubjectType],
      },
    });

    final BangumiApiResponse result = await transport.send(
      BangumiApiRequest(
        method: 'POST',
        uri: uri,
        headers: const <String, String>{
          HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        },
        body: body,
      ),
    );

    expect(result.statusCode, HttpStatus.ok);
    final List<int> bodyBytes = utf8.encode(body);
    final List<int> capturedBytes =
        verify(() => httpRequest.add(captureAny<List<int>>())).captured.single
            as List<int>;
    expect(utf8.decode(capturedBytes), body);
    expect(capturedBytes, bodyBytes);
    verify(() => httpRequest.contentLength = bodyBytes.length).called(1);
    verifyNever(() => httpRequest.write(any<dynamic>()));
    verify(
      () => headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      ),
    ).called(1);
  });
}

final class _MockHttpClient extends Mock implements HttpClient {}

final class _MockHttpClientRequest extends Mock implements HttpClientRequest {}

final class _MockHttpHeaders extends Mock implements HttpHeaders {}

final class _StaticHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _StaticHttpClientResponse({
    required this.statusCode,
    required String body,
  }) : _bodyBytes = utf8.encode(body);

  @override
  final int statusCode;

  final List<int> _bodyBytes;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_bodyBytes).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
