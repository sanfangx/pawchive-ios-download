class PostTarget {
  final String service;
  final String userId;
  final String postId;
  final String rawUrl;

  const PostTarget({
    required this.service,
    required this.userId,
    required this.postId,
    required this.rawUrl,
  });

  String get apiEndpoint =>
      'https://pawchive.pw/api/v1/$service/user/$userId/post/$postId';

  String get profileEndpoint =>
      'https://pawchive.pw/api/v1/$service/user/$userId/profile';

  String get avatarUrl => 'https://pawchive.pw/icons/$service/$userId';

  @override
  String toString() => '$service/user/$userId/post/$postId';
}
