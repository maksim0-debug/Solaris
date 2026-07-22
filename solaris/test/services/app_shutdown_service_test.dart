import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:solaris/services/app_shutdown_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppShutdownService Tests', () {
    test('performShutdown executes steps without throwing exceptions', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final shutdownService = AppShutdownService(container);

      // Verify that performShutdown finishes smoothly with exitProcess: false
      await expectLater(
        shutdownService.performShutdown(exitProcess: false),
        completes,
      );
    });

    test('appShutdownServiceProvider instantiates AppShutdownService correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final shutdownService = container.read(appShutdownServiceProvider(container));
      expect(shutdownService, isA<AppShutdownService>());
      expect(shutdownService.container, equals(container));
    });
  });
}
