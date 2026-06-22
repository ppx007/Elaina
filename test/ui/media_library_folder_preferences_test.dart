import 'package:elaina/src/domain/media/media_library_folder_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaLibraryFolderPreferenceCodec', () {
    const MediaLibraryFolderPreferenceCodec codec =
        MediaLibraryFolderPreferenceCodec();

    test('round-trips file folder URIs', () {
      final List<Uri> folders = <Uri>[
        Uri.parse('file:///D:/media/'),
        Uri.parse('file:///D:/anime/'),
      ];

      final String encoded = codec.encode(folders);
      final List<Uri> decoded = codec.decode(encoded);

      expect(decoded, folders);
    });

    test('rejects non-list and non-file values', () {
      expect(
        () => codec.decode('{"path":"file:///D:/media/"}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => codec.decode('["https://example.test/media"]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('deduplicates replacement paths by normalized folder identity', () {
      final Uri existing = Uri.parse('file:///D:/media/');
      final Uri replacement = Uri.parse('file:///D:/anime/');

      final List<Uri> folders = codec.replaceFolder(
        folders: <Uri>[existing, replacement],
        existingFolder: existing,
        replacementFolder: replacement,
      );

      expect(folders, <Uri>[replacement]);
    });

    test('deduplicates decoded folder preferences', () {
      final List<Uri> folders = codec.decode(
        '["file:///D:/media/","file:///D:/MEDIA/"]',
      );

      expect(folders, <Uri>[Uri.parse('file:///D:/media/')]);
    });

    test('ignores empty picked folder paths', () {
      expect(codec.directoryUriFromPath('  '), isNull);
      expect(codec.directoryUriFromPath(null), isNull);
    });
  });
}
