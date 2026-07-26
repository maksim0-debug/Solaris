import 'dart:convert';
import 'package:solaris/models/api_permissions_config.dart';

/// OpenAPI 3.0.3 Spec Generator for Solaris Control API v1.
class OpenApiSpec {
  static Map<String, dynamic> generateSpec({
    String title = 'Solaris Control API v1',
    String version = '1.0.0',
    int port = 45321,
    ApiPermissionsConfig? permissions,
  }) {
    final isReadOnly = permissions?.isReadOnly ?? false;
    final rfc7807Ref = {r'$ref': '#/components/schemas/Rfc7807Error'};

    final forbiddenResponse = {
      'description': 'Forbidden (Access Prohibited or Read-Only Mode)',
      'content': {
        'application/problem+json': {
          'schema': rfc7807Ref,
        },
      },
    };

    final pathsMap = <String, dynamic>{
      '/api/v1/health': {
        'get': {
          'summary': 'Health Check',
          'description': 'Returns system health status and uptime. Always unrestricted.',
          'responses': {
            '200': {
              'description': 'OK',
              'content': {
                'application/json': {
                  'schema': {r'$ref': '#/components/schemas/HealthResponse'},
                },
              },
            },
          },
        },
      },
      '/api/v1/status': {
        'get': {
          'summary': 'Full Application State Snapshot',
          'description': 'Returns complete JSON snapshot of all Solaris subsystems.',
          'responses': {
            '200': {
              'description': 'OK',
              'content': {
                'application/json': {
                  'schema': {r'$ref': '#/components/schemas/StatusResponse'},
                },
              },
            },
            '401': {
              'description': 'Unauthorized',
              'content': {
                'application/problem+json': {
                  'schema': rfc7807Ref,
                },
              },
            },
            if (permissions != null) '403': forbiddenResponse,
          },
        },
      },
      '/api/v1/solar': {
        'get': {
          'summary': 'Solar Elevation and Phase Information',
          'responses': {
            '200': {'description': 'OK'},
            if (permissions != null && !permissions.allowReadSolar) '403': forbiddenResponse,
          },
        },
      },
      '/api/v1/presets': {
        'get': {
          'summary': 'List Available Presets',
          'responses': {
            '200': {'description': 'OK'},
            if (permissions != null && (!permissions.allowReadMonitors && !permissions.allowReadCircadian)) '403': forbiddenResponse,
          },
        },
      },
      '/api/v1/monitors': {
        'get': {
          'summary': 'List Connected Monitors',
          'responses': {
            '200': {'description': 'OK'},
            if (permissions != null && !permissions.allowReadMonitors) '403': forbiddenResponse,
          },
        },
      },
      '/api/v1/monitors/{slug}': {
        'get': {
          'summary': 'Get Monitor Details by Slug or ID',
          'parameters': [
            {
              'name': 'slug',
              'in': 'path',
              'required': true,
              'schema': {'type': 'string'},
            },
          ],
          'responses': {
            '200': {'description': 'OK'},
            '404': {'description': 'Monitor Not Found'},
            if (permissions != null && !permissions.allowReadMonitors) '403': forbiddenResponse,
          },
        },
      },
      '/api/v1/sleep/sessions': {
        'get': {
          'summary': 'Get Paginated Sleep History',
          'parameters': [
            {'name': 'limit', 'in': 'query', 'schema': {'type': 'integer', 'default': 50}},
            {'name': 'offset', 'in': 'query', 'schema': {'type': 'integer', 'default': 0}},
            {'name': 'from', 'in': 'query', 'schema': {'type': 'string', 'format': 'date-time'}},
            {'name': 'to', 'in': 'query', 'schema': {'type': 'string', 'format': 'date-time'}},
          ],
          'responses': {
            '200': {'description': 'OK'},
            if (permissions != null && !permissions.allowReadSleep) '403': forbiddenResponse,
          },
        },
      },
      '/api/v1/control': {
        'post': {
          'summary': 'Execute Control Actions (Single or Batch)',
          'description': isReadOnly
              ? '[READ-ONLY MODE ACTIVE] Prohibits all mutation execution.'
              : 'Executes action commands subject to category permissions.',
          'requestBody': {
            'required': true,
            'content': {
              'application/json': {
                'schema': {r'$ref': '#/components/schemas/ControlRequest'},
              },
            },
          },
          'responses': {
            '200': {'description': 'OK / Completed'},
            '202': {'description': 'Accepted (Queued DDC Command)'},
            '400': {'description': 'Validation Error'},
            if (permissions != null) '403': forbiddenResponse,
          },
        },
      },
    };

    final allowedActionsStr = permissions?.allowedActions != null
        ? ', AllowedActions=${permissions!.allowedActions!.toList()}'
        : '';

    return {
      'openapi': '3.0.3',
      'info': {
        'title': title,
        'description': 'Zen control of monitors, solar positioning, circadian rhythms, and automation in Solaris.'
            '${permissions != null ? "\n\n[Permissions Active]: ReadOnly=$isReadOnly, Categories=${permissions.allowedCategories.map((c) => c.name).toList()}$allowedActionsStr" : ""}',
        'version': version,
        'contact': {
          'name': 'maksim0-debug',
          'url': 'https://github.com/maksim0-debug/Solaris',
        },
      },
      'servers': [
        {
          'url': 'http://127.0.0.1:$port',
          'description': 'Localhost Server',
        },
        {
          'url': 'http://localhost:$port',
          'description': 'Localhost Alias',
        },
      ],
      'components': {
        'securitySchemes': {
          'ApiKeyAuth': {
            'type': 'apiKey',
            'in': 'header',
            'name': 'X-API-Key',
            'description': 'API Key authentication for LAN access or browser drive-by protection.',
          },
          'BearerAuth': {
            'type': 'http',
            'scheme': 'bearer',
            'description': 'Bearer token authentication header.',
          },
        },
        'schemas': {
          'StatusResponse': {
            'type': 'object',
            'properties': {
              'version': {'type': 'string', 'example': '1.0.0'},
              'uptime_seconds': {'type': 'integer', 'example': 3600},
              'timestamp': {'type': 'string', 'format': 'date-time'},
              'solar': {'type': 'object'},
              'weather': {'type': 'object'},
              'monitors': {
                'type': 'array',
                'items': {r'$ref': '#/components/schemas/MonitorInfo'},
              },
              'automation': {'type': 'object'},
              'smart_circadian': {'type': 'object'},
              'sleep': {'type': 'object'},
              'server': {'type': 'object'},
            },
          },
          'MonitorInfo': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string', 'example': r'\\.\DISPLAY1\Monitor0'},
              'name': {'type': 'string', 'example': 'LG 27GL850'},
              'friendly_name': {'type': 'string', 'example': 'LG UltraGear'},
              'is_primary': {'type': 'boolean'},
              'brightness': {'type': 'object'},
              'temperature': {'type': 'object'},
            },
          },
          'HealthResponse': {
            'type': 'object',
            'properties': {
              'status': {'type': 'string', 'example': 'ok'},
              'version': {'type': 'string', 'example': '1.0.0'},
              'uptime_seconds': {'type': 'integer', 'example': 3600},
            },
          },
          'Rfc7807Error': {
            'type': 'object',
            'properties': {
              'type': {'type': 'string'},
              'title': {'type': 'string'},
              'status': {'type': 'integer'},
              'detail': {'type': 'string'},
              'instance': {'type': 'string'},
              'timestamp': {'type': 'string'},
            },
          },
          'ControlRequest': {
            'type': 'object',
            'required': ['action'],
            'properties': {
              'action': {'type': 'string', 'example': 'set_brightness'},
              'value': {'type': 'number'},
              'enabled': {'type': 'boolean'},
              'preset': {'type': 'string'},
              'monitor_id': {'type': 'string', 'example': 'display-1'},
            },
          },
        },
      },
      'security': [
        {'ApiKeyAuth': <String>[]},
        {'BearerAuth': <String>[]},
      ],
      'paths': pathsMap,
    };
  }

  static String generateJsonSpec({
    String title = 'Solaris Control API v1',
    String version = '1.0.0',
    int port = 45321,
    ApiPermissionsConfig? permissions,
  }) {
    return jsonEncode(generateSpec(title: title, version: version, port: port, permissions: permissions));
  }
}

