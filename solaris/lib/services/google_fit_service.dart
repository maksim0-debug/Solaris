import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis/fitness/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:solaris/services/storage_service.dart';
import 'package:http/http.dart' as http;

class GoogleFitService {
  static final GoogleFitService _instance = GoogleFitService._internal();
  factory GoogleFitService() => _instance;
  GoogleFitService._internal();

  final _storage = StorageService();
  final _tokenFilename = 'google_fit_token.json';

  AuthClient? _client;
  FitnessApi? _fitnessApi;

  final _scopes = [FitnessApi.fitnessSleepReadScope];

  bool get isConnected => _client != null;

  Future<bool> initialize() async {
    try {
      final tokenJson = await _storage.load(_tokenFilename);
      if (tokenJson != null) {
        final decoded = jsonDecode(tokenJson);
        if (decoded is Map<String, dynamic>) {
          var credentials = AccessCredentials.fromJson(decoded);
          final clientId = ClientId(
            dotenv.get('GOOGLE_CLIENT_ID'),
            dotenv.get('GOOGLE_CLIENT_SECRET'),
          );

          // Check if token is expired and refresh it proactively
          if (credentials.accessToken.expiry.isBefore(DateTime.now())) {
            debugPrint('Google Fit token expired on init, attempting refresh...');
            try {
              credentials = await refreshCredentials(
                clientId,
                credentials,
                http.Client(),
              );
              await _storage.save(
                _tokenFilename,
                jsonEncode(credentials.toJson()),
              );
            } catch (e) {
              debugPrint('Error refreshing token during initialization: $e');
              return false;
            }
          }

          _client = authenticatedClient(http.Client(), credentials);
          _fitnessApi = FitnessApi(_client!);

          debugPrint(
            'Google Fit initialized with client ID: ${clientId.identifier}',
          );

          return true;
        }
      }
    } catch (e) {
      debugPrint('Error initializing Google Fit: $e');
    }
    return false;
  }

  Future<bool> signIn() async {
    try {
      final clientId = ClientId(
        dotenv.get('GOOGLE_CLIENT_ID'),
        dotenv.get('GOOGLE_CLIENT_SECRET'),
      );

      final client = await clientViaUserConsent(
        clientId,
        _scopes,
        (url) async {
          // Append offline access parameters to the URL to ensure we get a refresh token
          final uri = Uri.parse(url);
          final updatedUri = uri.replace(
            queryParameters: {
              ...uri.queryParameters,
              'access_type': 'offline',
              'prompt': 'consent',
            },
          );
          final updatedUrl = updatedUri.toString();

          if (await canLaunchUrl(Uri.parse(updatedUrl))) {
            await launchUrl(Uri.parse(updatedUrl));
          } else {
            throw 'Could not launch $updatedUrl';
          }
        },
      );

      _client = client;
      _fitnessApi = FitnessApi(_client!);

      // Save credentials for later
      await _storage.save(
        _tokenFilename,
        jsonEncode(_client!.credentials.toJson()),
      );

      return true;
    } catch (e) {
      debugPrint('Error signing in to Google Fit: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    _client?.close();
    _client = null;
    _fitnessApi = null;
    await _storage.clear(_tokenFilename);
  }

  Future<List<Session>?> fetchSleepSessions({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (_fitnessApi == null || _client == null) {
      final initialized = await initialize();
      if (!initialized) return null;
    }

    // Refresh token if expired
    try {
      final credentials = _client!.credentials;
      if (credentials.accessToken.expiry.isBefore(DateTime.now())) {
        debugPrint('Google Fit token expired, attempting to refresh...');
        final clientId = ClientId(
          dotenv.get('GOOGLE_CLIENT_ID'),
          dotenv.get('GOOGLE_CLIENT_SECRET'),
        );

        // Use refreshCredentials instead of refreshAuthenticatedClient
        // as the later isn't a top-level function in this context
        final refreshedCredentials = await refreshCredentials(
          clientId,
          credentials,
          http.Client(),
        );

        _client = authenticatedClient(http.Client(), refreshedCredentials);
        _fitnessApi = FitnessApi(_client!);

        await _storage.save(
          _tokenFilename,
          jsonEncode(refreshedCredentials.toJson()),
        );
      }
    } catch (e) {
      debugPrint('Error refreshing Google Fit token: $e');
      // If refresh fails, sign out and let user re-connect
      await signOut();
      return null;
    }

    try {
      final response = await _fitnessApi!.users.sessions.list(
        'me',
        startTime: startTime.toUtc().toIso8601String(),
        endTime: endTime.toUtc().toIso8601String(),
      );
      return response.session;
    } catch (e) {
      debugPrint('Error fetching sleep sessions: $e');
      if (e.toString().contains('invalid_token') ||
          e.toString().contains('401')) {
        await signOut();
      }
      return null;
    }
  }
}
