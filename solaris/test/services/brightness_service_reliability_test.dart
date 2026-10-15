import 'dart:async';

import '../helpers/wait_until.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/brightness_service.dart';
import 'package:solaris/services/monitor_service.dart';

class _Hardware extends MonitorService {
  final writes = <({String device, int value, bool overlay})>[];
  Future<bool> Function(int)? write;
  int physical = 99;

  @override
  Future<bool> setBrightness(
    String deviceName,
    int brightness, {
    bool isOverlayOnly = false,
  }) async {
    writes.add((device: deviceName, value: brightness, overlay: isOverlayOnly));
    final accepted = await (write?.call(brightness) ?? Future.value(true));
    if (accepted) physical = brightness;
    return accepted;
  }
}

MonitorInfo _monitor({
  int? value = 99,
  bool ddc = true,
  String device = 'DISPLAY1',
}) => MonitorInfo(
  id: device,
  name: device,
  friendlyName: device,
  deviceName: device,
  deviceIdHash: device,
  isPrimary: true,
  realBrightness: value,
  isDdcSupported: ddc,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Brightness transition reliability', () {
    late BrightnessService service;
    late _Hardware hardware;
    late List<int> reported;

    void apply(
      double target, {
      MonitorInfo? monitor,
      bool manual = true,
      bool visible = true,
      bool dimming = true,
      Map<String, double>? offsets,
    }) {
      service.applyBrightnessSmoothly(
        selection: 'all',
        targetValue: target,
        monitors: [monitor ?? _monitor()],
        monitorService: hardware,
        updateBrightnessCallback: (_, value) => reported.add(value),
        isManual: manual,
        isUIVisible: visible,
        isSoftwareDimmingEnabled: dimming,
        offsets: offsets,
      );
    }

    setUp(() {
      service = BrightnessService();
      hardware = _Hardware();
      reported = [];
      addTearDown(service.dispose);
    });

    test(
      'state changes only after the pending hardware write succeeds',
      () async {
        final completion = Completer<bool>();
        hardware.write = (_) => completion.future;
        apply(76);
        expect(hardware.writes.single.value, 87);
        expect(reported, isEmpty);
        expect(service.getCurrentHardwareBrightness('DISPLAY1'), isNull);
        hardware.write = null;
        completion.complete(true);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(hardware.physical, 76);
        expect(reported, [87, 81, 76]);
        expect(service.getCurrentHardwareBrightness('DISPLAY1'), 76);
      },
    );

    test(
      'visible automatic changes advance in one-percent steps faster than before',
      () async {
        apply(100, monitor: _monitor(value: 80), manual: false);
        await Future<void>.delayed(const Duration(milliseconds: 650));
        expect(hardware.physical, 100);
        expect(reported, List.generate(20, (index) => 81 + index));
        expect(service.isTransitioning('DISPLAY1'), false);
      },
    );

    test(
      'slow automatic writes remain serial and adapt their step size',
      () async {
        var activeWrites = 0;
        hardware.write = (_) async {
          activeWrites++;
          expect(activeWrites, 1);
          await Future<void>.delayed(const Duration(milliseconds: 60));
          activeWrites--;
          return true;
        };
        apply(100, monitor: _monitor(value: 80), manual: false);
        await Future<void>.delayed(const Duration(milliseconds: 750));
        expect(hardware.physical, 100);
        expect(reported.first, 81);
        expect(reported.last, 100);
        expect(reported.length, lessThan(20));
        for (var i = 1; i < reported.length; i++) {
          expect(reported[i] - reported[i - 1], inInclusiveRange(1, 5));
        }
      },
    );

    test(
      'permanent failure stops after three attempts and remains retryable',
      () async {
        hardware.write = (_) async => false;
        apply(76);
        await Future<void>.delayed(const Duration(milliseconds: 450));
        expect(hardware.writes.map((c) => c.value), [87, 87, 87]);
        expect(hardware.physical, 99);
        expect(reported, isEmpty);
        expect(service.getCurrentHardwareBrightness('DISPLAY1'), isNull);
        hardware.writes.clear();
        hardware.write = null;
        apply(76);
        await waitUntil(
          () => !service.isTransitioning('DISPLAY1'),
          reason:
              'The recovery transition must finish after writes become available',
        );
        expect(hardware.physical, 76);
        expect(hardware.writes.last.value, 76);
        expect(reported.last, 76);
      },
    );

    test(
      'transient failure retries the same step without inventing progress',
      () async {
        var attempts = 0;
        hardware.write = (_) async => ++attempts > 1;
        apply(76);
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(hardware.writes.map((c) => c.value), [87, 87, 81, 76]);
        expect(reported, [87, 81, 76]);
        expect(hardware.physical, 76);
      },
    );

    test('a thrown write error is bounded and can recover', () async {
      var attempts = 0;
      hardware.write = (_) async {
        if (++attempts == 1) throw StateError('Disconnected');
        return true;
      };
      apply(93);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(hardware.writes.map((c) => c.value), [93, 93]);
      expect(reported, [93]);
    });

    test(
      'returning to the starting value supersedes an in-flight transition',
      () async {
        final completion = Completer<bool>();
        hardware.write = (_) => completion.future;
        apply(76);
        apply(99);
        expect(hardware.writes, hasLength(1));
        hardware.write = null;
        completion.complete(true);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(hardware.physical, 99);
        expect(hardware.writes.map((c) => c.value), [87, 93, 99]);
        expect(reported.last, 99);
      },
    );

    test(
      'an automatic target supersedes manual restoration in flight',
      () async {
        final completion = Completer<bool>();
        hardware.write = (_) => completion.future;
        apply(76);
        apply(99, manual: false, visible: false);
        hardware.write = null;
        completion.complete(true);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(hardware.writes.map((c) => c.value), [87, 99]);
        expect(hardware.physical, 99);
      },
    );

    test(
      'unknown initial hardware brightness still receives the target',
      () async {
        apply(76, monitor: _monitor(value: null));
        await Future<void>.delayed(Duration.zero);
        expect(hardware.writes.single.value, 76);
        expect(reported, [76]);
      },
    );

    test(
      'aligned confirmed targets do not produce redundant hardware writes',
      () async {
        apply(93);
        await Future<void>.delayed(Duration.zero);
        hardware.writes.clear();
        for (var i = 0; i < 20; i++) {
          apply(93, monitor: _monitor(value: 93));
        }
        await Future<void>.delayed(Duration.zero);
        expect(hardware.writes, isEmpty);
      },
    );

    test(
      'dispose suppresses reporting and further writes after an in-flight result',
      () async {
        final completion = Completer<bool>();
        hardware.write = (_) => completion.future;
        apply(76);
        service.dispose();
        completion.complete(true);
        await Future<void>.delayed(const Duration(milliseconds: 150));
        apply(50);
        expect(hardware.writes, hasLength(1));
        expect(reported, isEmpty);
      },
    );

    for (final ddc in [true, false]) {
      test('negative manual target obeys DDC capability: ddc=$ddc', () async {
        apply(-30, monitor: _monitor(value: 0, ddc: ddc));
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (ddc) {
          expect(hardware.writes.last.value, -30);
          expect(hardware.writes.every((c) => !c.overlay), isTrue);
        } else {
          expect(hardware.writes, isEmpty);
          expect(service.getCurrentHardwareBrightness('DISPLAY1'), 0);
        }
      });
    }

    test('software dimming disabled clamps negative offsets to zero', () async {
      apply(
        5,
        monitor: _monitor(value: 10),
        dimming: false,
        offsets: {'DISPLAY1': -20},
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(hardware.writes.map((c) => c.value), [4, 0]);
      expect(reported.last, 0);
    });

    test(
      'leaving software dimming removes negative brightness immediately',
      () async {
        service.syncHardwareBrightness('DISPLAY1', -30);
        apply(0, monitor: _monitor(value: -30), manual: false);
        await Future<void>.delayed(Duration.zero);
        expect(hardware.writes.map((c) => c.value), [0]);
        expect(reported, [0]);
      },
    );

    test('non-finite targets do not reach hardware', () {
      apply(double.nan);
      apply(double.infinity);
      expect(hardware.writes, isEmpty);
    });

    test(
      'a failed partial write cannot hide restoration to the previously confirmed value',
      () async {
        service.syncHardwareBrightness('DISPLAY1', 76);
        hardware.physical = 76;
        final completion = Completer<bool>();
        hardware.write = (_) => completion.future;
        apply(30, monitor: _monitor(value: 76));
        apply(76, monitor: _monitor(value: 76));
        hardware.physical = 64;
        hardware.write = null;
        completion.complete(false);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(hardware.writes.map((c) => c.value), [64, 76]);
        expect(hardware.physical, 76);
        expect(reported, [76]);
      },
    );
  });

  group('Native channel write cache', () {
    const channel = MethodChannel('com.solaris.monitor/names');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late MonitorService service;
    late int observed;
    late bool accepted;
    late List<int> writes;

    setUp(() {
      service = MonitorService();
      observed = 99;
      accepted = true;
      writes = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getMonitorBrightness') return observed;
        if (call.method == 'setMonitorBrightness') {
          final value = (call.arguments as Map)['brightness'] as int;
          writes.add(value);
          if (accepted) observed = value;
          return accepted;
        }
        return null;
      });
      addTearDown(() {
        service.dispose();
        messenger.setMockMethodCallHandler(channel, null);
      });
    });

    test(
      'observed external change allows resending a previously applied value',
      () async {
        expect(await service.setBrightness('DISPLAY1', 76), isTrue);
        expect(await service.setBrightness('DISPLAY1', 76), isTrue);
        expect(writes, [76]);
        observed = 99;
        expect(
          await service.getBrightness('DISPLAY1', probeHardware: true),
          99,
        );
        expect(await service.setBrightness('DISPLAY1', 76), isTrue);
        expect(writes, [76, 76]);
      },
    );

    test('failed channel writes do not poison deduplication', () async {
      accepted = false;
      expect(await service.setBrightness('DISPLAY1', 76), isFalse);
      accepted = true;
      expect(await service.setBrightness('DISPLAY1', 76), isTrue);
      expect(writes, [76, 76]);
    });

    test(
      'a failed change does not suppress reasserting a previously successful value',
      () async {
        await service.setBrightness('DISPLAY1', 76);
        accepted = false;
        expect(await service.setBrightness('DISPLAY1', 30), isFalse);
        observed = 76;
        await service.getBrightness('DISPLAY1', probeHardware: true);
        accepted = true;
        await service.setBrightness('DISPLAY1', 76);
        expect(writes, [76, 30, 76]);
      },
    );

    test(
      'an older read cannot overwrite the cache of a newer acknowledged write',
      () async {
        final completion = Completer<int>();
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getMonitorBrightness') return completion.future;
          if (call.method == 'setMonitorBrightness') {
            writes.add((call.arguments as Map)['brightness'] as int);
            return true;
          }
          return null;
        });
        final reading = service.getBrightness('DISPLAY1');
        await Future<void>.delayed(Duration.zero);
        await service.setBrightness('DISPLAY1', 76);
        completion.complete(99);
        expect(await reading, 99);
        await service.setBrightness('DISPLAY1', 76);
        expect(writes, [76]);
      },
    );

    test(
      'physical floor observation preserves successful software dimming',
      () async {
        expect(await service.setBrightness('DISPLAY1', -30), isTrue);
        observed = 1;
        expect(await service.getBrightness('DISPLAY1', probeHardware: true), 1);
        expect(await service.setBrightness('DISPLAY1', -30), isTrue);
        expect(writes, [-30]);
      },
    );
  });
}
