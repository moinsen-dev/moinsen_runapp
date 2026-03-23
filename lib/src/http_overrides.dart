import 'dart:convert' show Encoding;
import 'dart:io';

import 'package:moinsen_runapp/src/http_monitor.dart';

/// HTTP client wrapper that records requests to [MoinsenHttpMonitor].
///
/// Install via `HttpOverrides.global = MoinsenHttpOverrides()` to
/// automatically intercept all `dart:io` HTTP traffic (including
/// `package:http` and `package:dio` which use `HttpClient` internally).
class MoinsenHttpOverrides extends HttpOverrides {
  MoinsenHttpOverrides({HttpOverrides? previous}) : _previous = previous;

  final HttpOverrides? _previous;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final baseClient =
        _previous?.createHttpClient(context) ?? super.createHttpClient(context);
    return _MonitoringHttpClient(baseClient, MoinsenHttpMonitor.instance);
  }
}

/// Wrapping HttpClient that delegates all calls and records traffic.
class _MonitoringHttpClient implements HttpClient {
  _MonitoringHttpClient(this._inner, this._monitor);

  final HttpClient _inner;
  final MoinsenHttpMonitor _monitor;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final sw = Stopwatch()..start();
    try {
      final request = await _inner.openUrl(method, url);
      return _MonitoringRequest(request, method, url, sw, _monitor);
    } on Object catch (e) {
      sw.stop();
      _monitor.record(
        method: method,
        url: url.toString(),
        duration: sw.elapsed,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // Convenience methods that delegate to openUrl.
  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) => openUrl(method, Uri(scheme: 'http', host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  // Pass-through properties.
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;
  @override
  bool get autoUncompress => _inner.autoUncompress;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;
  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;

  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;
  @override
  Duration get idleTimeout => _inner.idleTimeout;

  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;
  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;

  @override
  set userAgent(String? value) => _inner.userAgent = value;
  @override
  String? get userAgent => _inner.userAgent;

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) => _inner.authenticate = f;

  @override
  set authenticateProxy(
    Future<bool> Function(
      String host,
      int port,
      String scheme,
      String? realm,
    )?
    f,
  ) => _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) => _inner.badCertificateCallback = callback;

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )?
    f,
  ) => _inner.connectionFactory = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set keyLog(void Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) => _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) => _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  void close({bool force = false}) => _inner.close(force: force);
}

/// Wrapping HttpClientRequest that records response metrics on close.
class _MonitoringRequest implements HttpClientRequest {
  _MonitoringRequest(
    this._inner,
    this._method,
    this._url,
    this._stopwatch,
    this._monitor,
  );

  final HttpClientRequest _inner;
  final String _method;
  final Uri _url;
  final Stopwatch _stopwatch;
  final MoinsenHttpMonitor _monitor;

  @override
  Future<HttpClientResponse> close() async {
    try {
      final response = await _inner.close();
      _stopwatch.stop();

      // Collect response headers as a simple map.
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(', ');
      });

      // Collect request headers.
      final requestHeaders = <String, String>{};
      headers.forEach((name, values) {
        requestHeaders[name] = values.join(', ');
      });

      _monitor.record(
        method: _method,
        url: _url.toString(),
        statusCode: response.statusCode,
        duration: _stopwatch.elapsed,
        responseSize: response.contentLength,
        requestHeaders: requestHeaders,
        responseHeaders: responseHeaders,
      );

      return response;
    } on Object catch (e) {
      _stopwatch.stop();
      _monitor.record(
        method: _method,
        url: _url.toString(),
        duration: _stopwatch.elapsed,
        error: e.toString(),
      );
      rethrow;
    }
  }

  // Delegate everything else.
  @override
  Encoding get encoding => _inner.encoding;
  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  void add(List<int> data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) =>
      _inner.addStream(stream);

  @override
  Future<HttpClientResponse> get done => _inner.done;

  @override
  Future<dynamic> flush() => _inner.flush();

  @override
  void write(Object? object) => _inner.write(object);

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      _inner.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _inner.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => _inner.writeln(object);

  @override
  bool get bufferOutput => _inner.bufferOutput;
  @override
  set bufferOutput(bool value) => _inner.bufferOutput = value;

  @override
  int get contentLength => _inner.contentLength;
  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  bool get followRedirects => _inner.followRedirects;
  @override
  set followRedirects(bool value) => _inner.followRedirects = value;

  @override
  int get maxRedirects => _inner.maxRedirects;
  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  bool get persistentConnection => _inner.persistentConnection;
  @override
  set persistentConnection(bool value) => _inner.persistentConnection = value;

  @override
  String get method => _inner.method;

  @override
  Uri get uri => _inner.uri;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      _inner.abort(exception, stackTrace);
}
