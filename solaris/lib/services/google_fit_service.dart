import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:solaris/env/env.dart';
import 'package:googleapis/fitness/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:solaris/services/storage_service.dart';
import 'package:solaris/services/pkce_service.dart';
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
            Env.googleClientId,
            Env.googleClientSecret,
          );

          // Check if token is expired and refresh it proactively
          if (credentials.accessToken.expiry.isBefore(DateTime.now())) {
            debugPrint('Google Fit token expired on init, attempting refresh...');
            try {
              // For public clients, refresh without secret should work if the client_id is the same
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
              // If refresh fails (e.g. because we removed the secret), 
              // we must clear the saved token and force a fresh sign in.
              await _storage.clear(_tokenFilename);
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
      final clientIdStr = Env.googleClientId;

      // 1. Generate PKCE verifier and challenge
      final verifier = PkceService.generateCodeVerifier();
      final challenge = PkceService.generateCodeChallenge(verifier);

      // 2. Start local receiver server to capture the code
      // Using 127.0.0.1 is often more reliable than 'localhost' for OAuth loopback
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://127.0.0.1:$port';

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientIdStr,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': _scopes.join(' '),
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'access_type': 'offline',
        'prompt': 'consent',
      });

      debugPrint('Opening auth URL: $authUrl');

      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl);
      } else {
        await server.close(force: true);
        throw 'Could not launch $authUrl';
      }

      // 3. Wait for the code
      String? code;
      String? error;
      
      try {
        final request = await server.first.timeout(const Duration(minutes: 5));
        code = request.uri.queryParameters['code'];
        error = request.uri.queryParameters['error'];

        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
          <html>
            <body style="font-family: sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; background-color: #0f172a; color: white; text-align: center;">
              <h1 style="color: #38bdf8; font-size: 48px;">Success!</h1>
              <p style="font-size: 20px; color: #94a3b8;">Google Fit connected successfully.</p>
              <p style="font-size: 16px; color: #64748b; margin-top: 20px;">You can now close this window and return to the app.</p>
            </body>
          </html>
        ''');
        await request.response.close();
      } catch (e) {
        error = 'timeout or error during listening: $e';
      } finally {
        await server.close(force: true);
      }

      if (code == null) {
        debugPrint('Google Fit Sign In failed capturing code: ${error ?? "unknown error"}');
        return false;
      }

      // 4. Exchange code + verifier for tokens
      debugPrint('Exchanging authorization code for tokens...');
      final tokenResponse = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientIdStr,
          'client_secret': Env.googleClientSecret,
          'code': code,
          'code_verifier': verifier,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
      );

      if (tokenResponse.statusCode != 200) {
        debugPrint('Failed to exchange code: ${tokenResponse.statusCode} - ${tokenResponse.body}');
        return false;
      }

      final tokenData = jsonDecode(tokenResponse.body);
      
      // Use safer casting for numeric values in JSON
      final expiresIn = (tokenData['expires_in'] as num?)?.toInt() ?? 3600;
      final accessToken = tokenData['access_token'] as String?;
      final refreshToken = tokenData['refresh_token'] as String?;

      if (accessToken == null) {
        debugPrint('No access_token received in response');
        return false;
      }

      final credentials = AccessCredentials(
        AccessToken(
          'Bearer',
          accessToken,
          DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
        ),
        refreshToken,
        _scopes,
      );

      _client = authenticatedClient(http.Client(), credentials);
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
          Env.googleClientId,
          Env.googleClientSecret,
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
