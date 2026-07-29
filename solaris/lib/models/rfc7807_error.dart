import 'dart:convert';

/// DTO for RFC 7807 Problem Details for HTTP APIs.
class Rfc7807Error {
  final String type;
  final String title;
  final int status;
  final String detail;
  final String? instance;
  final Map<String, dynamic>? invalidParams;
  final String timestamp;

  Rfc7807Error({
    required this.type,
    required this.title,
    required this.status,
    required this.detail,
    this.instance,
    this.invalidParams,
    String? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> toJson() => {
    'type': type,
    'title': title,
    'status': status,
    'detail': detail,
    if (instance != null) 'instance': instance,
    if (invalidParams != null) 'invalid_params': invalidParams,
    'timestamp': timestamp,
  };

  String toJsonString() => jsonEncode(toJson());
}
