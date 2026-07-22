enum PostUpdateStatus {
  none,
  success,
  rollback,
  error,
}

/// Represents the result of an update attempt parsed from `update.log`.
class PostUpdateResult {
  final PostUpdateStatus status;
  final String? oldVersion;
  final String? newVersion;
  final String? reason;
  final DateTime? timestamp;

  const PostUpdateResult({
    required this.status,
    this.oldVersion,
    this.newVersion,
    this.reason,
    this.timestamp,
  });

  factory PostUpdateResult.fromJson(Map<String, dynamic> json) {
    PostUpdateStatus parsedStatus;
    final statusStr = (json['status'] as String?)?.toUpperCase();
    switch (statusStr) {
      case 'SUCCESS':
        parsedStatus = PostUpdateStatus.success;
        break;
      case 'ROLLBACK':
        parsedStatus = PostUpdateStatus.rollback;
        break;
      case 'ERROR':
        parsedStatus = PostUpdateStatus.error;
        break;
      default:
        parsedStatus = PostUpdateStatus.none;
    }

    DateTime? parsedTimestamp;
    if (json['timestamp'] != null) {
      parsedTimestamp = DateTime.tryParse(json['timestamp'].toString());
    }

    return PostUpdateResult(
      status: parsedStatus,
      oldVersion: json['oldVersion'] as String?,
      newVersion: json['newVersion'] as String?,
      reason: json['reason'] as String?,
      timestamp: parsedTimestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.name.toUpperCase(),
      if (oldVersion != null) 'oldVersion': oldVersion,
      if (newVersion != null) 'newVersion': newVersion,
      if (reason != null) 'reason': reason,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'PostUpdateResult(status: $status, oldVersion: $oldVersion, newVersion: $newVersion, reason: $reason, timestamp: $timestamp)';
  }
}
