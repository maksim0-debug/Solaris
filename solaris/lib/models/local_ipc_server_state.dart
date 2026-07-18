/// Data class representing the state of the local IPC (HTTP) server.
class LocalIpcServerState {
  final bool isRunning;
  final int? port;
  final String? error;
  final int? failedPort;

  const LocalIpcServerState({
    required this.isRunning,
    this.port,
    this.error,
    this.failedPort,
  });

  LocalIpcServerState copyWith({
    bool? isRunning,
    int? port,
    String? error,
    int? failedPort,
  }) {
    return LocalIpcServerState(
      isRunning: isRunning ?? this.isRunning,
      port: port ?? this.port,
      error: error,
      failedPort: failedPort ?? this.failedPort,
    );
  }
}
