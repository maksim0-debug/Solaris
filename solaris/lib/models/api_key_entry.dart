import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:solaris/models/api_permissions_config.dart';
import 'package:solaris/utils/key_obfuscator.dart';

class ApiKeyEntry {
  final String id;
  final String name;
  final String token;
  final ApiPermissionsConfig permissions;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final bool isDpapiFallback;

  const ApiKeyEntry({
    required this.id,
    required this.name,
    required this.token,
    required this.permissions,
    required this.createdAt,
    this.lastUsedAt,
    this.isDpapiFallback = false,
  });

  static String generateSecureToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    final baseStr = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'sol_sec_$baseStr';
  }

  factory ApiKeyEntry.create({
    required String name,
    ApiPermissionsConfig permissions = const ApiPermissionsConfig(),
    int defaultIndex = 1,
  }) {
    final salt = Random.secure().nextInt(0xFFFF).toRadixString(16);
    final trimmedName = name.trim();
    return ApiKeyEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}_$salt',
      name: trimmedName.isEmpty ? 'API Key $defaultIndex' : trimmedName,
      token: generateSecureToken(),
      permissions: permissions,
      createdAt: DateTime.now(),
      isDpapiFallback: false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'token': KeyObfuscator.encrypt(token),
    'permissions': permissions.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
    'isDpapiFallback': isDpapiFallback,
  };

  factory ApiKeyEntry.fromJson(Map<String, dynamic> json) {
    String decryptedToken;
    bool isDpapiFallback = json['isDpapiFallback'] is bool ? json['isDpapiFallback'] as bool : false;
    final idStr = json['id'] is String ? json['id'] as String : '';
    final nameStr = json['name'] is String ? json['name'] as String : 'API Key';
    final tokenStr = json['token'] is String ? json['token'] as String : '';
    try {
      decryptedToken = KeyObfuscator.decrypt(tokenStr);
    } catch (e) {
      // ZERO SECRET LEAKAGE: Log only key ID and name, NEVER output the raw token string
      debugPrint('ApiKeyEntry: DPAPI decryption error for key "$nameStr" (id: $idStr): $e. Generated fallback secure token.');
      decryptedToken = generateSecureToken();
      isDpapiFallback = true;
    }
    final createdAtStr = json['createdAt'] is String ? json['createdAt'] as String : null;
    final lastUsedAtStr = json['lastUsedAt'] is String ? json['lastUsedAt'] as String : null;

    return ApiKeyEntry(
      id: idStr.isNotEmpty ? idStr : '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(0xFFFF).toRadixString(16)}',
      name: nameStr,
      token: decryptedToken.isNotEmpty ? decryptedToken : generateSecureToken(),
      permissions: json['permissions'] is Map<String, dynamic>
          ? ApiPermissionsConfig.fromJson(json['permissions'] as Map<String, dynamic>)
          : const ApiPermissionsConfig(),
      createdAt: createdAtStr != null
          ? DateTime.tryParse(createdAtStr) ?? DateTime.now()
          : DateTime.now(),
      lastUsedAt: lastUsedAtStr != null
          ? DateTime.tryParse(lastUsedAtStr)
          : null,
      isDpapiFallback: isDpapiFallback,
    );
  }

  ApiKeyEntry copyWith({
    String? name,
    String? token,
    ApiPermissionsConfig? permissions,
    DateTime? lastUsedAt,
    bool? isDpapiFallback,
  }) {
    return ApiKeyEntry(
      id: id,
      name: name ?? this.name,
      token: token ?? this.token,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      isDpapiFallback: isDpapiFallback ?? this.isDpapiFallback,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiKeyEntry &&
        other.id == id &&
        other.name == name &&
        other.token == token &&
        other.permissions == permissions &&
        other.createdAt == createdAt &&
        other.lastUsedAt == lastUsedAt &&
        other.isDpapiFallback == isDpapiFallback;
  }

  @override
  int get hashCode => Object.hash(id, name, token, permissions, createdAt, lastUsedAt, isDpapiFallback);
}
