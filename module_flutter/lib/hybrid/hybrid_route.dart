import 'dart:convert';

class HybridRoute {
  final String scheme;
  final String target;
  final String path;
  final Map<String, Object?> params;
  final String from;
  final int version;
  final String? requestId;
  final String raw;

  const HybridRoute({
    required this.scheme,
    required this.target,
    required this.path,
    required this.params,
    required this.from,
    required this.version,
    required this.raw,
    this.requestId,
  });

  factory HybridRoute.flutter(
    String path, {
    Map<String, Object?> params = const {},
    String from = 'flutter',
  }) {
    return HybridRoute(
      scheme: 'cooldemo',
      target: 'flutter',
      path: path,
      params: params,
      from: from,
      version: 1,
      raw: '',
    );
  }

  factory HybridRoute.parse(String? rawRoute) {
    final raw = rawRoute?.trim();
    if (raw == null || raw.isEmpty) {
      return HybridRoute._legacy('/');
    }

    if (!raw.startsWith('{')) {
      return HybridRoute._legacy(raw);
    }

    try {
      final json = jsonDecode(raw);
      if (json is! Map) {
        return HybridRoute._legacy('/');
      }

      final path = json['path'];
      final params = json['params'];

      return HybridRoute(
        scheme: json['scheme'] as String? ?? 'cooldemo',
        target: json['target'] as String? ?? 'flutter',
        path: path is String && path.isNotEmpty ? path : '/',
        params: params is Map ? Map<String, Object?>.from(params) : const {},
        from: json['from'] as String? ?? 'unknown',
        version: json['version'] is int ? json['version'] as int : 1,
        requestId: json['requestId'] as String?,
        raw: raw,
      );
    } catch (_) {
      return HybridRoute._legacy('/');
    }
  }

  factory HybridRoute._legacy(String path) {
    return HybridRoute(
      scheme: 'legacy',
      target: 'flutter',
      path: path,
      params: const {},
      from: 'legacy',
      version: 0,
      raw: path,
    );
  }

  String toJson() {
    return jsonEncode({
      'scheme': scheme,
      'target': target,
      'path': path,
      'params': params,
      'from': from,
      'version': version,
      if (requestId != null) 'requestId': requestId,
    });
  }
}
