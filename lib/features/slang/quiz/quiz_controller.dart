import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/slang_entry.dart';
import '../app/slang_providers.dart';

/// Two question types:
///  - termToMeaning:   prompt = entry.term,     correct = entry.meaning
///  - meaningToTerm:   prompt = entry.meaning,  correct = entry.term
enum QuizType { termToMeaning, meaningToTerm }

class QuizQuestion {
  final QuizType type;
  final String prompt;       // what we show as the question text
  final String correct;      // correct option (raw/original text)
  final List<String> options; // exactly 4 options (shuffled)
  final SlangEntry entry;    // the original slang entry

  QuizQuestion({
    required this.type,
    required this.prompt,
    required this.correct,
    required this.options,
    required this.entry,
  });
}

class QuizState {
  final List<QuizQuestion> questions;
  final int index;            // 0-based
  final int score;
  final String? selected;     // chosen option (raw text) for current question
  final bool finished;

  const QuizState({
    required this.questions,
    required this.index,
    required this.score,
    required this.selected,
    required this.finished,
  });

  QuizState copyWith({
    List<QuizQuestion>? questions,
    int? index,
    int? score,
    String? selected,
    bool? finished,
  }) =>
      QuizState(
        questions: questions ?? this.questions,
        index: index ?? this.index,
        score: score ?? this.score,
        selected: selected,
        finished: finished ?? this.finished,
      );

  static const empty = QuizState(
    questions: <QuizQuestion>[],
    index: 0,
    score: 0,
    selected: null,
    finished: false,
  );
}

class QuizController extends StateNotifier<QuizState> {
  QuizController(QuizState state) : super(state);

  /// Build a fresh quiz from the loaded slang list.
  factory QuizController.fromSlang(List<SlangEntry> all, {int length = 10}) {
    final rng = Random();
    if (all.isEmpty) return QuizController(QuizState.empty);

    // Pick N unique entries
    final pool = List<SlangEntry>.from(all)..shuffle(rng);
    final take = pool.take(length.clamp(1, all.length)).toList();

    final questions = <QuizQuestion>[];
    for (final entry in take) {
      final type = rng.nextBool() ? QuizType.termToMeaning : QuizType.meaningToTerm;

      // Build options
      final options = _buildOptions(entry, all, type, rng);

      final correct =
          (type == QuizType.termToMeaning) ? entry.meaning : entry.term;

      questions.add(QuizQuestion(
        type: type,
        prompt: (type == QuizType.termToMeaning) ? entry.term : entry.meaning,
        correct: correct,
        options: options,
        entry: entry,
      ));
    }

    return QuizController(QuizState(
      questions: questions,
      index: 0,
      score: 0,
      selected: null,
      finished: questions.isEmpty,
    ));
  }

  /// Normalize strings to avoid false negatives:
  /// - trim, lowercase
  /// - collapse spaces
  /// - strip punctuation
  static String _norm(String s) {
    final lower = s.trim().toLowerCase();
    final collapsed = lower.replaceAll(RegExp(r'\s+'), ' ');
    final stripped = collapsed.replaceAll(RegExp(r'[^\w\s]'), '');
    return stripped;
  }

  /// Compose exactly 4 options (including the correct one), deduped by normalized text.
  static List<String> _buildOptions(
    SlangEntry entry,
    List<SlangEntry> all,
    QuizType type,
    Random rng,
  ) {
    // candidate pool (excluding this entry)
    final others = List<SlangEntry>.from(all)..remove(entry)..shuffle(rng);

    // Correct answer text
    final correct = (type == QuizType.termToMeaning) ? entry.meaning : entry.term;

    // Generate wrong answers from others
    final wrongs = <String>[];
    for (final e in others) {
      final candidate =
          (type == QuizType.termToMeaning) ? e.meaning : e.term;
      // Deduplicate by normalized text & avoid adding something equal to the correct
      if (_norm(candidate) != _norm(correct) &&
          !wrongs.any((w) => _norm(w) == _norm(candidate))) {
        wrongs.add(candidate);
      }
      if (wrongs.length >= 10) break; // limit search footprint
    }

    // Assemble: 1 correct + 3 wrongs (fallbacks if needed)
    final options = <String>[];
    options.add(correct);

    // pick up to 3 wrongs
    wrongs.shuffle(rng);
    options.addAll(wrongs.take(3));

    // If we still have less than 4, pad with random distinct items from full pool
    if (options.length < 4) {
      final allTexts = (type == QuizType.termToMeaning)
          ? all.map((e) => e.meaning).toList()
          : all.map((e) => e.term).toList();
      allTexts.shuffle(rng);
      for (final t in allTexts) {
        if (options.length >= 4) break;
        if (!_containsNorm(options, t) && _norm(t) != _norm(correct)) {
          options.add(t);
        }
      }
    }

    // Final guard: if still < 4 (extremely rare), duplicate correct variants
    while (options.length < 4) {
      options.add('$correct ');
    }

    // Shuffle options
    options.shuffle(rng);
    return options;
  }

  static bool _containsNorm(List<String> list, String value) {
    final nv = _norm(value);
    for (final v in list) {
      if (_norm(v) == nv) return true;
    }
    return false;
  }

  /// User selects an option (raw text).
  void select(String option) {
    if (state.finished || state.selected != null) return;

    final q = state.questions[state.index];
    final isCorrect = _norm(option) == _norm(q.correct);
    final newScore = isCorrect ? state.score + 1 : state.score;

    state = state.copyWith(selected: option, score: newScore);
  }

  /// Move to next question or finish.
  void next() {
    if (state.finished) return;
    final last = state.index >= state.questions.length - 1;
    if (last) {
      state = state.copyWith(finished: true);
    } else {
      state = state.copyWith(index: state.index + 1, selected: null);
    }
  }

  /// Start a fresh quiz using the same data source.
  void restart(List<SlangEntry> all, {int length = 10}) {
    final fresh = QuizController.fromSlang(all, length: length).state;
    state = fresh;
  }
}

/// Number of questions per quiz.
final quizLengthProvider = Provider<int>((_) => 10);

/// Quiz controller provider: builds a new quiz when slang list is loaded.
final quizControllerProvider =
    StateNotifierProvider.autoDispose<QuizController, QuizState>((ref) {
  final len = ref.watch(quizLengthProvider);
  final listAsync = ref.watch(slangListProvider);

  return listAsync.maybeWhen(
    data: (list) => QuizController.fromSlang(list, length: len),
    orElse: () => QuizController(QuizState.empty),
  );
});