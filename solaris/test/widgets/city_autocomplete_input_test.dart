import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solaris/l10n/app_localizations.dart';
import 'package:solaris/services/geocoding_service.dart';
import 'package:solaris/widgets/city_autocomplete_input.dart';

class MockGeocodingService extends GeocodingService {
  String? lastPassedLanguage;

  @override
  Future<List<CitySearchResult>> searchPlaces(
    String query, {
    String? language,
    String? customToken,
  }) async {
    lastPassedLanguage = language;
    if (query.contains('Tokyo') || query.contains('tokyo')) {
      return const [
        CitySearchResult(
          name: 'Tokyo',
          fullAddress: 'Tokyo, Japan',
          latitude: 35.6762,
          longitude: 139.6503,
        ),
      ];
    }
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CityAutocompleteInput Widget Tests', () {
    testWidgets('passes current app locale language code to searchPlaces', (
      WidgetTester tester,
    ) async {
      final mockGeocoding = MockGeocodingService();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CityAutocompleteInput(
              geocodingService: mockGeocoding,
              hasMapboxToken: true,
              customToken: 'pk.test_123',
              onCitySelected: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(mockGeocoding.lastPassedLanguage, equals('en'));
      expect(find.text('Tokyo, Japan'), findsOneWidget);
    });

    testWidgets(
      'tapping city in overlay selects city and calls onCitySelected',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockGeocoding = MockGeocodingService();
        CitySearchResult? selectedCity;

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 400,
                  child: CityAutocompleteInput(
                    geocodingService: mockGeocoding,
                    hasMapboxToken: true,
                    customToken: 'pk.test_123',
                    onCitySelected: (city) {
                      selectedCity = city;
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'Tokyo');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.text('Tokyo, Japan'), findsOneWidget);

        await tester.tap(find.text('Tokyo, Japan'));
        await tester.pumpAndSettle();

        expect(selectedCity, isNotNull);
        expect(selectedCity!.name, equals('Tokyo'));
        expect(selectedCity!.latitude, equals(35.6762));
        expect(selectedCity!.longitude, equals(139.6503));
      },
    );

    testWidgets(
      're-opens overlay suggestions when gaining focus with existing text',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockGeocoding = MockGeocodingService();

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 400,
                  child: Column(
                    children: [
                      CityAutocompleteInput(
                        geocodingService: mockGeocoding,
                        hasMapboxToken: true,
                        customToken: 'pk.test_123',
                        onCitySelected: (_) {},
                      ),
                      const Text('Outside Focus Target'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        // 1. Enter query 'Tokyo' -> suggestions appear
        await tester.enterText(find.byType(TextField), 'Tokyo');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('Tokyo, Japan'), findsOneWidget);

        // 2. Unfocus text field -> overlay disappears
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(find.text('Tokyo, Japan'), findsNothing);

        // 3. Tap back into TextField without modifying characters -> overlay re-appears
        await tester.tap(find.byType(TextField));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text('Tokyo, Japan'), findsOneWidget);
      },
    );
  });
}
