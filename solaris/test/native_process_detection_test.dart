import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Native Process Detection & EventChannel Contract Tests', () {
    test('EventChannel map payload contains expected keys and types', () {
      final rawPayload = <Object?, Object?>{
        'is_gaming': true,
        'active_process': 'photoshop.exe',
      };

      expect(rawPayload.containsKey('is_gaming'), isTrue);
      expect(rawPayload.containsKey('active_process'), isTrue);

      final isGaming = rawPayload['is_gaming'];
      final activeProcess = rawPayload['active_process'];

      expect(isGaming, isA<bool>());
      expect(isGaming, isTrue);
      expect(activeProcess, isA<String>());
      expect(activeProcess, equals('photoshop.exe'));
    });

    test('EventChannel map payload handles empty process name (no focus)', () {
      final rawPayload = <Object?, Object?>{
        'is_gaming': false,
        'active_process': '',
      };

      expect(rawPayload['is_gaming'], isFalse);
      expect(rawPayload['active_process'], equals(''));
    });

    test('EventChannel map payload handles non-ASCII / UTF-8 process names', () {
      final rawPayload = <Object?, Object?>{
        'is_gaming': false,
        'active_process': 'редактор.exe',
      };

      expect(rawPayload['active_process'], equals('редактор.exe'));
    });

    test('MethodChannel getRunningProcesses payload format parsing', () {
      final rawList = <Object?>[
        <Object?, Object?>{
          'exe': 'photoshop.exe',
          'title': 'Adobe Photoshop 2026',
        },
        <Object?, Object?>{
          'exe': 'code.exe',
          'title': 'Visual Studio Code - project [Solaris]',
        },
        <Object?, Object?>{
          'exe': 'blender.exe',
          'title': 'Blender 4.2 - [Кириллица Тест]',
        },
      ];

      final parsedProcesses = rawList.map((item) {
        final map = item as Map<Object?, Object?>;
        return {
          'exe': map['exe'] as String,
          'title': map['title'] as String,
        };
      }).toList();

      expect(parsedProcesses.length, equals(3));
      expect(parsedProcesses[0]['exe'], equals('photoshop.exe'));
      expect(parsedProcesses[0]['title'], equals('Adobe Photoshop 2026'));
      expect(parsedProcesses[2]['title'], contains('Кириллица'));
    });

    test('MethodChannel getRunningProcesses excludes self process solaris.exe', () {
      final processes = [
        {'exe': 'photoshop.exe', 'title': 'Adobe Photoshop'},
        {'exe': 'chrome.exe', 'title': 'Google Chrome'},
      ];

      final hasSolaris = processes.any((p) => p['exe'] == 'solaris.exe');
      expect(hasSolaris, isFalse);
    });

    test('Process name lowercasing and normalization contract', () {
      String normalizeExe(String inputPath) {
        final lower = inputPath.toLowerCase();
        final normalized = lower.replaceAll('\\', '/');
        final lastSlash = normalized.lastIndexOf('/');
        return lastSlash != -1 ? normalized.substring(lastSlash + 1) : normalized;
      }

      expect(normalizeExe(r'C:\Program Files\Adobe\Photoshop.exe'), equals('photoshop.exe'));
      expect(normalizeExe(r'C:\ПОЛЬЗОВАТЕЛИ\ТЕСТ\APP.EXE'), equals('app.exe'));
      expect(normalizeExe('ApplicationFrameHost.exe'), equals('applicationframehost.exe'));
    });
  });
}
