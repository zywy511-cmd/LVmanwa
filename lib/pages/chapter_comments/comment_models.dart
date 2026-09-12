part of '../chapter_comments_sheet.dart';

class _AiSummaryModelChoice {
  final String providerId;
  final String providerName;
  final String model;

  const _AiSummaryModelChoice({
    required this.providerId,
    required this.providerName,
    required this.model,
  });
}

class _CommentRow {
  final List<_CommentLayoutItem> items;

  const _CommentRow({required this.items});
}

class _CommentLayoutItem {
  final ChapterCommentDisplayEntry entry;
  final double width;

  const _CommentLayoutItem({required this.entry, required this.width});
}

class _MergedCountTagColors {
  final Color foreground;

  const _MergedCountTagColors({required this.foreground});
}
