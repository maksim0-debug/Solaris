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
  }) : _httpClient = httpClient ?? RetryClient(Client());

  final BaseClient _httpClient;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      NetworkImage(
        getTileUrl(coordinates, options),
        headers: headers,
      );

  /// Force-close the HTTP client, aborting all in-flight tile downloads.
  ///
  /// Unlike [NetworkTileProvider.dispose()], this does NOT await pending
  /// requests — it terminates them immediately.
  @override
  void dispose() {
    try {
      _httpClient.close();
    } catch (e) {
      debugPrint('CancelableNetworkTileProvider: close failed: $e');
    }
    super.dispose();
  }
}
