import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/services/accent_color_extractor.dart';
import 'package:solaris/services/icon_cache_service.dart';
import 'package:solaris/widgets/glowing_app_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async => Directory.systemTemp.path,
        );
  });

  group('AccentColorExtractor Tests', () {
    test('colorToHex and hexToColor formatting and parsing', () {
      const color = Color(0xFF6366F1);
      final hex = AccentColorExtractor.colorToHex(color);
      expect(hex, '#6366F1');

      final parsed = AccentColorExtractor.hexToColor(hex);
      expect(parsed.toARGB32(), color.toARGB32());
    });

    test('hexToColor returns fallback on invalid hex', () {
      const fallback = Color(0xFFFF0000);
      final parsed = AccentColorExtractor.hexToColor('invalid-hex', fallback);
      expect(parsed, fallback);
    });
  });

  group('GlowingAppIcon Widget Tests', () {
    testWidgets('renders fallback letter avatar with first letter of name', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GlowingAppIcon(name: 'Photoshop.exe', size: 36)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GlowingAppIcon), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
    });

    testWidgets('renders fallback letter avatar with custom fallbackLetter', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlowingAppIcon(
              name: 'code.exe',
              fallbackLetter: 'Visual Studio Code',
              size: 40,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(GlowingAppIcon), findsOneWidget);
      expect(find.text('V'), findsOneWidget);
    });

    testWidgets(
      'renders fallback letter avatar when fallbackLetter has leading whitespace or only spaces',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: GlowingAppIcon(
                name: 'KyivTool.exe',
                fallbackLetter: '   Kyiv Tool   ',
                size: 40,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(GlowingAppIcon), findsOneWidget);
        expect(find.text('K'), findsOneWidget);

        // When fallbackLetter is only whitespace, fall back to exe name
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: GlowingAppIcon(
                name: 'KyivApp.exe',
                fallbackLetter: '    ',
                size: 40,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('K'), findsOneWidget);
      },
    );

    testWidgets(
      'renders correct emoji fallback when app name or fallbackLetter starts with an emoji',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: GlowingAppIcon(
                name: 'RocketTool.exe',
                fallbackLetter: '🚀 Kyiv Space Monitor',
                size: 40,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(GlowingAppIcon), findsOneWidget);
        expect(find.text('🚀'), findsOneWidget);
      },
    );

    testWidgets('triggers onTap callback when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlowingAppIcon(
              name: 'Discord.exe',
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(GlowingAppIcon));
      await tester.pump();

      expect(tapped, isTrue);
    });

    test('clearCacheFor handles case insensitivity without error', () {
      expect(
        () => GlowingAppIcon.clearCacheFor('Discord.exe'),
        returnsNormally,
      );
      expect(
        () => GlowingAppIcon.clearCacheFor('discord.exe'),
        returnsNormally,
      );
      expect(
        () => GlowingAppIcon.clearCacheFor('DISCORD.EXE'),
        returnsNormally,
      );
    });

    testWidgets(
      'parent rebuild does not cause duplicate load cycles or error',
      (tester) async {
        int buildCount = 0;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              buildCount++;
              return MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      const GlowingAppIcon(name: 'TestApp.exe', size: 36),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Rebuild'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

        await tester.pumpAndSettle();
        expect(buildCount, 1);

        // Trigger rebuild
        await tester.tap(find.text('Rebuild'));
        await tester.pumpAndSettle();
        expect(buildCount, 2);
        expect(find.byType(GlowingAppIcon), findsOneWidget);
      },
    );

    testWidgets(
      'retries loading when exePath is updated after an initial failure',
      (tester) async {
        GlowingAppIcon.resetStaticCaches();
        IconCacheService.resetInstance();

        const channel = MethodChannel('com.solaris.monitor/icons');
        final calls = <MethodCall>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              calls.add(call);
              return null;
            });

        await tester.runAsync(() async {
          // 1. Initial build without exePath -> fails and records failure
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: GlowingAppIcon(name: 'KyivEditor.exe', size: 36),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();

          expect(find.byType(GlowingAppIcon), findsOneWidget);
          expect(find.text('K'), findsOneWidget);
          expect(calls.length, 1);
          expect(GlowingAppIcon.isFailed('KyivEditor.exe'), isTrue);

          // 2. Update widget with explicit exePath -> invalidates failed cache and retries
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: GlowingAppIcon(
                  name: 'KyivEditor.exe',
                  exePath: r'C:\Tools\KyivEditor.exe',
                  size: 36,
                ),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();

          expect(calls.length, 2);
          final secondCallArgs = calls[1].arguments as Map;
          expect(secondCallArgs['exePath'], r'C:\Tools\KyivEditor.exe');
        });
      },
    );

    testWidgets(
      'does not treat icon as failed when mounted with explicit exePath even if key is in failed cache',
      (tester) async {
        GlowingAppIcon.resetStaticCaches();
        IconCacheService.resetInstance();

        const channel = MethodChannel('com.solaris.monitor/icons');
        final calls = <MethodCall>[];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              calls.add(call);
              return null;
            });

        await tester.runAsync(() async {
          // 1. First app without exePath fails
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: GlowingAppIcon(name: 'KyivViewer.exe', size: 36),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();

          expect(calls.length, 1);
          expect(GlowingAppIcon.isFailed('KyivViewer.exe'), isTrue);

          // 2. Another widget instance for KyivViewer.exe with explicit exePath
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: GlowingAppIcon(
                  name: 'KyivViewer.exe',
                  exePath: r'C:\Tools\KyivViewer.exe',
                  size: 36,
                ),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();

          // Should have attempted to load KyivViewer.exe again with the explicit path
          expect(calls.length, 2);
          final secondCallArgs = calls[1].arguments as Map;
          expect(secondCallArgs['exePath'], r'C:\Tools\KyivViewer.exe');
        });
      },
    );

    testWidgets(
      'recycles widget cleanly when name changes to an app that fails to load',
      (tester) async {
        GlowingAppIcon.resetStaticCaches();
        IconCacheService.resetInstance();

        const channel = MethodChannel('com.solaris.monitor/icons');
        final dummyPng = <int>[
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
          0,
          0,
          0,
          13,
          73,
          72,
          68,
          82,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          1,
          8,
          6,
          0,
          0,
          0,
          31,
          21,
          196,
          137,
          0,
          0,
          0,
          10,
          73,
          68,
          65,
          84,
          120,
          156,
          99,
          0,
          1,
          0,
          0,
          5,
          0,
          1,
          13,
          10,
          45,
          180,
          0,
          0,
          0,
          0,
          73,
          69,
          78,
          68,
          174,
          66,
          96,
          130,
        ];

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'extractAppIcon') {
                final args = call.arguments as Map;
                final exePath = (args['exePath'] as String).toLowerCase();
                if (exePath.contains('appwithicon')) {
                  final savePath = args['savePath'] as String;
                  await File(savePath).writeAsBytes(dummyPng);
                  return savePath;
                }
              }
              return null;
            });

        await tester.runAsync(() async {
          // 1. Initial widget has valid icon
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: GlowingAppIcon(name: 'AppWithIcon.exe', size: 36),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();

          expect(find.byType(Image), findsOneWidget);
          expect(find.text('A'), findsNothing);

          // 2. Recycle widget with another app that has NO icon (fails)
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: GlowingAppIcon(name: 'FailingApp.exe', size: 36),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();

          // Must show fallback letter for FailingApp and NOT keep the old image
          expect(find.byType(Image), findsNothing);
          expect(find.text('F'), findsOneWidget);
        });
      },
    );

    testWidgets(
      'rapid updates to exePath do not let slower previous load overwrite newer load',
      (tester) async {
        GlowingAppIcon.resetStaticCaches();
        IconCacheService.resetInstance();

        const channel = MethodChannel('com.solaris.monitor/icons');
        final dummyPng = <int>[
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
          0,
          0,
          0,
          13,
          73,
          72,
          68,
          82,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          1,
          8,
          6,
          0,
          0,
          0,
          31,
          21,
          196,
          137,
          0,
          0,
          0,
          10,
          73,
          68,
          65,
          84,
          120,
          156,
          99,
          0,
          1,
          0,
          0,
          5,
          0,
          1,
          13,
          10,
          45,
          180,
          0,
          0,
          0,
          0,
          73,
          69,
          78,
          68,
          174,
          66,
          96,
          130,
        ];

        final slowCompleter = Completer<String?>();
        final fastCompleter = Completer<String?>();

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'extractAppIcon') {
                final args = call.arguments as Map;
                final exePath = (args['exePath'] as String).toLowerCase();
                if (exePath.contains('validpath')) {
                  final savePath = args['savePath'] as String;
                  await File(savePath).writeAsBytes(dummyPng);
                  await fastCompleter.future;
                  return savePath;
                } else {
                  await slowCompleter.future;
                  return null;
                }
              }
              return null;
            });

        await tester.runAsync(() async {
          // 1. Initial build without exePath (triggers slow load)
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: GlowingAppIcon(name: 'RaceApp.exe', size: 36),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // 2. Immediate update with valid exePath before slow load finishes
          await tester.pumpWidget(
            const MaterialApp(
              home: Scaffold(
                body: GlowingAppIcon(
                  name: 'RaceApp.exe',
                  exePath: r'C:\ValidPath\RaceApp.exe',
                  size: 36,
                ),
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));

          // 3. Fast load finishes first with success
          fastCompleter.complete('');
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();

          expect(find.byType(Image), findsOneWidget);

          // 4. Slow load finishes later with failure
          slowCompleter.complete(null);
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();

          // Slower older failure must NOT have overwritten the successful load
          expect(find.byType(Image), findsOneWidget);
          expect(find.text('R'), findsNothing);
        });
      },
    );

    testWidgets(
      'errorBuilder records failure timestamp, deletes corrupt file, and switches cleanly to fallback avatar',
      (tester) async {
        GlowingAppIcon.resetStaticCaches();
        IconCacheService.resetInstance();

        const channel = MethodChannel('com.solaris.monitor/icons');
        // Valid PNG magic header (8 bytes) followed by invalid/corrupted PNG chunk payload (> 64 bytes).
        // This passes IconCacheService._isValidCacheFile initial validation so it reaches Image.file,
        // but fails Flutter's image decoding pipeline, directly exercising errorBuilder.
        final corruptBytes = <int>[
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          ...List<int>.filled(80, 0xFF),
        ];
        String? corruptPath;

        final testAppName =
            'CorruptApp_${DateTime.now().microsecondsSinceEpoch}.exe';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'extractAppIcon') {
                final args = call.arguments as Map;
                corruptPath = args['savePath'] as String;
                await File(corruptPath!).writeAsBytes(corruptBytes);
                return corruptPath;
              }
              return null;
            });

        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: GlowingAppIcon(name: testAppName, size: 36)),
            ),
          );

          await Future<void>.delayed(const Duration(milliseconds: 400));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await tester.pump();
          await tester.pump();

          // Image.file internally reports the codec exception to FlutterError; consume it
          tester.takeException();

          expect(find.text('C'), findsOneWidget);
          expect(GlowingAppIcon.isFailed(testAppName), isTrue);
          expect(corruptPath, isNotNull);
          expect(File(corruptPath!).existsSync(), isFalse);
        });
      },
    );

    testWidgets('didUpdateWidget does not clear _failedIcons on widget recycling', (
      tester,
    ) async {
      GlowingAppIcon.resetStaticCaches();
      IconCacheService.resetInstance();

      const channel = MethodChannel('com.solaris.monitor/icons');
      int callCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            callCount++;
            return null;
          });

      await tester.runAsync(() async {
        // 1. Initial widget for KyivFirst.exe fails and is marked failed
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: GlowingAppIcon(name: 'KyivFirst.exe', size: 36),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(GlowingAppIcon.isFailed('KyivFirst.exe'), isTrue);
        expect(callCount, 1);

        // 2. Widget recycled with KyivSecond.exe which also fails
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: GlowingAppIcon(name: 'KyivSecond.exe', size: 36),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(GlowingAppIcon.isFailed('KyivSecond.exe'), isTrue);
        // Crucial: KyivFirst.exe failure cooldown was NOT wiped out by recycling
        expect(GlowingAppIcon.isFailed('KyivFirst.exe'), isTrue);
        expect(callCount, 2);

        // 3. Re-rendering KyivFirst.exe does not trigger extraction while on cooldown
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: GlowingAppIcon(name: 'KyivFirst.exe', size: 36),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(callCount, 2);
      });
    });

    testWidgets('failure cooldown applies when explicit exePath is provided', (
      tester,
    ) async {
      GlowingAppIcon.resetStaticCaches();
      IconCacheService.resetInstance();

      const channel = MethodChannel('com.solaris.monitor/icons');
      int callCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            callCount++;
            return null;
          });

      await tester.runAsync(() async {
        // 1. Initial build with explicit exePath fails
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: GlowingAppIcon(
                name: 'KyivCustom.exe',
                exePath: r'C:\KyivTools\KyivCustom.exe',
                size: 36,
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(callCount, 1);
        expect(
          GlowingAppIcon.isFailed(
            'KyivCustom.exe',
            exePath: r'C:\KyivTools\KyivCustom.exe',
          ),
          isTrue,
        );

        // 2. Re-rendering widget with same explicit exePath must NOT retry while on cooldown
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: GlowingAppIcon(
                name: 'KyivCustom.exe',
                exePath: r'C:\KyivTools\KyivCustom.exe',
                size: 36,
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        expect(callCount, 1);
      });
    });
  });
}
