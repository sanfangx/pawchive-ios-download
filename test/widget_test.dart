import 'package:flutter_test/flutter_test.dart';
import 'package:pawchive_download/services/url_parser.dart';

void main() {
  group('UrlParser Tests', () {
    test('Correctly parses standard Pawchive post URL', () {
      const url =
          'https://pawchive.pw/patreon/user/30500811/post/170445231';
      final target = UrlParser.parse(url);
      expect(target, isNotNull);
      expect(target?.service, equals('patreon'));
      expect(target?.userId, equals('30500811'));
      expect(target?.postId, equals('170445231'));
    });

    test('Correctly extracts Pawchive URL from messy text', () {
      const text =
          'Hey check this out: https://pawchive.pw/fanbox/user/98765/post/54321 thanks!';
      final target = UrlParser.parse(text);
      expect(target, isNotNull);
      expect(target?.service, equals('fanbox'));
      expect(target?.userId, equals('98765'));
      expect(target?.postId, equals('54321'));
    });

    test('Rejects invalid URLs', () {
      expect(UrlParser.parse('https://google.com'), isNull);
      expect(UrlParser.parse('hello world'), isNull);
    });
  });
}
