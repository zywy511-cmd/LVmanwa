List<int?> inferSequentialDandanplayEpisodeBindings({
  required List<int?> currentEpisodeIds,
  required List<int> availableEpisodeIds,
}) {
  final nextEpisodeIds = List<int?>.of(currentEpisodeIds);
  if (nextEpisodeIds.isEmpty || availableEpisodeIds.isEmpty) {
    return nextEpisodeIds;
  }

  var lastBoundChapterIndex = -1;
  for (var i = nextEpisodeIds.length - 1; i >= 0; i--) {
    if (nextEpisodeIds[i] != null) {
      lastBoundChapterIndex = i;
      break;
    }
  }

  if (lastBoundChapterIndex < 0) {
    for (var i = 0; i < nextEpisodeIds.length; i++) {
      if (i >= availableEpisodeIds.length) break;
      nextEpisodeIds[i] = availableEpisodeIds[i];
    }
    return nextEpisodeIds;
  }

  final lastBoundEpisodeId = nextEpisodeIds[lastBoundChapterIndex];
  final lastBoundEpisodeIndex = availableEpisodeIds.indexOf(
    lastBoundEpisodeId!,
  );
  if (lastBoundEpisodeIndex < 0) return nextEpisodeIds;

  for (
    var chapterIndex = lastBoundChapterIndex + 1;
    chapterIndex < nextEpisodeIds.length;
    chapterIndex++
  ) {
    if (nextEpisodeIds[chapterIndex] != null) continue;
    final episodeIndex =
        lastBoundEpisodeIndex + chapterIndex - lastBoundChapterIndex;
    if (episodeIndex >= availableEpisodeIds.length) break;
    nextEpisodeIds[chapterIndex] = availableEpisodeIds[episodeIndex];
  }

  return nextEpisodeIds;
}
