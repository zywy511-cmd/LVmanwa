import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChapterSummaryProgress extends ChangeNotifier {
  bool _isGenerating = false;
  String _content = '';
  String _reasoningContent = '';
  String? _error;

  bool get isGenerating => _isGenerating;
  String get content => _content;
  String get reasoningContent => _reasoningContent;
  String? get error => _error;
  bool get hasState =>
      _isGenerating ||
      _content.isNotEmpty ||
      _reasoningContent.isNotEmpty ||
      _error != null;

  void _start({String initialContent = '', String initialReasoning = ''}) {
    _isGenerating = true;
    _content = initialContent;
    _reasoningContent = initialReasoning;
    _error = null;
    notifyListeners();
  }

  void _update(String content, {String? reasoningContent}) {
    _content = content;
    if (reasoningContent != null) {
      _reasoningContent = reasoningContent;
    }
    _error = null;
    notifyListeners();
  }

  void _complete(String content, {String? reasoningContent}) {
    _isGenerating = false;
    _content = content;
    if (reasoningContent != null) {
      _reasoningContent = reasoningContent;
    }
    _error = null;
    notifyListeners();
  }

  void _fail(String error) {
    _isGenerating = false;
    _error = error;
    notifyListeners();
  }

  void _clear() {
    _isGenerating = false;
    _content = '';
    _reasoningContent = '';
    _error = null;
    notifyListeners();
  }
}

/// 按章节 uuid 持久化 AI 评论总结。
class ChapterSummaryCache {
  static const _prefix = 'zhipu_chapter_summary_';
  static final Map<String, ChapterSummaryProgress> _progress = {};

  static ChapterSummaryProgress progressOf(String chapterUuid) =>
      _progress.putIfAbsent(chapterUuid, () => ChapterSummaryProgress());

  static bool isGenerating(String chapterUuid) =>
      _progress[chapterUuid]?.isGenerating ?? false;

  static void startProgress(
    String chapterUuid, {
    String initialContent = '',
    String initialReasoning = '',
  }) {
    progressOf(chapterUuid)._start(
      initialContent: initialContent,
      initialReasoning: initialReasoning,
    );
  }

  static void updateProgress(
    String chapterUuid,
    String content, {
    String? reasoningContent,
  }) {
    progressOf(
      chapterUuid,
    )._update(content, reasoningContent: reasoningContent);
  }

  static void failProgress(String chapterUuid, String error) {
    progressOf(chapterUuid)._fail(error);
  }

  static void clearProgress(String chapterUuid) {
    progressOf(chapterUuid)._clear();
  }

  static Future<String?> get(String chapterUuid) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('$_prefix$chapterUuid');
  }

  static Future<void> set(
    String chapterUuid,
    String content, {
    String? reasoningContent,
  }) async {
    final sp = await SharedPreferences.getInstance();
    if (content.isEmpty) {
      await sp.remove('$_prefix$chapterUuid');
      clearProgress(chapterUuid);
    } else {
      await sp.setString('$_prefix$chapterUuid', content);
      progressOf(
        chapterUuid,
      )._complete(content, reasoningContent: reasoningContent);
    }
  }

  static Future<void> remove(String chapterUuid) async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('$_prefix$chapterUuid');
    clearProgress(chapterUuid);
  }
}
