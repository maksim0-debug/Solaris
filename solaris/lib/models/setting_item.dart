import 'package:solaris/providers.dart';

class SettingItem {
  final String id;
  final String title;
  final String description;
  final List<String> tags;
  final AppScreen screen;
  final String? anchorId; // Optional ID to scroll to or highlight

  SettingItem({
    required this.id,
    required this.title,
    required this.description,
    required this.tags,
    required this.screen,
    this.anchorId,
  });
}
