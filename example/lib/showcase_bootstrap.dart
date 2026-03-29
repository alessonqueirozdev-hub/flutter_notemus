import 'package:flutter/services.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

Future<void>? _showcaseAssetsFuture;

Future<void> ensureShowcaseAssetsLoaded() {
  return _showcaseAssetsFuture ??= _loadShowcaseAssets();
}

void invalidateShowcaseAssetsCache() {
  _showcaseAssetsFuture = null;
}

Future<void> _loadShowcaseAssets() async {
  final loader = FontLoader('Bravura');
  loader.addFont(
    rootBundle.load('packages/flutter_notemus/assets/smufl/Bravura.otf'),
  );
  await loader.load();

  await SmuflMetadata().load();
}
