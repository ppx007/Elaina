import 'dart:convert';

final class MediaLibraryFolderPreferenceCodec {
  const MediaLibraryFolderPreferenceCodec();

  String encode(Iterable<Uri> folders) {
    return jsonEncode(<String>[
      for (final Uri folder in folders) folder.toString(),
    ]);
  }

  List<Uri> decode(String rawValue) {
    final Object? decoded = jsonDecode(rawValue);
    if (decoded is! List<Object?>) {
      throw const FormatException(
        'Media library folders preference must be a JSON array.',
      );
    }
    final List<Uri> folders = <Uri>[];
    for (final Object? value in decoded) {
      final Uri folder = _decodeFolder(value);
      if (!containsFolder(folders, folder)) {
        folders.add(folder);
      }
    }
    return folders;
  }

  Uri? directoryUriFromPath(String? path) {
    final String? trimmedPath = path?.trim();
    if (trimmedPath == null || trimmedPath.isEmpty) {
      return null;
    }
    return Uri.directory(trimmedPath);
  }

  bool containsFolder(Iterable<Uri> folders, Uri folder) {
    for (final Uri configuredFolder in folders) {
      if (sameFolder(configuredFolder, folder)) {
        return true;
      }
    }
    return false;
  }

  bool sameFolder(Uri left, Uri right) => _folderKey(left) == _folderKey(right);

  List<Uri> replaceFolder({
    required Iterable<Uri> folders,
    required Uri existingFolder,
    required Uri replacementFolder,
  }) {
    final List<Uri> updatedFolders = <Uri>[];
    var replaced = false;
    for (final Uri folder in folders) {
      if (sameFolder(folder, existingFolder)) {
        if (!containsFolder(updatedFolders, replacementFolder)) {
          updatedFolders.add(replacementFolder);
        }
        replaced = true;
        continue;
      }
      if (!sameFolder(folder, replacementFolder)) {
        updatedFolders.add(folder);
      }
    }
    if (!replaced && !containsFolder(updatedFolders, replacementFolder)) {
      updatedFolders.add(replacementFolder);
    }
    return updatedFolders;
  }

  Uri _decodeFolder(Object? value) {
    if (value is! String) {
      throw const FormatException(
        'Media library folder entries must be strings.',
      );
    }
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || !uri.isScheme('file')) {
      throw FormatException('Invalid media library folder URI: $value');
    }
    return uri;
  }

  String _folderKey(Uri uri) => uri.toString().toLowerCase();
}
