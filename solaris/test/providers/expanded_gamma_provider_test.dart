import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/providers.dart';
import 'package:solaris/services/monitor_service.dart';

class FakeMonitorService extends MonitorService {
  ExpandedGammaStatus status;
  bool unlockResult;
  bool restartResult;

  FakeMonitorService({
    this.status = ExpandedGammaStatus.disabled,
    this.unlockResult = true,
    this.restartResult = true,
  });

  @override
  Future<ExpandedGammaStatus> getExpandedGammaStatus() async {
    return status;
  }

  @override
  Future<bool> isExpandedGammaUnlocked() async {
    return status == ExpandedGammaStatus.active;
  }

  @override
  Future<bool> unlockExpandedGamma() async {
    if (unlockResult) {
      status = ExpandedGammaStatus.pendingRestart;
    }
    return unlockResult;
  }

  @override
  Future<bool> restartComputer() async {
    return restartResult;
  }
}

void main() {
  group('ExpandedGammaProvider Tests', () {
    test(
      'initial state returns disabled when registry key is missing',
      () async {
        final fakeService = FakeMonitorService(
          status: ExpandedGammaStatus.disabled,
        );
        final container = ProviderContainer(
          overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
        );
        addTearDown(container.dispose);

        final result = await container.read(expandedGammaProvider.future);
        expect(result, equals(ExpandedGammaStatus.disabled));
      },
    );

    test(
      'initial state returns pendingRestart when key written in current session',
      () async {
        final fakeService = FakeMonitorService(
          status: ExpandedGammaStatus.pendingRestart,
        );
        final container = ProviderContainer(
          overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
        );
        addTearDown(container.dispose);

        final result = await container.read(expandedGammaProvider.future);
        expect(result, equals(ExpandedGammaStatus.pendingRestart));
      },
    );

    test(
      'initial state returns active when registry key was effective prior to boot',
      () async {
        final fakeService = FakeMonitorService(
          status: ExpandedGammaStatus.active,
        );
        final container = ProviderContainer(
          overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
        );
        addTearDown(container.dispose);

        final result = await container.read(expandedGammaProvider.future);
        expect(result, equals(ExpandedGammaStatus.active));
      },
    );

    test('unlock updates state to pendingRestart on success', () async {
      final fakeService = FakeMonitorService(
        status: ExpandedGammaStatus.disabled,
        unlockResult: true,
      );
      final container = ProviderContainer(
        overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final initial = await container.read(expandedGammaProvider.future);
      expect(initial, equals(ExpandedGammaStatus.disabled));

      final unlockSuccess = await container
          .read(expandedGammaProvider.notifier)
          .unlock();
      expect(unlockSuccess, isTrue);

      final updated = await container.read(expandedGammaProvider.future);
      expect(updated, equals(ExpandedGammaStatus.pendingRestart));
    });

    test(
      'unlock leaves state as disabled when user cancels UAC elevation',
      () async {
        final fakeService = FakeMonitorService(
          status: ExpandedGammaStatus.disabled,
          unlockResult: false,
        );
        final container = ProviderContainer(
          overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
        );
        addTearDown(container.dispose);

        final unlockSuccess = await container
            .read(expandedGammaProvider.notifier)
            .unlock();
        expect(unlockSuccess, isFalse);

        final current = await container.read(expandedGammaProvider.future);
        expect(current, equals(ExpandedGammaStatus.disabled));
      },
    );

    test('restartComputer delegates to monitorService', () async {
      final fakeService = FakeMonitorService(restartResult: true);
      final container = ProviderContainer(
        overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final success = await container
          .read(expandedGammaProvider.notifier)
          .restartComputer();
      expect(success, isTrue);
    });

    test(
      'refresh performs quiet background update without wiping state',
      () async {
        final fakeService = FakeMonitorService(
          status: ExpandedGammaStatus.disabled,
        );
        final container = ProviderContainer(
          overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
        );
        addTearDown(container.dispose);

        await container.read(expandedGammaProvider.future);
        expect(
          container.read(expandedGammaProvider).value,
          equals(ExpandedGammaStatus.disabled),
        );

        fakeService.status = ExpandedGammaStatus.active;
        await container.read(expandedGammaProvider.notifier).refresh();

        expect(
          container.read(expandedGammaProvider).value,
          equals(ExpandedGammaStatus.active),
        );
      },
    );

    test('unlock guards against concurrent execution', () async {
      final fakeService = FakeMonitorService(
        status: ExpandedGammaStatus.disabled,
        unlockResult: true,
      );
      final container = ProviderContainer(
        overrides: [monitorServiceProvider.overrideWithValue(fakeService)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(expandedGammaProvider.notifier);
      final future1 = notifier.unlock();
      final future2 = notifier.unlock();

      final results = await Future.wait([future1, future2]);
      expect(results.contains(true), isTrue);
      expect(results.contains(false), isTrue);
    });
  });
}
