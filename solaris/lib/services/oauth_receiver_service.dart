import 'dart:async';
import 'dart:io';

/// Results of the OAuth receipt.
class OAuthReceipt {
  final String? code;
  final String? error;
  final int port;

  OAuthReceipt({this.code, this.error, required this.port});
}

/// Service to handle receiving the OAuth2 redirect on a local loopback address.
class OAuthReceiverService {
  HttpServer? _server;

  /// Starts a local server and waits for the first request containing 'code' or 'error'.
  /// Returns the receipt and closes the server.
  Future<OAuthReceipt> receiveCode({int timeoutSeconds = 300}) async {
    // Bind to any available port on localhost
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = _server!.port;

    final completer = Completer<OAuthReceipt>();

    final subscription = _server!.listen((HttpRequest request) async {
      final queryParams = request.uri.queryParameters;
      final code = queryParams['code'];
      final error = queryParams['error'];

      if (code != null || error != null) {
        // Send a nice response to the user's browser
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.html;
        request.response.write('''
          <!DOCTYPE html>
          <html>
          <head>
            <title>Authentication Successful</title>
            <style>
              body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background-color: #0f172a; color: white; }
              .card { background: rgba(30, 41, 59, 0.7); padding: 2rem; border-radius: 1rem; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); text-align: center; border: 1px solid rgba(255, 255, 255, 0.1); }
              h1 { color: #38bdf8; margin-top: 0; }
              p { color: #94a3b8; }
            </style>
          </head>
          <body>
            <div class="card">
              <h1>${code != null ? 'Success!' : 'Authentication Failed'}</h1>
              <p>${code != null ? 'You have successfully authenticated with Google Fit. You can now close this window and return to the app.' : 'Error: $error. You can close this window.'}</p>
            </div>
            <script>
              // Try to close the window automatically after a delay
              setTimeout(() => {
                // window.close() only works if window was opened by script, 
                // but it's worth a try or just inform the user.
              }, 3000);
            </script>
          </body>
          </html>
        ''');
        await request.response.close();

        if (!completer.isCompleted) {
          completer.complete(OAuthReceipt(code: code, error: error, port: port));
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      }
    });

    try {
      // Add a timeout
      return await completer.future.timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          if (!completer.isCompleted) {
            completer.complete(OAuthReceipt(error: 'timeout', port: port));
          }
          return completer.future;
        },
      );
    } finally {
      await subscription.cancel();
      await _server?.close(force: true);
      _server = null;
    }
  }
}
