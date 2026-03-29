import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme, ThemeData, ColorScheme;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'examples/accidentals_example.dart';
import 'examples/articulations_example.dart';
import 'examples/beaming_showcase.dart';
import 'examples/chords_example.dart';
import 'examples/clefs_example.dart';
import 'examples/complete_music_piece.dart';
import 'examples/dots_and_ledgers_example.dart';
import 'examples/dynamics_example.dart';
import 'examples/grace_notes_example.dart';
import 'examples/key_signatures_example.dart';
import 'examples/lyrics_text_example.dart';
import 'examples/multi_staff_example.dart';
import 'examples/octave_marks_example.dart';
import 'examples/ornaments_example.dart';
import 'examples/polyphony_example.dart';
import 'examples/professional_json_example.dart';
import 'examples/repeats_example.dart';
import 'examples/rhythmic_figures_example.dart';
import 'examples/slurs_ties_example.dart';
import 'examples/tempo_agogics_example.dart';
import 'examples/tuplets_example.dart';
import 'examples/volta_brackets_example.dart';
import 'showcase_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MusicNotationApp());
}

class MusicNotationApp extends StatelessWidget {
  const MusicNotationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Notemus Showcase',
      scrollBehavior: _AppScrollBehavior(),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en'),
        Locale('pt', 'BR'),
      ],
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFF0F766E),
        scaffoldBackgroundColor: Color(0xFFF7F1E8),
        barBackgroundColor: Color(0xFFF7F1E8),
        textTheme: CupertinoTextThemeData(
          navTitleTextStyle: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          navLargeTitleTextStyle: TextStyle(
            color: Color(0xFF111827),
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
          textStyle: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 16,
          ),
        ),
      ),
      builder: _materialBridge,
      home: _BootstrapGate(),
    );
  }

  static Widget _materialBridge(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F1E8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
          surface: const Color(0xFFF7F1E8),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate();

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  late Future<void> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = ensureShowcaseAssetsLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapLoadingView();
        }

        if (snapshot.hasError) {
          return _BootstrapErrorView(
            error: snapshot.error,
            onRetry: _retryBootstrap,
          );
        }

        return const MainScreen();
      },
    );
  }

  void _retryBootstrap() {
    setState(() {
      invalidateShowcaseAssetsCache();
      _bootstrapFuture = ensureShowcaseAssetsLoaded();
    });
  }
}

class _BootstrapLoadingView extends StatelessWidget {
  const _BootstrapLoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF7F1E8)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(radius: 16),
            const SizedBox(height: 18),
            Text(
              'Preparing the 2.5.1 showcase...',
              style: theme.textTheme.navTitleTextStyle.copyWith(
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading engraving assets and notation metadata.',
              style: theme.textTheme.textStyle.copyWith(
                color: const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootstrapErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _BootstrapErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF7F1E8)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF7),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x1F0F172A)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The example gallery could not finish loading.',
                  style: theme.textTheme.navTitleTextStyle.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The app stayed responsive, but one of the required notation assets failed during startup.',
                  style: theme.textTheme.textStyle.copyWith(
                    color: const Color(0xFF4B5563),
                    height: 1.4,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8E8E0),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '$error',
                      style: theme.textTheme.textStyle.copyWith(
                        color: const Color(0xFF7C2D12),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                CupertinoButton.filled(
                  onPressed: onRetry,
                  child: const Text('Retry loading'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final List<_ExampleEntry> _entries = [
    _ExampleEntry(
      category: 'Fundamentals',
      title: 'Clefs',
      subtitle: 'Treble, bass, alto, tenor, percussion, and tablature.',
      icon: CupertinoIcons.music_note,
      accentColor: const Color(0xFFB45309),
      builder: () => const ClefsExample(),
    ),
    _ExampleEntry(
      category: 'Fundamentals',
      title: 'Key Signatures',
      subtitle: 'Sharps, flats, and modal signature layouts.',
      icon: CupertinoIcons.plusminus,
      accentColor: const Color(0xFF7C3AED),
      builder: () => const KeySignaturesExample(),
    ),
    _ExampleEntry(
      category: 'Fundamentals',
      title: 'Rhythmic Figures',
      subtitle: 'Core durations and readability across note values.',
      icon: CupertinoIcons.clock,
      accentColor: const Color(0xFF0369A1),
      builder: () => const RhythmicFiguresExample(),
    ),
    _ExampleEntry(
      category: 'Fundamentals',
      title: 'Dots and Ledger Lines',
      subtitle: 'Augmentation dots and staff extensions.',
      icon: CupertinoIcons.ellipsis_circle,
      accentColor: const Color(0xFF4F46E5),
      builder: () => const DotsAndLedgersExample(),
    ),
    _ExampleEntry(
      category: 'Fundamentals',
      title: 'Accidentals',
      subtitle: 'Chromatic signs with optical spacing.',
      icon: CupertinoIcons.add_circled_solid,
      accentColor: const Color(0xFF0F766E),
      builder: () => const AccidentalsExample(),
    ),
    _ExampleEntry(
      category: 'Fundamentals',
      title: 'Chords',
      subtitle: 'Clusters, intervals, stems, and notehead offsets.',
      icon: CupertinoIcons.square_grid_2x2,
      accentColor: const Color(0xFF9333EA),
      builder: () => const ChordsExample(),
    ),
    _ExampleEntry(
      category: 'Fundamentals',
      title: 'Beaming',
      subtitle: 'Grouped beams and slope handling.',
      icon: CupertinoIcons.link_circle,
      accentColor: const Color(0xFF2563EB),
      builder: () => const BeamingShowcase(),
    ),
    _ExampleEntry(
      category: 'Fundamentals',
      title: 'Tuplets',
      subtitle: 'Clear bracket clearance, ratios, rests, and beam groupings.',
      icon: CupertinoIcons.number_circle,
      accentColor: const Color(0xFFB45309),
      builder: () => const TupletsExample(),
    ),
    _ExampleEntry(
      category: 'Expression',
      title: 'Articulations',
      subtitle: 'Accent families, tenuto, staccato, and stem-aware placement.',
      icon: CupertinoIcons.star_fill,
      accentColor: const Color(0xFF0EA5E9),
      builder: () => const ArticulationsExample(),
    ),
    _ExampleEntry(
      category: 'Expression',
      title: 'Ornaments',
      subtitle: 'Trills, mordents, arpeggios, fermatas, and jazz effects.',
      icon: CupertinoIcons.music_note_2,
      accentColor: const Color(0xFF16A34A),
      builder: () => const OrnamentsExample(),
    ),
    _ExampleEntry(
      category: 'Expression',
      title: 'Grace Notes',
      subtitle: 'Compact grace slurs, accidentals, and chord resolutions.',
      icon: CupertinoIcons.music_note,
      accentColor: const Color(0xFF0F766E),
      builder: () => const GraceNotesExample(),
    ),
    _ExampleEntry(
      category: 'Expression',
      title: 'Slurs and Ties',
      subtitle: 'Head-to-head phrasing and chord ties in the 2.5.1 pass.',
      icon: CupertinoIcons.link,
      accentColor: const Color(0xFF0F4C81),
      builder: () => const SlursTiesExample(),
    ),
    _ExampleEntry(
      category: 'Expression',
      title: 'Dynamics',
      subtitle: 'Dynamic marks and expressive contrast.',
      icon: CupertinoIcons.speaker_3,
      accentColor: const Color(0xFFC2410C),
      builder: () => const DynamicsExample(),
    ),
    _ExampleEntry(
      category: 'Expression',
      title: 'Tempo and Agogics',
      subtitle: 'Tempo text, breath marks, and agogic signs.',
      icon: CupertinoIcons.speedometer,
      accentColor: const Color(0xFFF97316),
      builder: () => const TempoAgogicsExample(),
    ),
    _ExampleEntry(
      category: 'Expression',
      title: 'Lyrics and Text',
      subtitle: 'Syllabification, verses, tempo text, and expressive marks.',
      icon: CupertinoIcons.text_quote,
      accentColor: const Color(0xFF2563EB),
      builder: () => const LyricsTextExample(),
    ),
    _ExampleEntry(
      category: 'Expression',
      title: 'Repeats',
      subtitle: 'Repeat signs, navigation symbols, and form cues.',
      icon: CupertinoIcons.repeat,
      accentColor: const Color(0xFFB91C1C),
      builder: () => const RepeatsExample(),
    ),
    _ExampleEntry(
      category: 'Advanced',
      title: 'Polyphony',
      subtitle: 'Two-voice notation and independent stem directions.',
      icon: CupertinoIcons.square_stack_3d_up,
      accentColor: const Color(0xFF0D9488),
      builder: () => const PolyphonyExampleWidget(),
    ),
    _ExampleEntry(
      category: 'Advanced',
      title: 'Multi-Staff',
      subtitle: 'Grand staff layouts and aligned systems.',
      icon: CupertinoIcons.rectangle_stack,
      accentColor: const Color(0xFF7C2D12),
      builder: () => const MultiStaffDemoApp(),
    ),
    _ExampleEntry(
      category: 'Advanced',
      title: 'Octave Marks',
      subtitle: 'Ottava lines with improved contrast and bracket visibility.',
      icon: CupertinoIcons.arrow_up_arrow_down,
      accentColor: const Color(0xFF4338CA),
      builder: () => const OctaveMarksExample(),
    ),
    _ExampleEntry(
      category: 'Advanced',
      title: 'Volta Brackets',
      subtitle: 'Alternate endings and navigation spans.',
      icon: CupertinoIcons.return_icon,
      accentColor: const Color(0xFFBE185D),
      builder: () => const VoltaBracketsExample(),
    ),
    _ExampleEntry(
      category: 'Advanced',
      title: 'Complete Piece',
      subtitle: 'A polished end-to-end engraving walkthrough.',
      icon: CupertinoIcons.music_albums,
      accentColor: const Color(0xFF0F766E),
      builder: () => const CompleteMusicPieceExample(),
    ),
    _ExampleEntry(
      category: 'Advanced',
      title: 'JSON Import',
      subtitle: 'Professional JSON-driven score rendering.',
      icon: CupertinoIcons.doc_text,
      accentColor: const Color(0xFF1D4ED8),
      builder: () => const ProfessionalJsonExample(),
    ),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentEntry = _entries[_selectedIndex];
    final isWide = MediaQuery.sizeOf(context).width >= 1120;
    final page = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(
        key: ValueKey(currentEntry.title),
        child: currentEntry.builder(),
      ),
    );

    if (isWide) {
      return DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF7F1E8)),
        child: Row(
          children: [
            SizedBox(
              width: 360,
              child: _CatalogSidebar(
                entries: _entries,
                selectedIndex: _selectedIndex,
                onSelect: _selectIndex,
              ),
            ),
            Expanded(child: page),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF7F1E8)),
      child: Stack(
        children: [
          Positioned.fill(child: page),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _showCatalogSheet,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xF7FFFDFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x1F0F172A)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x140F172A),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      CupertinoIcons.sidebar_left,
                      color: Color(0xFF111827),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCatalogSheet() {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return Container(
          height: MediaQuery.sizeOf(context).height * 0.82,
          decoration: const BoxDecoration(
            color: Color(0xFFF7F1E8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: _CatalogSidebar(
              entries: _entries,
              selectedIndex: _selectedIndex,
              onSelect: (index) {
                Navigator.of(context).pop();
                _selectIndex(index);
              },
            ),
          ),
        );
      },
    );
  }

  void _selectIndex(int index) {
    if (index == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = index);
  }
}

class _CatalogSidebar extends StatefulWidget {
  final List<_ExampleEntry> entries;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _CatalogSidebar({
    required this.entries,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  State<_CatalogSidebar> createState() => _CatalogSidebarState();
}

class _CatalogSidebarState extends State<_CatalogSidebar> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupedEntries = <String, List<MapEntry<int, _ExampleEntry>>>{};
    for (int index = 0; index < widget.entries.length; index++) {
      groupedEntries.putIfAbsent(widget.entries[index].category, () => []).add(
            MapEntry(index, widget.entries[index]),
          );
    }

    final textTheme = CupertinoTheme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF8F3EA),
            Color(0xFFF0E8DB),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: CupertinoScrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          thickness: 7,
          radius: const Radius.circular(999),
          child: ListView(
            controller: _scrollController,
            primary: false,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              _CatalogHeader(totalExamples: widget.entries.length),
              const SizedBox(height: 20),
              for (final category in groupedEntries.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Text(
                    category.key,
                    style: textTheme.tabLabelTextStyle.copyWith(
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                for (final entry in category.value)
                  _CatalogTile(
                    entry: entry.value,
                    selected: entry.key == widget.selectedIndex,
                    onTap: () => widget.onSelect(entry.key),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  final int totalExamples;

  const _CatalogHeader({required this.totalExamples});

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F766E),
            Color(0xFF0F4C81),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F4C81),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Release 2.5.1',
              style: textTheme.tabLabelTextStyle.copyWith(
                color: const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Curated Showcase',
            style: textTheme.navLargeTitleTextStyle.copyWith(
              color: const Color(0xFFFFFFFF),
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A cleaner catalog that keeps the useful public examples, trims only redundant demos, and highlights the refreshed 2.5.1 work.',
            style: textTheme.textStyle.copyWith(
              color: const Color(0xF2FFFFFF),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(label: '$totalExamples focused demos'),
              const _HeaderChip(label: 'Cupertino shell'),
              const _HeaderChip(label: 'White score canvas'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;

  const _HeaderChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x33FFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: textTheme.tabLabelTextStyle.copyWith(
          color: const Color(0xFFFFFFFF),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  final _ExampleEntry entry;
  final bool selected;
  final VoidCallback onTap;

  const _CatalogTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? entry.accentColor.withValues(alpha: 0.45)
        : const Color(0x120F172A);
    final backgroundColor = selected
        ? entry.accentColor.withValues(alpha: 0.10)
        : const Color(0xEFFFFFFC);
    final textTheme = CupertinoTheme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.all(14),
        borderRadius: BorderRadius.circular(20),
        alignment: Alignment.centerLeft,
        onPressed: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: entry.accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(entry.icon, color: entry.accentColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: textTheme.navTitleTextStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.subtitle,
                    style: textTheme.textStyle.copyWith(
                      fontSize: 14,
                      color: const Color(0xFF4B5563),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExampleEntry {
  final String category;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget Function() builder;

  const _ExampleEntry({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.builder,
  });
}

class _AppScrollBehavior extends CupertinoScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.unknown,
      };
}
