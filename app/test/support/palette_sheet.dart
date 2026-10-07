import 'package:flutter/material.dart';
import 'package:tutoria/core/design/design.dart';

/// One page showing the whole design system: colours, type, and the components. Rendered to
/// docs/design/palette.png by the golden test, so the palette is something you can look at.
class PaletteSheet extends StatelessWidget {
  const PaletteSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.blue50,
      body: ListView(
        padding: const EdgeInsets.all(TSpace.page),
        children: [
          const Wordmark(size: 34, tagline: true),
          const SizedBox(height: TSpace.xl),
          _section('Brand blue'),
          _swatches(const [
            ('blue800', TColors.blue800),
            ('blue700', TColors.blue700),
            ('blue600 · primary', TColors.blue600),
            ('blue500', TColors.blue500),
            ('blue200', TColors.blue200),
            ('blue100', TColors.blue100),
            ('blue50 · page', TColors.blue50),
          ]),
          _section('Sunshine yellow'),
          _swatches(const [
            ('yellow · CTA', TColors.yellow),
            ('yellowDeep', TColors.yellowDeep),
            ('yellowTint', TColors.yellowTint),
            ('gold · star', TColors.gold),
          ]),
          _section('Text'),
          _swatches(const [
            ('ink · headings', TColors.ink),
            ('body', TColors.body),
            ('muted', TColors.muted),
            ('faint', TColors.faint),
            ('line', TColors.line),
          ]),
          _section('Subjects (accent + tint)'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in const [
                'Mathematics',
                'English Language',
                'Science',
                'Our World and Our People',
                'Social Studies',
                'Computing',
              ])
                Container(
                  width: 170,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: SubjectStyle.of(s).tint,
                    borderRadius: BorderRadius.circular(TRadius.lg),
                  ),
                  child: Row(
                    children: [
                      IconBadge(
                        icon: SubjectStyle.of(s).icon,
                        color: SubjectStyle.of(s).accent,
                        size: 38,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          SubjectStyle.shortName(s),
                          style: TText.smallBold.copyWith(color: TColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          _section('Feedback'),
          _swatches(const [
            ('success', TColors.success),
            ('warning', TColors.warning),
            ('danger', TColors.danger),
            ('dangerTint', TColors.dangerTint),
          ]),
          _section('Type · Nunito'),
          Text('Display 34 / 900', style: TText.display),
          Text('Title 26 / 800', style: TText.title),
          Text('Heading 20 / 800', style: TText.heading),
          Text('Subheading 17 / 700', style: TText.subheading),
          Text(
            'Body 15 / 500: A personal tutor that explains every lesson, step by step.',
            style: TText.body,
          ),
          Text('Small 13 / 500: secondary text and hints', style: TText.small),
          _section('Buttons'),
          TButton(label: 'Primary', onPressed: () {}),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: TColors.heroGradient,
              borderRadius: BorderRadius.circular(TRadius.lg),
            ),
            child: TButton(
              label: 'Call to action',
              style: TButtonStyle.cta,
              onPressed: () {},
            ),
          ),
          const SizedBox(height: 10),
          TButton(
            label: 'Outline',
            style: TButtonStyle.outline,
            onPressed: () {},
          ),
          const SizedBox(height: 10),
          TButton(label: 'Soft', style: TButtonStyle.soft, onPressed: () {}),
          _section('Fields and chips'),
          TTextField(
            controller: TextEditingController(),
            hint: 'Email address',
            icon: Icons.mail_outline_rounded,
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(text: 'Class 5', icon: Icons.school_rounded),
              Pill(
                text: 'Mathematics',
                background: TColors.mathsTint,
                foreground: TColors.mathsAccent,
              ),
              Pill(
                text: 'English',
                background: TColors.englishTint,
                foreground: TColors.englishAccent,
              ),
              Avatar(name: 'Ama Mensah', size: 36),
              NumberBadge(number: 3, color: TColors.scienceAccent, size: 36),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Text(title, style: TText.heading),
  );

  Widget _swatches(List<(String, Color)> swatches) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final (name, color) in swatches)
        SizedBox(
          width: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(TRadius.md),
                  border: Border.all(color: TColors.line),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: TText.caption.copyWith(
                  color: TColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                style: TText.caption,
              ),
            ],
          ),
        ),
    ],
  );
}
