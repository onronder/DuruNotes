import '../../data/local/app_db.dart';
import 'package:uuid/uuid.dart';

/// Bir link hedefini temsil eder.
/// - `@Title` veya `[[Title]]` -> title = "Title", id = null
/// - `@id:UUID` veya `[[id:UUID]]` -> title = "UUID", id = "UUID"
class LinkTarget {
  const LinkTarget({this.title, this.id});
  final String? title;
  final String? id;
}

/// #tag, [[Link]] / @Link parse edip DB indekslerini günceller.
class NoteIndexer {
  NoteIndexer(this.db);
  final AppDb db;

  // #etiket yakalama
  static final RegExp _tagRe = RegExp(r'(^|\s)#([\w\-]+)');

  // Eski tip link: [[...]]
  static final RegExp _legacyLinkRe = RegExp(r'\[\[([^\[\]]+)\]\]');

  // Yeni tip link: @...
  // Boşluk/harf olmayan bir karakterden sonra gelen '@' ve boşluğa kadar olan kısmı alır
  static final RegExp _atLinkRe = RegExp(r'(?<!\w)@([^\s\[\]]+)');

  Future<void> updateIndex(LocalNote n) async {
    final text = '${n.title}\n${n.body}';
    final tags = parseTags(text);
    final links = parseLinks(text);
    await db.replaceTagsForNote(n.id, tags);
    await db.replaceLinksForNote(n.id, links);
  }

  /// Metinden #tag’leri set olarak döndürür.
  Set<String> parseTags(String text) {
    final out = <String>{};
    for (final m in _tagRe.allMatches(text)) {
      final tag = m.group(2);
      if (tag != null && tag.isNotEmpty) {
        out.add(tag.trim());
      }
    }
    return out;
  }

  /// Metinden link hedeflerini listeler.
  /// Desteklenen formatlar:
  /// - `[[Title]]`, `[[id:<UUID>]]`
  /// - `@Title`, `@id:<UUID>`
  List<LinkTarget> parseLinks(String text) {
    final out = <LinkTarget>[];

    void addByRaw(String raw) {
      final v = raw.trim();
      if (v.isEmpty) return;

      if (v.startsWith('id:')) {
        final id = v.substring(3).trim();
        if (Uuid.isValidUUID(fromString: id)) {
          out.add(LinkTarget(title: id, id: id));
          return;
        }
        // UUID değilse başlık olarak düşer
      }

      out.add(LinkTarget(title: v));
    }

    // Eski stil: [[...]]
    for (final m in _legacyLinkRe.allMatches(text)) {
      final raw = m.group(1);
      if (raw != null) addByRaw(raw);
    }

    // Yeni stil: @...
    for (final m in _atLinkRe.allMatches(text)) {
      final raw = m.group(1);
      if (raw != null) addByRaw(raw);
    }

    return out;
  }
}
