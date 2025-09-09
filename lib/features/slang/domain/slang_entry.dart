class SlangEntry {
  final String term;
  final String meaning;
  final String example;
  final List<String> emojis;
  final List<String> tags;

  SlangEntry({
    required this.term,
    required this.meaning,
    required this.example,
    required this.emojis,
    required this.tags,
  });

  factory SlangEntry.fromMap(Map<String, dynamic> m) => SlangEntry(
    term: m['term'] as String,
    meaning: m['meaning'] as String,
    example: m['example'] as String,
    emojis: (m['emojis'] as List).map((e) => e.toString()).toList(),
    tags: (m['tags'] as List).map((e) => e.toString()).toList(),
  );
}
