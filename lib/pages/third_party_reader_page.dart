import 'package:flutter/material.dart';
import 'package:material3_expressive_loading_indicator/material3_expressive_loading_indicator.dart';

import '../api/third_party/third_party_source.dart';
import '../api/third_party/third_party_sources.dart';
import '../widgets/third_party_image.dart';

/// 第三方漫源（漫屋3/漫屋吧）阅读器：
/// 章节图片列表加载 + 左右翻页 + 图片解密显示 + 上下话切换。
class ThirdPartyReaderPage extends StatefulWidget {
  final String sourceKey;
  final String comicId;
  final String comicName;
  final List<ThirdPartyChapter> chapters; // 按阅读顺序（旧->新）
  final int initialIndex;

  const ThirdPartyReaderPage({
    super.key,
    required this.sourceKey,
    required this.comicId,
    required this.comicName,
    required this.chapters,
    required this.initialIndex,
  });

  @override
  State<ThirdPartyReaderPage> createState() => _ThirdPartyReaderPageState();
}

class _ThirdPartyReaderPageState extends State<ThirdPartyReaderPage> {
  ThirdPartyComicSource? get _source =>
      ThirdPartySources.byKey(widget.sourceKey);

  late int _index = widget.initialIndex.clamp(0, widget.chapters.length - 1);
  List<String> _images = [];
  bool _loading = true;
  String? _error;
  final PageController _pageController = PageController();
  int _page = 1;

  ThirdPartyChapter get _chapter => widget.chapters[_index];

  @override
  void initState() {
    super.initState();
    _loadChapter();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadChapter() async {
    final source = _source;
    if (source == null) {
      setState(() {
        _loading = false;
        _error = '未知的漫源';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _images = [];
    });
    try {
      final images = await source.loadEp(widget.comicId, _chapter.id);
      if (!mounted) return;
      setState(() {
        _images = images;
        _loading = false;
        if (images.isEmpty) {
          _error = '本章暂无图片';
        }
      });
    } catch (e) {
      debugPrint('${source.key} 章节图片加载失败: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _switchChapter(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.chapters.length) return;
    setState(() => _index = next);
    _loadChapter();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chapter.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (!_loading && _images.isNotEmpty)
              Text(
                '$_page / ${_images.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: ExpressiveLoadingIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: _loadChapter,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _images.length,
                        onPageChanged: (page) {
                          setState(() => _page = page + 1);
                        },
                        itemBuilder: (context, i) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              // 左右半屏点击翻页
                              final width =
                                  MediaQuery.of(context).size.width;
                              final dx = _lastTapDx;
                              if (dx == null) return;
                              if (dx < width / 3) {
                                if (i > 0) {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                  );
                                } else {
                                  _switchChapter(-1);
                                }
                              } else if (dx > width * 2 / 3) {
                                if (i < _images.length - 1) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                  );
                                } else {
                                  _switchChapter(1);
                                }
                              }
                            },
                            onTapDown: (d) => _lastTapDx = d.localPosition.dx,
                            child: Center(
                              child: TpAwareImage(
                                sourceKey: widget.sourceKey,
                                url: _images[i],
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                tooltip: '上一话',
                                onPressed: _index > 0 ? () => _switchChapter(-1) : null,
                                icon: const Icon(Icons.skip_previous),
                              ),
                              Text(
                                '第 ${_index + 1}/${widget.chapters.length} 话',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                                ),
                              ),
                              IconButton(
                                tooltip: '下一话',
                                onPressed: _index < widget.chapters.length - 1
                                    ? () => _switchChapter(1)
                                    : null,
                                icon: const Icon(Icons.skip_next),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  double? _lastTapDx;
}
