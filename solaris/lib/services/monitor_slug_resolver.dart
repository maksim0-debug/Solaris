import 'package:solaris/services/monitor_service.dart';

/// Helper to map human-friendly monitor slugs ("display-1", "lg-27gl850-a1f9", "primary")
/// to underlying Win32 system monitor IDs ("\\\\.\\DISPLAY1\\Monitor0") and vice versa.
class MonitorSlugResolver {
  static final Map<String, String> _slugToSystemId = {};
  static final Map<String, String> _systemIdToSlug = {};

  /// Updates internal mapping from active monitor list.
  static void updateMonitors(List<MonitorInfo> monitors) {
    _slugToSystemId.clear();
    _systemIdToSlug.clear();

    final Map<String, int> modelCounts = {};

    for (int i = 0; i < monitors.length; i++) {
      final mon = monitors[i];
      final baseName = mon.friendlyName.isNotEmpty
          ? mon.friendlyName
          : (mon.name.isNotEmpty ? mon.name : 'monitor');
      final modelSlugBase = _slugify(baseName);
      final count = (modelCounts[modelSlugBase] ?? 0) + 1;
      modelCounts[modelSlugBase] = count;

      final deviceHash = mon.deviceIdHash.length >= 4
          ? mon.deviceIdHash.substring(0, 4)
          : mon.deviceIdHash;
      final edidSlug = '$modelSlugBase-$deviceHash';
      final friendlyIndexSlug = 'display-${i + 1}';

      _slugToSystemId[friendlyIndexSlug] = mon.id;
      _slugToSystemId[edidSlug] = mon.id;
      _slugToSystemId[mon.id] = mon.id; // Fallback for raw Win32 ID

      if (mon.isPrimary) {
        _slugToSystemId['primary'] = mon.id;
        _slugToSystemId['main'] = mon.id;
      }

      _systemIdToSlug[mon.id] = edidSlug;
    }
  }

  /// Resolves a slug or raw ID to the internal system monitor ID.
  /// Returns null if unable to resolve.
  static String? resolveToSystemId(String slugOrId) {
    if (slugOrId == 'all' || slugOrId == 'primary') {
      return _slugToSystemId[slugOrId] ?? (slugOrId == 'all' ? 'all' : null);
    }
    final decoded = Uri.decodeComponent(slugOrId);
    return _slugToSystemId[slugOrId] ?? _slugToSystemId[decoded];
  }

  /// Gets friendly slug for a given system monitor ID.
  static String getSlugForSystemId(String systemId) {
    return _systemIdToSlug[systemId] ?? systemId;
  }

  static String _slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}
