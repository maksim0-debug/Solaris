import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart';
import 'package:http/retry.dart';

/// Drop-in replacement for [NetworkTileProvider] that forcefully closes
/// its [HttpClient] on dispose instead of waiting for all in-flight tile
/// requests to complete.
///
/// The stock [NetworkTileProvider.dispose()] calls
/// `Future.wait(_tilesInProgress.values.map((c) => c.future))`
/// which blocks until every HTTP response arrives and every PNG/JPEG is decoded
/// by the Flutter engine. During that period the process continues to consume
/// CPU (HTTP I/O + Dart isolate codec) and GPU (hardware-accelerated image decode),
/// even though the widget tree is already destroyed via SizedBox.shrink().
///
/// This provider calls `_httpClient.close()` immediately, which aborts all
/// pending HTTP requests and allows the process to drop CPU/GPU to 0% within
/// a single frame.
class CancelableNetworkTileProvider extends TileProvider {
  CancelableNetworkTileProvider({
    super.headers,
    BaseClient? httpClient,
    bool? ownsHttpClient,
  }) : _httpClient = httpClient ?? RetryClient(Client()),
       _ownsHttpClient = ownsHttpClient ?? (httpClient == null);

  final BaseClient _httpClient;
  final bool _ownsHttpClient;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _CancelableNetworkImageProvider(
        getTileUrl(coordinates, options),
        _httpClient,
        headers: headers,
      );

  /// Force-close the HTTP client if owned, aborting all in-flight tile downloads.
  ///
  /// Unlike [NetworkTileProvider.dispose()], this does NOT await pending
  /// requests — it terminates them immediately.
  @override
  void dispose() {
    if (_ownsHttpClient) {
      try {
        _httpClient.close();
      } catch (e) {
        debugPrint('CancelableNetworkTileProvider: close failed: $e');
      }
    }
    super.dispose();
  }
}

class _CancelableNetworkImageProvider
    extends ImageProvider<_CancelableNetworkImageProvider> {
  const _CancelableNetworkImageProvider(
    this.url,
    this.httpClient, {
    this.headers,
  });

  final String url;
  final BaseClient httpClient;
  final Map<String, String>? headers;

  @override
  Future<_CancelableNetworkImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<_CancelableNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _CancelableNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<_CancelableNetworkImageProvider>('Image key', key),
      ],
    );
  }

  Future<Codec> _loadAsync(
    _CancelableNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final Uri resolved = Uri.parse(key.url);
      final response = await key.httpClient.get(resolved, headers: key.headers);
      if (response.statusCode != 200) {
        throw NetworkImageLoadException(
          statusCode: response.statusCode,
          uri: resolved,
        );
      }
      final Uint8List bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        throw Exception('NetworkImage is an empty file: $resolved');
      }
      final ImmutableBuffer buffer = await ImmutableBuffer.fromUint8List(bytes);
      return await decode(buffer);
    } catch (e) {
      if (e is ClientException) {
        debugPrint(
          'CancelableNetworkImageProvider: request canceled for ${key.url}: $e',
        );
      }
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CancelableNetworkImageProvider && other.url == url);

  @override
  int get hashCode => url.hashCode;
}
