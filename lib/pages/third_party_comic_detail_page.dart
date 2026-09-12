import 'package:flutter/material.dart';
import 'package:material3_expressive_loading_indicator/material3_expressive_loading_indicator.dart';

import '../api/third_party/third_party_source.dart';
import '../api/third_party/third_party_sources.dart';
import '../models/comic.dart' hide Theme;
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../widgets/third_party_image.dart';
import 'third_party_reader_page.dart';

/// 第三方漫源（漫屋3/漫屋吧）详情页：标题/封面/作者/状态/简介 + 章节列表。
class ThirdPartyComicDetailPage extends StatefulWidget {
  final String pathWord; // 形如 waman3:123456
  final Comic? initialComic;

  const ThirdPartyComicDetailPage({
    super.key,
    required this.pathWord,
    this.initialComic,
  });

  @override
  State<ThirdPartyComicDetailPage> createState() =>
      _ThirdPartyComicDetailPageState();
}

class _ThirdPartyComicDetailPageState extends State<ThirdPartyComicDetailPage> {
  ThirdPartyComicSource? get _source {
    final key = ThirdPartyComicSource.sourceKeyOfPathWord(widget.pathWord);
    return key == null ? null : ThirdPartySources.byKey(key);
  }

  String get _comicId =>
      ThirdPartyComicSource.comicIdOfPathWord(widget.pathWord);

  ThirdPartyComicDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    });
    try {
      final detail = await source.loadInfo(_comicId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      debugPrint('${source.key} 详情加载失败: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openReader(List<ThirdPartyChapter> chapters, int index) {
    final source = _source;
    if (source == null || chapters.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThirdPartyReaderPage(
          sourceKey: source.key,
          comicId: _comicId,
          comicName: _detail?.title ?? widget.initialComic?.name ?? '',
          chapters: chapters,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final source = _source;

    return Scaffold(
      appBar: AppBar(title: Text(_detail?.title ?? source?.name ?? '')),
      body: _loading
          ? const Center(child: ExpressiveLoadingIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 48, color: cs.onSurfaceVariant),
                      const SizedBox(height: AppSpacing.md),
                      Text(_error!, style: tt.bodySmall),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.tonal(
                        onPressed: _load,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _buildContent(cs, tt),
    );
  }

  Widget _buildContent(ColorScheme cs, TextTheme tt) {
    final detail = _detail!;
    final cover = detail.cover.isNotEmpty
        ? detail.cover
        : (widget.initialComic?.cover ?? '');
    // 章节按阅读顺序（旧->新）展示为「最新在上」
    final chapters = detail.chapters.reversed.toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.mdR,
                  child: SizedBox(
                    width: 110,
                    height: 150,
                    child: TpAwareImage(
                      sourceKey: _source?.key,
                      url: cover,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.title,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (detail.authors.isNotEmpty)
                        Text(
                          '作者：${detail.authors.join(' / ')}',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      if (detail.statusDisplay != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '状态：${detail.statusDisplay}',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (detail.updateTime != null &&
                          detail.updateTime!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '更新：${detail.updateTime}',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (detail.tags.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: detail.tags
                              .take(6)
                              .map(
                                (t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.secondaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    t,
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (detail.description.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                detail.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ),
        if (chapters.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.format_list_numbered, size: 18, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    '章节列表（共 ${chapters.length} 话）',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        if (chapters.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverList.separated(
              itemCount: chapters.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final chapter = chapters[i];
                final realIndex = detail.chapters.length - 1 - i;
                return Material(
                  color: cs.surfaceContainerLow,
                  borderRadius: AppRadius.mdR,
                  child: InkWell(
                    borderRadius: AppRadius.mdR,
                    onTap: () => _openReader(detail.chapters, realIndex),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              chapter.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (chapters.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 56, color: cs.onSurfaceVariant),
                  const SizedBox(height: AppSpacing.md),
                  Text('暂无章节', style: tt.bodyMedium),
                ],
              ),
            ),
          ),
        if (chapters.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      _openReader(detail.chapters, detail.chapters.length - 1),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始阅读（最新话）'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
