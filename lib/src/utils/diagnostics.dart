/// Builds a `ClassName{fields, listName: [...]}` debug string.
///
/// Used by model classes' `toString()` to combine [describeFields] output
/// with [describeChildren] lists in a consistent, indented format.
String buildDescription(
  Type type,
  Map<String, dynamic> fields, [
  Map<String, List> children = const {},
]) {
  final parts = <String>[];
  if (fields.isNotEmpty) {
    parts.add(fields.entries.map((e) => '${e.key}: ${e.value}').join(', '));
  }
  for (final entry in children.entries) {
    final buf = StringBuffer('${entry.key}: [');
    for (var child in entry.value) {
      buf.write('\n\t${child.toString().replaceAll('\n', '\n\t')}');
    }
    buf.write('\n]');
    parts.add(buf.toString());
  }
  return '$type{${parts.join(', ')}}';
}
