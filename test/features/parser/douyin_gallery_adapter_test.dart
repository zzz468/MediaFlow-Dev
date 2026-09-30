import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/features/downloader/application/media_content_download_mapper.dart';
import 'package:mediaflow/features/parser/data/douyin/gallery/douyin_gallery_adapter.dart';
import 'package:mediaflow/features/parser/domain/media_content.dart';

void main() {
  const target = '7690029886242009957';
  const adapter = DouyinGalleryAdapter();
  Map<String, Object?> fixture() =>
      jsonDecode(
            File(
              'test/fixtures/douyin/authorized_gallery_13_sanitized.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  MediaContent map(Map<String, Object?> value) =>
      adapter.adapt(value, expectedAwemeId: target);
  Map<String, dynamic> detail(Map<String, Object?> value) =>
      value['aweme_detail'] as Map<String, dynamic>;

  test('target and content identity match the requested work', () {
    final content = map(fixture());
    expect(content.id, target);
    expect(content.sourceUrl.path, '/note/$target');
  });
  test('type 68 maps to gallery with 13 image resources', () {
    final content = map(fixture());
    expect(content.type, MediaContentType.imageGallery);
    expect(content.resources, hasLength(13));
    expect(
      content.resources.every((item) => item.type == MediaResourceType.image),
      isTrue,
    );
  });
  test('every URL and original image position is preserved', () {
    final value = fixture();
    final images = detail(value)['images'] as List;
    final content = map(value);
    expect(content.resources.map((item) => item.url.toString()), [
      for (final image in images) (image as Map)['url_list'][0],
    ]);
    expect(content.resources.indexed.map((item) => item.$1), [
      for (var index = 0; index < 13; index++) index,
    ]);
  });
  test('resource IDs are unique and independent of expiring CDN URLs', () {
    final value = fixture();
    final before = map(value);
    final images = detail(value)['images'] as List;
    for (var index = 0; index < images.length; index++) {
      (images[index] as Map)['url_list'] = [
        'https://other.example.test/$index.jpg?version=2',
      ];
    }
    final after = map(value);
    expect(before.resources.map((item) => item.id).toSet(), hasLength(13));
    expect(
      after.resources.map((item) => item.id),
      before.resources.map((item) => item.id),
    );
  });
  test('existing mapper makes 13 ordered ordinary download tasks', () {
    final content = map(fixture());
    final tasks = downloadTasksFromMediaContent(
      content,
      operationId: 'gallery13',
      createdAt: DateTime.utc(2026, 9, 28),
    );
    expect(tasks, hasLength(13));
    for (var index = 0; index < 13; index++) {
      expect(tasks[index].contentId, target);
      expect(tasks[index].resourceId, '$target:image:$index');
      expect(tasks[index].url, content.resources[index].url);
      expect(tasks[index].resourceType, 'image');
    }
  });
  test('credentials and unknown raw fields are not propagated', () {
    final value = fixture();
    value['cookie'] = 'fixture-credential-sentinel';
    detail(value)['sessionid'] = 'fixture-credential-sentinel';
    final content = map(value);
    expect(
      content.resources.every((item) => item.requestHeaders.isEmpty),
      isTrue,
    );
    expect(content.title, isNot(contains('fixture-credential-sentinel')));
  });
  for (final key in ['status_code', 'aweme_detail']) {
    test('missing required response field $key fails explicitly', () {
      final value = fixture()..remove(key);
      expect(() => map(value), throwsFormatException);
    });
  }
  for (final key in ['aweme_id', 'aweme_type', 'images']) {
    test('missing required detail field $key fails explicitly', () {
      final value = fixture();
      detail(value).remove(key);
      expect(() => map(value), throwsFormatException);
    });
  }
  test('wrong target is rejected', () {
    final value = fixture();
    detail(value)['aweme_id'] = '123';
    expect(() => map(value), throwsFormatException);
  });
  test('video detail is rejected without changing legacy video adaptation', () {
    final value = fixture();
    detail(value)['aweme_type'] = 0;
    expect(() => map(value), throwsFormatException);
  });
  test('empty images is not a successful gallery', () {
    final value = fixture();
    detail(value)['images'] = <Object?>[];
    expect(() => map(value), throwsFormatException);
  });
  test('malformed middle image fails without silently shifting order', () {
    final value = fixture();
    (detail(value)['images'] as List)[6] = null;
    expect(() => map(value), throwsFormatException);
  });
  test('missing URL list fails', () {
    final value = fixture();
    ((detail(value)['images'] as List).first as Map).remove('url_list');
    expect(() => map(value), throwsFormatException);
  });
  test('HTTP, credentials in URI and invalid URLs are rejected safely', () {
    for (final url in [
      'http://fixture.example.test/a.jpg',
      'https://user:password@fixture.example.test/a.jpg',
      'not a URL',
    ]) {
      final value = fixture();
      ((detail(value)['images'] as List).first as Map)['url_list'] = [url];
      expect(() => map(value), throwsFormatException);
    }
  });
  test('nonzero business status fails before mapping images', () {
    final value = fixture()..['status_code'] = 1;
    expect(() => map(value), throwsFormatException);
  });
}
