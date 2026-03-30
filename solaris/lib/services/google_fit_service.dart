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
          final credentials = AccessCredentials.fromJson(decoded);
          final clientId = ClientId(
            dotenv.get('GOOGLE_CLIENT_ID'),
            dotenv.get('GOOGLE_CLIENT_SECRET'),
          );
          
          _client = authenticatedClient(http.Client(), credentials);
          _fitnessApi = FitnessApi(_client!);
          
          // Use clientId to verify credentials if needed, but for now we just initialize
          debugPrint('Google Fit initialized with client ID: ${clientId.identifier}');
          
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

      final client = await clientViaUserConsent(clientId, _scopes, (url) async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        } else {
          throw 'Could not launch $url';
        }
      });

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
    if (_fitnessApi == null) {
      final initialized = await initialize();
      if (!initialized) return null;
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
      return null;
    }
  }
}
