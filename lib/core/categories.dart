import 'package:flutter/material.dart';

import 'l10n.dart';

/// Ana menüdeki oyun kategorileri.
enum GameCategory { memory, reflex, math, word, puzzle, arcade }

/// Oyun kimliği -> kategori. Yeni oyun eklenince buraya da bir satır ekle
/// (eklenmezse oyun "Arcade" sayılır).
const Map<String, GameCategory> _categoryById = {
  // Hafıza
  'sequence_echo': GameCategory.memory,
  'flip_pairs': GameCategory.memory,
  'number_memory': GameCategory.memory,
  'chimp_test': GameCategory.memory,
  'grid_memory': GameCategory.memory,
  'back_memory': GameCategory.memory,
  'reverse_echo': GameCategory.memory,
  'shell_game': GameCategory.memory,
  'spot_change': GameCategory.memory,
  'path_memory': GameCategory.memory,
  'word_recall': GameCategory.memory,
  // Refleks
  'tap_rush': GameCategory.reflex,
  'reflex': GameCategory.reflex,
  'time_stop': GameCategory.reflex,
  'mole_hunt': GameCategory.reflex,
  'timing_bar': GameCategory.reflex,
  'tap_storm': GameCategory.reflex,
  'rps_speed': GameCategory.reflex,
  'orbit_tap': GameCategory.reflex,
  'number_order': GameCategory.reflex,
  'arrow_rule': GameCategory.reflex,
  'color_words': GameCategory.reflex,
  'shape_sort': GameCategory.reflex,
  'dot_count': GameCategory.reflex,
  'wire_cut': GameCategory.reflex,
  'emoji_hunt': GameCategory.reflex,
  'odd_one_out': GameCategory.reflex,
  // Matematik
  'math_rush': GameCategory.math,
  'quick_compare': GameCategory.math,
  'higher_lower': GameCategory.math,
  'target_sum': GameCategory.math,
  'true_false': GameCategory.math,
  'odd_even': GameCategory.math,
  'sum_ten': GameCategory.math,
  'pattern_finder': GameCategory.math,
  'next_number': GameCategory.math,
  'binary_bits': GameCategory.math,
  'clock_read': GameCategory.math,
  // Kelime
  'word_scramble': GameCategory.word,
  'missing_letter': GameCategory.word,
  'letter_hunt': GameCategory.word,
  'category_rush': GameCategory.word,
  // Bulmaca
  'lights_out': GameCategory.puzzle,
  'slide_puzzle': GameCategory.puzzle,
  'hanoi': GameCategory.puzzle,
  'mini_sudoku': GameCategory.puzzle,
  'mine_sweep': GameCategory.puzzle,
  'tube_sort': GameCategory.puzzle,
  'maze_dash': GameCategory.puzzle,
  'color_mixer': GameCategory.puzzle,
  'mirror_match': GameCategory.puzzle,
  'color_flood': GameCategory.puzzle,
  'merge_2048': GameCategory.puzzle,
  // Arcade
  'balloon_pop': GameCategory.arcade,
  'catch_fall': GameCategory.arcade,
  'stack_tower': GameCategory.arcade,
  'flap_dot': GameCategory.arcade,
  'dodge_rush': GameCategory.arcade,
  'snake': GameCategory.arcade,
  'paddle_bounce': GameCategory.arcade,
  'lane_runner': GameCategory.arcade,
  'brick_breaker': GameCategory.arcade,
  'star_blaster': GameCategory.arcade,
  'gravity_flip': GameCategory.arcade,
  'hop_rush': GameCategory.arcade,
};

GameCategory categoryOf(String gameId) =>
    _categoryById[gameId] ?? GameCategory.arcade;

extension GameCategoryX on GameCategory {
  String label(AppStrings t) {
    switch (this) {
      case GameCategory.memory:
        return t.p('Memory', 'Hafıza');
      case GameCategory.reflex:
        return t.p('Reflex', 'Refleks');
      case GameCategory.math:
        return t.p('Math', 'Matematik');
      case GameCategory.word:
        return t.p('Word', 'Kelime');
      case GameCategory.puzzle:
        return t.p('Puzzle', 'Bulmaca');
      case GameCategory.arcade:
        return 'Arcade';
    }
  }

  IconData get icon {
    switch (this) {
      case GameCategory.memory:
        return Icons.psychology_rounded;
      case GameCategory.reflex:
        return Icons.bolt_rounded;
      case GameCategory.math:
        return Icons.calculate_rounded;
      case GameCategory.word:
        return Icons.abc_rounded;
      case GameCategory.puzzle:
        return Icons.extension_rounded;
      case GameCategory.arcade:
        return Icons.sports_esports_rounded;
    }
  }

  Color get color {
    switch (this) {
      case GameCategory.memory:
        return const Color(0xFFA472EE);
      case GameCategory.reflex:
        return const Color(0xFFFFC94D);
      case GameCategory.math:
        return const Color(0xFF4D9DFF);
      case GameCategory.word:
        return const Color(0xFF3DDC84);
      case GameCategory.puzzle:
        return const Color(0xFF22D3EE);
      case GameCategory.arcade:
        return const Color(0xFFFF5E7E);
    }
  }
}
