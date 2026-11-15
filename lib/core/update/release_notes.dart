/// A block of release notes, reduced from Markdown to what the update
/// sheet shows: section headings, bullets and paragraphs.
sealed class NoteBlock {
  const NoteBlock(this.text);

  /// Plain text, with inline Markdown removed.
  final String text;
}

/// A `#` heading.
final class NoteHeading extends NoteBlock {
  /// Creates a heading.
  const NoteHeading(super.text);
}

/// A `-` or `*` list item.
final class NoteBullet extends NoteBlock {
  /// Creates a bullet.
  const NoteBullet(super.text);
}

/// Any other line of text.
final class NoteParagraph extends NoteBlock {
  /// Creates a paragraph.
  const NoteParagraph(super.text);
}

final _heading = RegExp(r'^#{1,6}\s+(.*)$');
final _bullet = RegExp(r'^\s*[-*+]\s+(.*)$');
final _link = RegExp(r'\[([^\]]*)\]\([^)]*\)');
final _emphasis = RegExp(r'(\*\*|__|`)');

String _inline(String text) =>
    text.replaceAllMapped(_link, (m) => m[1]!).replaceAll(_emphasis, '').trim();

/// Turns release-note Markdown into [NoteBlock]s. Tables, rules and HTML
/// are dropped: the sheet is a summary, the release page has the rest.
List<NoteBlock> parseReleaseNotes(String markdown) {
  final blocks = <NoteBlock>[];
  final paragraph = StringBuffer();
  void flush() {
    final text = _inline(paragraph.toString());
    if (text.isNotEmpty) blocks.add(NoteParagraph(text));
    paragraph.clear();
  }

  for (final raw in markdown.split('\n')) {
    final line = raw.trimRight();
    final trimmed = line.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('|') ||
        trimmed.startsWith('<') ||
        RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
      flush();
      continue;
    }
    final heading = _heading.firstMatch(trimmed);
    final bullet = heading == null ? _bullet.firstMatch(line) : null;
    if (heading != null || bullet != null) {
      flush();
      final text = _inline((heading ?? bullet)![1]!);
      if (text.isEmpty) continue;
      blocks.add(heading != null ? NoteHeading(text) : NoteBullet(text));
      continue;
    }
    if (paragraph.isNotEmpty) paragraph.write(' ');
    paragraph.write(trimmed);
  }
  flush();
  return blocks;
}
