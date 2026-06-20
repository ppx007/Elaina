import 'package:elaina/src/foundation/security/outbound_uri_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const OutboundUriGuard guard = OutboundUriGuard();

  group('OutboundUriGuard', () {
    test('blocks loopback in every IPv4 and IPv6 encoding', () {
      expect(guard.classifyHost('localhost'), OutboundHostRisk.loopback);
      expect(guard.classifyHost('127.0.0.1'), OutboundHostRisk.loopback);
      expect(guard.classifyHost('0.0.0.0'), OutboundHostRisk.loopback);
      expect(guard.classifyHost('2130706433'), OutboundHostRisk.loopback);
      expect(guard.classifyHost('0x7f000001'), OutboundHostRisk.loopback);
      expect(guard.classifyHost('::1'), OutboundHostRisk.loopback);
      expect(guard.classifyHost('::ffff:127.0.0.1'), OutboundHostRisk.loopback);
    });

    test('blocks link-local ranges', () {
      expect(guard.classifyHost('169.254.1.1'), OutboundHostRisk.linkLocal);
      expect(guard.classifyHost('fe80::1'), OutboundHostRisk.linkLocal);
    });

    test('blocks private / unique-local ranges', () {
      expect(guard.classifyHost('10.0.0.5'), OutboundHostRisk.privateNetwork);
      expect(guard.classifyHost('172.16.0.1'), OutboundHostRisk.privateNetwork);
      expect(
          guard.classifyHost('192.168.1.1'), OutboundHostRisk.privateNetwork);
      expect(guard.classifyHost('fd00::1'), OutboundHostRisk.privateNetwork);
    });

    test('allows routable public hosts', () {
      expect(guard.classifyHost('example.com'), isNull);
      expect(guard.classifyHost('8.8.8.8'), isNull);
      expect(
          guard.classifyHost('172.32.0.1'), isNull); // just outside 172.16/12
      expect(guard.isUriAllowed(Uri.parse('https://api.bgm.tv/v0/search')),
          isTrue);
    });

    test('classifyUri rejects unsafe hosts via Uri', () {
      expect(guard.isUriAllowed(Uri.parse('http://127.0.0.1/admin')), isFalse);
      expect(guard.isUriAllowed(Uri.parse('http://[::1]/admin')), isFalse);
    });

    test('blocks hex-encoded IPv4-mapped IPv6 (SSRF bypass regression)', () {
      // Without dotted-quad notation the embedded IPv4 must still be classified.
      expect(guard.classifyHost('::ffff:7f00:1'), OutboundHostRisk.loopback);
      expect(guard.classifyHost('::ffff:7f00:0001'), OutboundHostRisk.loopback);
      // 169.254.169.254 — the cloud instance-metadata endpoint.
      expect(
          guard.classifyHost('::ffff:a9fe:a9fe'), OutboundHostRisk.linkLocal);
      expect(
          guard.classifyHost('::ffff:a00:1'), OutboundHostRisk.privateNetwork);
      expect(
          guard.classifyHost('::ffff:c0a8:1'), OutboundHostRisk.privateNetwork);
      expect(
          guard.classifyHost('::ffff:ac10:1'), OutboundHostRisk.privateNetwork);
    });

    test('blocks expanded and zone-tagged loopback (SSRF bypass regression)',
        () {
      expect(guard.classifyHost('0:0:0:0:0:0:0:1'), OutboundHostRisk.loopback);
      expect(guard.classifyHost('0000:0000:0000:0000:0000:0000:0000:0001'),
          OutboundHostRisk.loopback);
      expect(guard.classifyHost('::'), OutboundHostRisk.loopback);
      expect(guard.classifyHost('0:0:0:0:0:0:0:0'), OutboundHostRisk.loopback);
    });

    test('blocks fe80::/10 link-local across the full range', () {
      expect(guard.classifyHost('fe80::1'), OutboundHostRisk.linkLocal);
      expect(guard.classifyHost('fea0::1'), OutboundHostRisk.linkLocal);
      expect(guard.classifyHost('febf::1'), OutboundHostRisk.linkLocal);
      // fec0::/10 is the separate (deprecated) site-local block, not fe80::/10.
      expect(guard.classifyHost('fec0::1'), isNull);
    });

    test('blocks fc00::/7 unique-local across the range', () {
      expect(guard.classifyHost('fc00::1'), OutboundHostRisk.privateNetwork);
      expect(guard.classifyHost('fdff::1'), OutboundHostRisk.privateNetwork);
    });
  });
}
