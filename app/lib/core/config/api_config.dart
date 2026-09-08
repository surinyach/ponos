class ApiConfig {
  ApiConfig(String baseUrl) : baseUri = _parse(baseUrl);
  factory ApiConfig.fromEnvironment() => ApiConfig(
    const String.fromEnvironment(
      'PONOS_API_BASE_URL',
      defaultValue: 'http://localhost:8000',
    ),
  );
  final Uri baseUri;
  Uri endpoint(String path) {
    final base = baseUri.toString().replaceFirst(RegExp(r'/$'), '');
    final suffix = path.replaceFirst(RegExp(r'^/'), '');
    return Uri.parse('$base/$suffix');
  }

  static Uri _parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw ArgumentError.value(value, 'baseUrl', 'Must be an HTTP(S) URL');
    }
    return uri;
  }
}
