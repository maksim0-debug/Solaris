import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solaris/widgets/cancelable_network_tile_provider.dart';

void main() {
  group('CancelableNetworkTileProvider Unit Tests', () {
    test(
      'getImage returns _CancelableNetworkImageProvider with custom httpClient',
      () {
        final mockClient = MockClient((request) async {
          return http.Response('', 200);
        });

        final provider = CancelableNetworkTileProvider(httpClient: mockClient);
        final coords = const TileCoordinates(1, 2, 3);
        final options = TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        );

        final imageProvider = provider.getImage(coords, options);

        expect(imageProvider, isNotNull);
        expect(
          imageProvider.runtimeType.toString(),
          contains('CancelableNetworkImageProvider'),
        );

        provider.dispose();
        // Closing provider does not crash
        expect(() => provider.dispose(), returnsNormally);
      },
    );

    test('dispose force closes httpClient when owned', () {
      bool isClosed = false;
      final client = _TrackingClient(() => isClosed = true);
      final provider = CancelableNetworkTileProvider(
        httpClient: client,
        ownsHttpClient: true,
      );

      provider.dispose();
      expect(isClosed, isTrue);
    });

    test(
      'dispose preserves external httpClient when ownsHttpClient is false',
      () {
        bool isClosed = false;
        final client = _TrackingClient(() => isClosed = true);
        final provider = CancelableNetworkTileProvider(
          httpClient: client,
          ownsHttpClient: false,
        );

        provider.dispose();
        expect(isClosed, isFalse);
      },
    );
  });
}

class _TrackingClient extends http.BaseClient {
  final void Function() onClose;
  _TrackingClient(this.onClose);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
  }

  @override
  void close() {
    onClose();
    super.close();
  }
}
