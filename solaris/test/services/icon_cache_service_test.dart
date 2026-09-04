import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/icon_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => Directory.systemTemp.path,
        );
  });

  const MethodChannel channel = MethodChannel('com.solaris.monitor/icons');

  setUp(() {
    IconCacheService.resetInstance();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    IconCacheService.resetInstance();
  });

  group('IconCacheService Basic & Deduplication Tests', () {
    test('returns null for empty name or Unknown.exe', () async {
      final service = await IconCacheService.instance;
      expect(await service.getCachedIconPath(''), isNull);
      expect(await service.getCachedIconPath('Unknown.exe'), isNull);
    });

    test('deduplicates concurrent requests for the same executable', () async {
      int invokeCount = 0;
      final completer = Completer<String?>();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'extractAppIcon') {
              invokeCount++;
              return await completer.future;
            }
            return null;
          });

      final service = await IconCacheService.instance;

      // Dispatch two concurrent requests with different casing
      final future1 = service.getCachedIconPath('Discord.exe');
      final future2 = service.getCachedIconPath('discord.exe');

      completer.complete('');
      await Future.wait([future1, future2]);

      // Only one native call should have been triggered due to dedupe key normalization
      expect(invokeCount, 1);
    });

    test(
      'deduplicates requests for names with and without .exe extension',
      () async {
        int invokeCount = 0;
        final completer = Completer<String?>();

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'extractAppIcon') {
                invokeCount++;
                return await completer.future;
              }
              return null;
            });

        final service = await IconCacheService.instance;

        final future1 = service.getCachedIconPath('Code');
        final future2 = service.getCachedIconPath('code.exe');

        completer.complete('');
        await Future.wait([future1, future2]);

        expect(invokeCount, 1);
      },
    );

    test('normalizes names with dots by ensuring .exe extension', () async {
      int invokeCount = 0;
      final completer = Completer<String?>();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'extractAppIcon') {
              invokeCount++;
              return await completer.future;
            }
            return null;
          });

      final service = await IconCacheService.instance;

      final future1 = service.getCachedIconPath('Kyiv.Editor.v2');
      final future2 = service.getCachedIconPath('kyiv.editor.v2.exe');

      completer.complete('');
      await Future.wait([future1, future2]);

      expect(invokeCount, 1);
    });

    test(
      'distinguishes executables with the same name on different paths',
      () async {
        final calls = <MethodCall>[];
        final completer = Completer<String?>();

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'extractAppIcon') {
                calls.add(call);
                return await completer.future;
              }
              return null;
            });

        final service = await IconCacheService.instance;

        // Two distinct apps that share the common name "launcher.exe"
        final future1 = service.getCachedIconPath(
          'launcher.exe',
          exePath: r'C:\Games\KyivQuest\launcher.exe',
        );
        final future2 = service.getCachedIconPath(
          'launcher.exe',
          exePath: r'C:\Tools\KyivStudio\launcher.exe',
        );

        completer.complete('');
        await Future.wait([future1, future2]);

        // Both requests should trigger separate extractions because exePath is distinct
        expect(calls.length, 2);
        final savePath1 = (calls[0].arguments as Map)['savePath'] as String;
        final savePath2 = (calls[1].arguments as Map)['savePath'] as String;
        expect(savePath1, isNot(equals(savePath2)));
      },
    );

    test(
      'handles method channel exceptions gracefully without throwing',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              throw PlatformException(
                code: 'EXTRACTION_FAILED',
                message: 'Failed',
              );
            });

        final service = await IconCacheService.instance;
        final result = await service.getCachedIconPath('CrashingApp.exe');
        expect(result, isNull);
      },
    );

    test('handles timeout without hanging in-flight requests', () async {
      // Simulate hanging method channel call
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            if (call.method == 'extractAppIcon') {
              // Never completes
              await Completer<void>().future;
            }
            return null;
          });

      final service = await IconCacheService.instance;

      // Request icon with a timeout
      final result = await service.getCachedIconPath('HangingApp.exe');

      expect(result, isNull);
      // Verify subsequent request does not get blocked by old in-flight future
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            return '';
          });

      final retryResult = await service.getCachedIconPath('HangingApp.exe');
      expect(retryResult, isNull);
    });
  });

  group('IconCacheService Concurrency Limiter Tests', () {
    test(
      'limits simultaneous native extractions to at most maxConcurrentExtractions',
      () async {
        int activeCalls = 0;
        int maxObservedConcurrentCalls = 0;
        final completers = List.generate(12, (_) => Completer<String?>());

        int callIndex = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'extractAppIcon') {
                activeCalls++;
                if (activeCalls > maxObservedConcurrentCalls) {
                  maxObservedConcurrentCalls = activeCalls;
                }
                final idx = callIndex++;
                final res = await completers[idx].future;
                activeCalls--;
                return res;
              }
              return null;
            });

        final service = await IconCacheService.instance;

        // Dispatch 12 requests concurrently with distinct names
        final futures = List.generate(
          12,
          (i) => service.getCachedIconPath('UniqueApp$i.exe'),
        );

        // Yield event loop to let requests start and enter queue
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(
          maxObservedConcurrentCalls,
          lessThanOrEqualTo(IconCacheService.maxConcurrentExtractions),
        );
        expect(
          service.activeExtractions,
          IconCacheService.maxConcurrentExtractions,
        );
        expect(service.queueLength, 8);

        // Complete first batch of 4
        for (int i = 0; i < 4; i++) {
          completers[i].complete('');
        }

        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(
          maxObservedConcurrentCalls,
          lessThanOrEqualTo(IconCacheService.maxConcurrentExtractions),
        );
        expect(
          service.activeExtractions,
          IconCacheService.maxConcurrentExtractions,
        );
        expect(service.queueLength, 4);

        // Complete remaining 8
        for (int i = 4; i < 12; i++) {
          completers[i].complete('');
        }

        await Future.wait(futures);

        expect(
          maxObservedConcurrentCalls,
          lessThanOrEqualTo(IconCacheService.maxConcurrentExtractions),
        );
        expect(service.activeExtractions, 0);
        expect(service.queueLength, 0);
      },
    );
  });

  group('IconCacheService File Validation Tests', () {
    test(
      'deletes cache file exceeding 64 bytes if PNG magic header is invalid',
      () async {
        String? targetSavePath;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'extractAppIcon') {
                final args = call.arguments as Map;
                targetSavePath = args['savePath'] as String;
                final file = File(targetSavePath!);
                await file.parent.create(recursive: true);
                // Write 100 corrupt bytes without PNG magic bytes
                await file.writeAsBytes(List<int>.filled(100, 0xAA));
                return targetSavePath;
              }
              return null;
            });

        final service = await IconCacheService.instance;
        final result = await service.getCachedIconPath('KyivCorruptApp.exe');

        expect(result, isNull);
        expect(targetSavePath, isNotNull);
        expect(await File(targetSavePath!).exists(), isFalse);
      },
    );

    test(
      'retains cache file exceeding 64 bytes if PNG magic header is valid',
      () async {
        String? targetSavePath;
        final validPng = <int>[
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG magic header
          ...List<int>.filled(60, 0x00), // > 64 bytes total
        ];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'extractAppIcon') {
                final args = call.arguments as Map;
                targetSavePath = args['savePath'] as String;
                final file = File(targetSavePath!);
                await file.parent.create(recursive: true);
                await file.writeAsBytes(validPng);
                return targetSavePath;
              }
              return null;
            });

        final service = await IconCacheService.instance;
        final result = await service.getCachedIconPath('KyivValidApp.exe');

        expect(result, equals(targetSavePath));
        expect(targetSavePath, isNotNull);
        expect(await File(targetSavePath!).exists(), isTrue);

        try {
          await File(targetSavePath!).delete();
        } catch (_) {}
      },
    );
  });
}
