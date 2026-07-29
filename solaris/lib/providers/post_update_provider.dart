import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post_update_result.dart';
import '../services/post_update_service.dart';

/// Provider for [PostUpdateService].
final postUpdateServiceProvider = Provider<PostUpdateService>((ref) {
  return PostUpdateService();
});

/// Riverpod State Notifier holding the result of post-update processing upon app launch.
class PostUpdateNotifier extends Notifier<PostUpdateResult?> {
  @override
  PostUpdateResult? build() => null;

  void setResult(PostUpdateResult? result) {
    state = result;
  }
}

/// Provider for [PostUpdateNotifier].
final postUpdateResultProvider =
    NotifierProvider<PostUpdateNotifier, PostUpdateResult?>(
      PostUpdateNotifier.new,
    );
