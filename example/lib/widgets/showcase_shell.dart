import 'package:flutter/cupertino.dart';
import 'package:flutter_notemus/flutter_notemus.dart';

class ExampleShowcasePage extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<Widget> children;

  const ExampleShowcasePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.children,
  });

  @override
  State<ExampleShowcasePage> createState() => _ExampleShowcasePageState();
}

class _ExampleShowcasePageState extends State<ExampleShowcasePage> {
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
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFF8F3EA),
            Color(0xFFF4EEE4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: CupertinoScrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          thickness: 7,
          radius: const Radius.circular(999),
          child: SingleChildScrollView(
            controller: _scrollController,
            primary: false,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShowcaseHeader(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  accentColor: widget.accentColor,
                ),
                const SizedBox(height: 24),
                ...widget.children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExampleSectionCard extends StatelessWidget {
  final String title;
  final String description;
  final Color accentColor;
  final Widget child;

  const ExampleSectionCard({
    super.key,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.18),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: textTheme.navTitleTextStyle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: textTheme.textStyle.copyWith(
                fontSize: 15,
                color: const Color(0xFF4B5563),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class ScorePreviewFrame extends StatelessWidget {
  final Staff staff;
  final Color accentColor;
  final double minHeight;
  final double staffSpace;
  final MusicScoreTheme? theme;

  const ScorePreviewFrame({
    super.key,
    required this.staff,
    required this.accentColor,
    this.minHeight = 200,
    this.staffSpace = 16,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7DDE5)),
        color: const Color(0xFFFFFFFF),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        child: MusicScore(
          staff: staff,
          staffSpace: staffSpace,
          theme: theme ??
              MusicScoreTheme(
                staffLineColor: const Color(0xFF1F2937),
                noteheadColor: const Color(0xFF111827),
                stemColor: const Color(0xFF111827),
                clefColor: const Color(0xFF111827),
                barlineColor: const Color(0xFF111827),
                accidentalColor: const Color(0xFF111827),
                dynamicColor: const Color(0xFF111827),
                ornamentColor: accentColor,
                tupletColor: const Color(0xFF111827),
                octaveColor: const Color(0xFF111827),
                slurColor: const Color(0xFF111827),
                tieColor: const Color(0xFF111827),
                textColor: const Color(0xFF334155),
                textStyle: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 15,
                ),
                lyricTextStyle: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 15,
                ),
                tupletTextStyle: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                octaveTextStyle: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                ),
                tempoTextStyle: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          enableResponsiveLayout: false,
          preventVerticalOverflow: false,
        ),
      ),
    );
  }
}

class ShowcaseInfoBanner extends StatelessWidget {
  final String title;
  final String description;
  final Color accentColor;

  const ShowcaseInfoBanner({
    super.key,
    required this.title,
    required this.description,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              CupertinoIcons.info_circle_fill,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.navTitleTextStyle.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: textTheme.textStyle.copyWith(
                    fontSize: 15,
                    color: const Color(0xFF334155),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;

  const _ShowcaseHeader({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.92),
            accentColor.withValues(alpha: 0.20),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Flutter Notemus 2.5.1',
              style: textTheme.tabLabelTextStyle.copyWith(
                color: const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: textTheme.navLargeTitleTextStyle.copyWith(
              color: const Color(0xFFFFFFFF),
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: textTheme.textStyle.copyWith(
              color: const Color(0xF2FFFFFF),
              fontSize: 16,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
