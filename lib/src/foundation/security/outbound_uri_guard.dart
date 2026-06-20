/// Pure, dependency-free SSRF host classification shared by the network policy
/// layer and concrete provider transports.
///
/// Lives in `foundation` (the cross-cutting base imported by every layer) so a
/// single canonical implementation guards every outbound request without the
/// provider layer having to depend on the network layer.
library;

/// Why an outbound host is considered unsafe to dial directly.
enum OutboundHostRisk {
  /// Loopback / "this host" (127.0.0.0/8, 0.0.0.0/8, ::1, localhost).
  loopback,

  /// Link-local (169.254.0.0/16, fe80::/10).
  linkLocal,

  /// Private / unique-local (RFC1918, fc00::/7).
  privateNetwork,
}

/// Default port for the `http` scheme.
const int httpDefaultPort = 80;

/// Default port for the `https` scheme.
const int httpsDefaultPort = 443;

/// The effective port for [uri], substituting scheme defaults when absent.
int effectiveUriPort(Uri uri) {
  if (uri.hasPort) {
    return uri.port;
  }
  return switch (uri.scheme) {
    'http' => httpDefaultPort,
    'https' => httpsDefaultPort,
    _ => 0,
  };
}

/// True when [left] and [right] share scheme, host, and effective port.
bool uriSameOrigin(Uri left, Uri right) {
  return left.scheme == right.scheme &&
      left.host == right.host &&
      effectiveUriPort(left) == effectiveUriPort(right);
}

/// Classifies request hosts that must not be reached by provider traffic.
///
/// The default `const OutboundUriGuard()` blocks loopback, link-local, and
/// private ranges across IPv4 (dotted, single-integer and hex encodings) and
/// IPv6 (including IPv4-mapped suffixes).
final class OutboundUriGuard {
  const OutboundUriGuard();

  /// Returns the risk classification for [uri]'s host, or null when the host
  /// is a routable public destination.
  OutboundHostRisk? classifyUri(Uri uri) => classifyHost(uri.host);

  /// True when [uri] is safe to dial directly (no SSRF risk classification).
  bool isUriAllowed(Uri uri) => classifyUri(uri) == null;

  /// Classifies a bare host string (IPv6 literals arrive without brackets,
  /// matching `Uri.host`).
  OutboundHostRisk? classifyHost(String host) {
    final String normalized = host.toLowerCase();
    if (normalized.isEmpty || normalized == 'localhost') {
      return OutboundHostRisk.loopback;
    }
    if (normalized.contains(':')) {
      return _classifyIpv6(normalized);
    }
    final List<int>? octets =
        _dottedIpv4Octets(normalized) ?? _nonDottedIpv4Octets(normalized);
    if (octets == null) {
      return null;
    }
    return _classifyIpv4Octets(octets);
  }

  static OutboundHostRisk? _classifyIpv4Octets(List<int> octets) {
    // 0.0.0.0/8 is "this host"; routes to loopback on most stacks.
    if (octets[0] == 0 || octets[0] == 127) {
      return OutboundHostRisk.loopback;
    }
    if (octets[0] == 169 && octets[1] == 254) {
      return OutboundHostRisk.linkLocal;
    }
    if (octets[0] == 10 ||
        (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
        (octets[0] == 192 && octets[1] == 168)) {
      return OutboundHostRisk.privateNetwork;
    }
    return null;
  }

  static OutboundHostRisk? _classifyIpv6(String host) {
    final String compact = host.replaceAll('[', '').replaceAll(']', '');
    // Drop any RFC 4007 zone identifier (`fe80::1%eth0`); it never changes the
    // address class and would otherwise defeat exact-value comparisons.
    final int zoneIndex = compact.indexOf('%');
    final String address =
        zoneIndex >= 0 ? compact.substring(0, zoneIndex) : compact;

    // Classify by the parsed 16-byte value rather than textual prefixes, so
    // every spelling (zero-compressed, fully expanded, leading zeros, and
    // hex-encoded IPv4-mapped suffixes) is handled uniformly. Parsing also
    // rejects malformed literals, which are simply treated as unclassified.
    final List<int>? bytes = _parseIpv6Bytes(address);
    if (bytes == null) {
      return null;
    }

    // IPv4-mapped (::ffff:0:0/96) and IPv4-compatible (::/96, excluding ::/::1)
    // embed an IPv4 address in the trailing four bytes; delegate to the IPv4
    // classifier so e.g. ::ffff:7f00:1 is recognized as 127.0.0.1.
    if (_isIpv4MappedPrefix(bytes) || _isIpv4CompatiblePrefix(bytes)) {
      final OutboundHostRisk? mapped = _classifyIpv4Octets(
          <int>[bytes[12], bytes[13], bytes[14], bytes[15]]);
      if (mapped != null) {
        return mapped;
      }
    }

    // Loopback ::1 and the unspecified :: address (this-host) both route locally.
    if (_isUnspecifiedOrLoopback(bytes)) {
      return OutboundHostRisk.loopback;
    }
    // Link-local fe80::/10 — first 10 bits are 1111 1110 10.
    if (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) {
      return OutboundHostRisk.linkLocal;
    }
    // Unique-local fc00::/7 — first 7 bits are 1111 110.
    if ((bytes[0] & 0xfe) == 0xfc) {
      return OutboundHostRisk.privateNetwork;
    }
    return null;
  }

  /// Parses [address] into its 16 constituent bytes, or null when it is not a
  /// valid IPv6 literal.
  static List<int>? _parseIpv6Bytes(String address) {
    try {
      final List<int> bytes = Uri.parseIPv6Address(address);
      return bytes.length == 16 ? bytes : null;
    } on FormatException {
      return null;
    }
  }

  /// True for the IPv4-mapped prefix `::ffff:0:0/96`.
  static bool _isIpv4MappedPrefix(List<int> bytes) {
    for (int i = 0; i < 10; i++) {
      if (bytes[i] != 0) {
        return false;
      }
    }
    return bytes[10] == 0xff && bytes[11] == 0xff;
  }

  /// True for the deprecated IPv4-compatible prefix `::/96`, excluding `::` and
  /// `::1` which are handled as loopback/unspecified.
  static bool _isIpv4CompatiblePrefix(List<int> bytes) {
    for (int i = 0; i < 12; i++) {
      if (bytes[i] != 0) {
        return false;
      }
    }
    // Exclude :: (all zero) and ::1 so they fall through to the loopback check.
    final bool lastFourZeroOrOne =
        bytes[12] == 0 && bytes[13] == 0 && bytes[14] == 0 && bytes[15] <= 1;
    return !lastFourZeroOrOne;
  }

  /// True for `::` (unspecified) and `::1` (loopback).
  static bool _isUnspecifiedOrLoopback(List<int> bytes) {
    for (int i = 0; i < 15; i++) {
      if (bytes[i] != 0) {
        return false;
      }
    }
    return bytes[15] == 0 || bytes[15] == 1;
  }

  static List<int>? _dottedIpv4Octets(String value) {
    final List<String> parts = value.split('.');
    if (parts.length != 4) {
      return null;
    }
    final List<int> octets = <int>[];
    for (final String part in parts) {
      final int? parsed = int.tryParse(part);
      if (parsed == null || parsed < 0 || parsed > 255) {
        return null;
      }
      octets.add(parsed);
    }
    return octets;
  }

  /// Parses single-integer (`2130706433`) and hex (`0x7f000001`) IPv4 forms.
  static List<int>? _nonDottedIpv4Octets(String value) {
    int? raw;
    if (value.startsWith('0x')) {
      raw = int.tryParse(value.substring(2), radix: 16);
    } else if (RegExp(r'^[0-9]+$').hasMatch(value)) {
      raw = int.tryParse(value);
    }
    if (raw == null || raw < 0 || raw > 0xffffffff) {
      return null;
    }
    return <int>[
      (raw >> 24) & 0xff,
      (raw >> 16) & 0xff,
      (raw >> 8) & 0xff,
      raw & 0xff,
    ];
  }
}
