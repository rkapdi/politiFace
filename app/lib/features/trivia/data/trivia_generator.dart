import 'dart:math' as math;

import '../../../core/database/drift/app_database.dart';
import '../domain/trivia_question.dart';

/// Build a deterministic 10-question trivia run for a given date. Same date
/// + same card pool = same questions for every user, which is what makes the
/// "share your archetype" loop work — friends can ask "what did you get for
/// today's?" and compare grids honestly.
///
/// Distractors are picked first from the same deck as the answer card (so
/// the wrong options are plausible — "Secretary of Defense" not "Senator
/// from Iowa"), falling back to the broader pool.
class TriviaGenerator {
  const TriviaGenerator({this.questionsPerRun = 10});
  final int questionsPerRun;

  /// Build today's questions (or any specified date) from the active pool.
  List<TriviaQuestion> generate({
    required DateTime date,
    required List<LocalCard> cards,
  }) {
    if (cards.length < 4) return const [];
    final seed = _seedForDate(date);
    final rng = math.Random(seed);

    // Pick which cards we'll quiz on. Avoid repeats within a run.
    final pool = [...cards.where((c) => c.isActive)]..shuffle(rng);
    final picks = pool.take(questionsPerRun).toList();

    final questions = <TriviaQuestion>[];
    for (var i = 0; i < picks.length; i++) {
      final card = picks[i];
      // Rotate through the four formats so the run feels varied.
      final format = TriviaFormat.values[i % TriviaFormat.values.length];
      questions.add(_buildQuestion(
        card: card,
        format: format,
        pool: cards,
        rng: rng,
      ),);
    }
    return questions;
  }

  TriviaQuestion _buildQuestion({
    required LocalCard card,
    required TriviaFormat format,
    required List<LocalCard> pool,
    required math.Random rng,
  }) {
    final String correct;
    final String prompt;
    final String? photoUrl;

    switch (format) {
      case TriviaFormat.photoToName:
        correct = card.politicianName;
        prompt = 'Who is this?';
        photoUrl = card.photoUrl;
      case TriviaFormat.photoToTitle:
        correct = card.title;
        prompt = "What's their role?";
        photoUrl = card.photoUrl;
      case TriviaFormat.titleToName:
        correct = card.politicianName;
        prompt = 'Who currently holds the role of ${card.title}?';
        photoUrl = null;
      case TriviaFormat.nameToTitle:
        correct = card.title;
        prompt = "What's ${card.politicianName}'s role?";
        photoUrl = null;
    }

    final distractors = _pickDistractors(
      card: card,
      format: format,
      pool: pool,
      rng: rng,
      correctAnswer: correct,
    );
    final options = [correct, ...distractors]..shuffle(rng);
    final correctIndex = options.indexOf(correct);

    return TriviaQuestion(
      cardId: card.id,
      format: format,
      prompt: prompt,
      photoUrl: photoUrl,
      options: options,
      correctIndex: correctIndex,
    );
  }

  /// Pick 3 wrong-but-plausible options. Prefer same-deck cards first
  /// (Cabinet members for a Cabinet question, etc.) then widen to anywhere.
  ///
  /// For name-answer formats we also try to gender-match the distractors
  /// against the correct card. If the correct card's gender is missing or
  /// the filtered pool is too small, we fall through to the unfiltered
  /// pool — better one mixed-gender option than no question at all.
  List<String> _pickDistractors({
    required LocalCard card,
    required TriviaFormat format,
    required List<LocalCard> pool,
    required math.Random rng,
    required String correctAnswer,
  }) {
    String fieldFor(LocalCard c) {
      switch (format) {
        case TriviaFormat.photoToName:
        case TriviaFormat.titleToName:
          return c.politicianName;
        case TriviaFormat.photoToTitle:
        case TriviaFormat.nameToTitle:
          return c.title;
      }
    }

    // Gender matching only matters for name-answer formats — title strings
    // (roles) aren't gendered. Nonbinary / missing answer gender = no filter.
    final genderFilters = format == TriviaFormat.photoToName ||
        format == TriviaFormat.titleToName;
    final answerGender = card.gender;
    bool genderMatches(LocalCard c) {
      if (!genderFilters) return true;
      if (answerGender == null) return true;
      if (answerGender == 'nonbinary') return true;
      return c.gender == answerGender;
    }

    final sameDeckGendered = <String>{
      for (final c in pool)
        if (c.id != card.id && c.deckId == card.deckId && genderMatches(c))
          fieldFor(c),
    }.toList();
    final widePoolGendered = <String>{
      for (final c in pool)
        if (c.id != card.id && genderMatches(c)) fieldFor(c),
    }.toList();
    // Unfiltered backup — used only if gendered pools come up short. Keeps
    // the question generator robust on tiny decks (a single woman in SCOTUS,
    // etc.).
    final widePoolAll = <String>{
      for (final c in pool)
        if (c.id != card.id) fieldFor(c),
    }.toList();

    for (final list in [sameDeckGendered, widePoolGendered, widePoolAll]) {
      list.remove(correctAnswer);
      list.shuffle(rng);
    }

    final picked = <String>{};
    for (final list in [sameDeckGendered, widePoolGendered, widePoolAll]) {
      for (final candidate in list) {
        if (picked.length == 3) break;
        picked.add(candidate);
      }
      if (picked.length == 3) break;
    }
    return picked.toList();
  }

  /// Stable per-day seed derived from the calendar date so every user
  /// sees the same questions for "today."
  int _seedForDate(DateTime date) {
    final local = date.toLocal();
    return local.year * 10000 + local.month * 100 + local.day;
  }
}
