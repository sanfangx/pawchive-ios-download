import '../models/post_target.dart';

class UrlParser {
  /// Matches pawchive, kemono, coomer post URLs
  /// Example: https://pawchive.pw/patreon/user/30500811/post/170445231
  static final RegExp _postUrlRegex = RegExp(
    r'https?://(?:www\.)?(?:pawchive\.pw|kemono\.(?:party|su)|coomer\.(?:party|su))/(?<service>[a-zA-Z0-9_\-]+)/user/(?<user>[a-zA-Z0-9_\-]+)/post/(?<post>[a-zA-Z0-9_\-]+)',
    caseSensitive: false,
  );

  /// Extract and parse PostTarget from user input or clipboard text
  static PostTarget? parse(String input) {
    if (input.trim().isEmpty) return null;

    final match = _postUrlRegex.firstMatch(input);
    if (match != null) {
      final service = match.namedGroup('service');
      final user = match.namedGroup('user');
      final post = match.namedGroup('post');

      if (service != null && user != null && post != null) {
        return PostTarget(
          service: service.toLowerCase(),
          userId: user,
          postId: post,
          rawUrl: match.group(0) ?? input.trim(),
        );
      }
    }
    return null;
  }

  /// Validates if an input string contains a recognizable post URL
  static bool isValid(String input) => parse(input) != null;
}
