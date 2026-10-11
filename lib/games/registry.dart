import 'package:flutter/material.dart';

import '../core/mini_game.dart';
import 'arrow_rule/arrow_rule_screen.dart';
import 'chimp_test/chimp_test_screen.dart';
import 'clock_read/clock_read_screen.dart';
import 'color_match/color_match_screen.dart';
import 'color_words/color_words_screen.dart';
import 'dot_count/dot_count_screen.dart';
import 'flip_pairs/flip_pairs_screen.dart';
import 'grid_memory/grid_memory_screen.dart';
import 'higher_lower/higher_lower_screen.dart';
import 'lights_out/lights_out_screen.dart';
import 'letter_hunt/letter_hunt_screen.dart';
import 'math_rush/math_rush_screen.dart';
import 'mole_hunt/mole_hunt_screen.dart';
import 'number_memory/number_memory_screen.dart';
import 'number_order/number_order_screen.dart';
import 'pattern_finder/pattern_finder_screen.dart';
import 'quick_compare/quick_compare_screen.dart';
import 'reflex/reflex_screen.dart';
import 'shape_sort/shape_sort_screen.dart';
import 'slide_puzzle/slide_puzzle_screen.dart';
import 'odd_one_out/odd_one_out_screen.dart';
import 'sequence_echo/sequence_echo_screen.dart';
import 'tap_rush/tap_rush_screen.dart';
import 'target_sum/target_sum_screen.dart';
import 'time_stop/time_stop_screen.dart';
import 'timing_bar/timing_bar_screen.dart';

/// Ana menüde görünen oyunlar. Yeni oyun eklemek için buraya bir satır ekle.
final List<MiniGame> allGames = [
  MiniGame(
    id: 'color_match',
    nameEn: 'Color Match',
    nameTr: 'Renk Eşle',
    descEn: 'Memorize a color, find its exact twin.',
    descTr: 'Rengi aklında tut, aynısını bul.',
    icon: Icons.palette_rounded,
    color: const Color(0xFFFF5E7E),
    builder: () => const ColorMatchScreen(),
  ),
  MiniGame(
    id: 'odd_one_out',
    nameEn: 'Odd One Out',
    nameTr: 'Farklı Olan',
    descEn: 'Spot the slightly different shade.',
    descTr: 'Biraz farklı tonu yakala.',
    icon: Icons.grid_view_rounded,
    color: const Color(0xFF4D9DFF),
    builder: () => const OddOneOutScreen(),
  ),
  MiniGame(
    id: 'sequence_echo',
    nameEn: 'Sequence Echo',
    nameTr: 'Sıra Hafızası',
    descEn: 'Watch the pattern, repeat it.',
    descTr: 'Sırayı izle, tekrar et.',
    icon: Icons.graphic_eq_rounded,
    color: const Color(0xFF3DDC84),
    builder: () => const SequenceEchoScreen(),
  ),
  MiniGame(
    id: 'math_rush',
    nameEn: 'Math Rush',
    nameTr: 'Hızlı İşlem',
    descEn: 'Solve quick sums before time runs out.',
    descTr: 'Süre bitmeden işlemleri çöz.',
    icon: Icons.calculate_rounded,
    color: const Color(0xFFA472EE),
    builder: () => const MathRushScreen(),
  ),
  MiniGame(
    id: 'lights_out',
    nameEn: 'Lights Out',
    nameTr: 'Işıkları Söndür',
    descEn: 'Turn off every light on the board.',
    descTr: 'Tahtadaki tüm ışıkları söndür.',
    icon: Icons.lightbulb_rounded,
    color: const Color(0xFFFFC94D),
    builder: () => const LightsOutScreen(),
  ),
  MiniGame(
    id: 'tap_rush',
    nameEn: 'Tap Rush',
    nameTr: 'Dokun Kaç',
    descEn: 'Tap the target before it vanishes.',
    descTr: 'Hedef kaybolmadan dokun.',
    icon: Icons.touch_app_rounded,
    color: const Color(0xFFFF8A4D),
    builder: () => const TapRushScreen(),
  ),
  MiniGame(
    id: 'flip_pairs',
    nameEn: 'Pair Flip',
    nameTr: 'Çift Çevir',
    descEn: 'Flip cards and match every pair.',
    descTr: 'Kartları çevir, çiftleri eşleştir.',
    icon: Icons.style_rounded,
    color: const Color(0xFF22D3EE),
    builder: () => const FlipPairsScreen(),
  ),
  MiniGame(
    id: 'number_memory',
    nameEn: 'Number Memory',
    nameTr: 'Sayı Hafızası',
    descEn: 'Memorize the digits, type them back.',
    descTr: 'Sayıyı aklında tut, geri yaz.',
    icon: Icons.pin_rounded,
    color: const Color(0xFFE879F9),
    builder: () => const NumberMemoryScreen(),
  ),
  MiniGame(
    id: 'color_words',
    nameEn: 'Color Words',
    nameTr: 'Renkli Kelime',
    descEn: 'Pick the ink color, not the word.',
    descTr: 'Yazıyı değil, rengi seç.',
    icon: Icons.text_fields_rounded,
    color: const Color(0xFFA3E635),
    builder: () => const ColorWordsScreen(),
  ),
  MiniGame(
    id: 'number_order',
    nameEn: 'Number Order',
    nameTr: 'Sayı Sırası',
    descEn: 'Tap the numbers in order, fast.',
    descTr: 'Sayılara sırayla hızlıca dokun.',
    icon: Icons.format_list_numbered_rounded,
    color: const Color(0xFF818CF8),
    builder: () => const NumberOrderScreen(),
  ),
  MiniGame(
    id: 'pattern_finder',
    nameEn: 'Pattern Finder',
    nameTr: 'Örüntü Bul',
    descEn: 'Spot the rule, pick the next number.',
    descTr: 'Kuralı bul, sıradaki sayıyı seç.',
    icon: Icons.timeline_rounded,
    color: const Color(0xFF2DD4BF),
    builder: () => const PatternFinderScreen(),
  ),
  MiniGame(
    id: 'quick_compare',
    nameEn: 'Quick Compare',
    nameTr: 'Hızlı Karşılaştır',
    descEn: 'Which sum is bigger? Decide fast.',
    descTr: 'Hangi işlem büyük? Hızlı karar ver.',
    icon: Icons.compare_arrows_rounded,
    color: const Color(0xFFF472B6),
    builder: () => const QuickCompareScreen(),
  ),
  MiniGame(
    id: 'arrow_rule',
    nameEn: 'Arrow Rule',
    nameTr: 'Ok Kuralı',
    descEn: 'Green: same way. Red: opposite.',
    descTr: 'Yeşil: aynı yön. Kırmızı: ters.',
    icon: Icons.open_with_rounded,
    color: const Color(0xFFFB7185),
    builder: () => const ArrowRuleScreen(),
  ),
  MiniGame(
    id: 'dot_count',
    nameEn: 'Dot Count',
    nameTr: 'Nokta Say',
    descEn: 'Count the dots in a blink.',
    descTr: 'Noktaları göz açıp kapayana kadar say.',
    icon: Icons.scatter_plot_rounded,
    color: const Color(0xFF38BDF8),
    builder: () => const DotCountScreen(),
  ),
  MiniGame(
    id: 'reflex',
    nameEn: 'Reflex',
    nameTr: 'Refleks',
    descEn: 'Tap the instant it turns green.',
    descTr: 'Yeşile dönünce hemen dokun.',
    icon: Icons.flash_on_rounded,
    color: const Color(0xFFFDE047),
    builder: () => const ReflexScreen(),
  ),
  MiniGame(
    id: 'time_stop',
    nameEn: 'Time Stop',
    nameTr: 'Zamanı Tut',
    descEn: 'Stop the clock at the exact second.',
    descTr: 'Saati tam saniyesinde durdur.',
    icon: Icons.timer_rounded,
    color: const Color(0xFFC4B5FD),
    builder: () => const TimeStopScreen(),
  ),
  MiniGame(
    id: 'mole_hunt',
    nameEn: 'Mole Hunt',
    nameTr: 'Köstebek Avı',
    descEn: 'Whack the moles, dodge the bombs.',
    descTr: 'Köstebekleri vur, bombalardan kaç.',
    icon: Icons.gps_fixed_rounded,
    color: const Color(0xFFD97706),
    builder: () => const MoleHuntScreen(),
  ),
  MiniGame(
    id: 'higher_lower',
    nameEn: 'Higher or Lower',
    nameTr: 'Büyük mü Küçük mü',
    descEn: 'Guess if the next number is higher.',
    descTr: 'Sıradaki sayı büyük mü küçük mü?',
    icon: Icons.swap_vert_rounded,
    color: const Color(0xFF5EEAD4),
    builder: () => const HigherLowerScreen(),
  ),
  MiniGame(
    id: 'shape_sort',
    nameEn: 'Shape Sort',
    nameTr: 'Şekil Ayır',
    descEn: 'Sort shapes left or right. Rules change.',
    descTr: 'Şekilleri sağa sola ayır, kural değişir.',
    icon: Icons.category_rounded,
    color: const Color(0xFFFCA5A5),
    builder: () => const ShapeSortScreen(),
  ),
  MiniGame(
    id: 'letter_hunt',
    nameEn: 'Letter Hunt',
    nameTr: 'Harf Avı',
    descEn: 'Find the odd letter in the grid.',
    descTr: 'Tablodaki farklı harfi bul.',
    icon: Icons.search_rounded,
    color: const Color(0xFF86EFAC),
    builder: () => const LetterHuntScreen(),
  ),
  MiniGame(
    id: 'timing_bar',
    nameEn: 'Perfect Stop',
    nameTr: 'Tam Vuruş',
    descEn: 'Stop the marker inside the green zone.',
    descTr: 'İşareti yeşil alanda durdur.',
    icon: Icons.linear_scale_rounded,
    color: const Color(0xFFFDBA74),
    builder: () => const TimingBarScreen(),
  ),
  MiniGame(
    id: 'slide_puzzle',
    nameEn: 'Slide Puzzle',
    nameTr: 'Kaydırmalı Bulmaca',
    descEn: 'Slide the tiles into order.',
    descTr: 'Kareleri kaydırıp sıraya diz.',
    icon: Icons.extension_rounded,
    color: const Color(0xFF93C5FD),
    builder: () => const SlidePuzzleScreen(),
  ),
  MiniGame(
    id: 'chimp_test',
    nameEn: 'Chimp Test',
    nameTr: 'Maymun Testi',
    descEn: 'Remember where the numbers were.',
    descTr: 'Sayıların yerini hatırla, sırayla dokun.',
    icon: Icons.visibility_off_rounded,
    color: const Color(0xFFF9A8D4),
    builder: () => const ChimpTestScreen(),
  ),
  MiniGame(
    id: 'grid_memory',
    nameEn: 'Grid Memory',
    nameTr: 'Kare Hafızası',
    descEn: 'Remember which squares lit up.',
    descTr: 'Hangi karelerin yandığını hatırla.',
    icon: Icons.grid_on_rounded,
    color: const Color(0xFF6EE7B7),
    builder: () => const GridMemoryScreen(),
  ),
  MiniGame(
    id: 'target_sum',
    nameEn: 'Target Sum',
    nameTr: 'Hedef Toplam',
    descEn: 'Pick tiles that add up to the target.',
    descTr: 'Toplamı hedefe eşitleyen kareleri seç.',
    icon: Icons.functions_rounded,
    color: const Color(0xFFFCD34D),
    builder: () => const TargetSumScreen(),
  ),
  MiniGame(
    id: 'clock_read',
    nameEn: 'Read the Clock',
    nameTr: 'Saati Oku',
    descEn: 'Read the analog clock, pick the time.',
    descTr: 'Analog saati oku, doğru saati seç.',
    icon: Icons.schedule_rounded,
    color: const Color(0xFF7DD3FC),
    builder: () => const ClockReadScreen(),
  ),
];
