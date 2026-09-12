import '../../models/comic.dart' hide Theme;

/// 第三方漫源统一搜索结果。
class ThirdPartySearchResult {
  final List<Comic> comics;
  final int maxPage;

  const ThirdPartySearchResult({required this.comics, required this.maxPage});
}

/// 第三方漫源抽象（漫屋3 / 漫屋吧）。
///
/// 本轮移植覆盖：主页板块 + 关键词搜索。
/// 详情页 / 阅读器（含 AES 解密图片渲染）接入留待下一迭代。
abstract class ThirdPartyComicSource {
  /// 源 key：`waman3` / `manwaba`，用于 pathWord 前缀与设置持久化。
  String get key;

  /// 展示名：漫屋3 / 漫屋吧。
  String get name;

  /// 主页板块：板块标题 -> 漫画列表。
  Future<Map<String, List<Comic>>> loadHome();

  /// 关键词搜索（page 从 1 开始）。
  Future<ThirdPartySearchResult> search(String keyword, int page);

  /// 生成带源前缀的 pathWord，避免跨源 id 冲突：`waman3:123456`。
  String encodeComicId(String comicId) => '$key:$comicId';

  /// 从 pathWord 反向解析源 key；非第三方 pathWord 返回 null。
  static String? sourceKeyOfPathWord(String pathWord) {
    final sep = pathWord.indexOf(':');
    if (sep <= 0) return null;
    return pathWord.substring(0, sep);
  }
}
