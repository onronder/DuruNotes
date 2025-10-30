import 'package:duru_notes/data/local/app_db.dart';
import 'package:duru_notes/domain/entities/tag.dart' as domain;

/// Maps between domain Tag entity and infrastructure TagCount
class TagMapper {
  /// Convert infrastructure TagCount to domain TagWithCount
  static domain.TagWithCount toDomain(TagCount tagCount) {
    return domain.TagWithCount(
      tag: tagCount.tag,
      noteCount: tagCount.count, // TagCount has 'count', not 'noteCount'
    );
  }

  /// Convert domain TagWithCount to infrastructure TagCount
  static TagCount toInfrastructure(domain.TagWithCount tag) {
    return TagCount(
      tag: tag.tag,
      count: tag.noteCount, // TagCount has 'count', not 'noteCount'
    );
  }

  /// Convert TagCount list to domain TagWithCount list
  static List<domain.TagWithCount> toDomainList(List<TagCount> tagCounts) {
    return tagCounts.map((tag) => toDomain(tag)).toList();
  }

  /// Convert domain TagWithCount list to TagCount list
  static List<TagCount> toInfrastructureList(List<domain.TagWithCount> tags) {
    return tags.map((tag) => toInfrastructure(tag)).toList();
  }
}
