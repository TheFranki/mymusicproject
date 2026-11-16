import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'favorites_provider.dart';
import 'player_provider.dart';
import 'youtube_favorites_provider.dart';

import 'custom_artwork_provider.dart';
import 'player_controller.dart';

final notificationSyncProvider = Provider<void>((ref) {
  final handler = ref.read(audioHandlerProvider);

  void sync() {
    final song = ref.read(currentSongProvider);
    var fav = false;
    if (song != null) {
      if (song['isLocal'] == 'true') {
        fav = ref.read(favoritesIdsProvider).contains(song['data'] ?? '');
      } else {
        fav = ref
            .read(youtubeFavoritesProvider)
            .any((s) => s['id'] == song['id']);
      }
    }
    handler.updateExtras(
      shuffle: ref.read(isShuffleEnabledProvider),
      repeat: ref.read(repeatModeProvider),
      favorite: fav,
    );
  }

  ref.listen(isShuffleEnabledProvider, (_, _) => sync());
  ref.listen(repeatModeProvider, (_, _) => sync());
  ref.listen(currentSongProvider, (_, _) => sync());
  ref.listen(favoritesIdsProvider, (_, _) => sync());
  ref.listen(youtubeFavoritesProvider, (_, _) => sync());
  ref.listen(
    customArtworkProvider,
    (_, _) => ref.read(playerControllerProvider).refreshNowPlaying(),
  );
  ref.listen(
    customSongMetadataProvider,
    (_, _) => ref.read(playerControllerProvider).refreshNowPlaying(),
  );
  sync();
});
