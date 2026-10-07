# Tutoria design system

The app's look comes from one set of **design tokens** in
[`app/lib/core/design/tokens.dart`](../app/lib/core/design/tokens.dart), taken from the approved
screen designs. Screens use token names (`TColors.blue600`, `TText.title`, `TRadius.lg`) and shared
components, never raw hex values or ad-hoc styles, so the whole app can be re-skinned from that
file.

- **Palette and type, rendered:** [`design/palette.png`](design/palette.png)
- **Every screen, rendered from the real code:** [`design/app-screens.png`](design/app-screens.png)
- **Pixel-exact screenshots of each screen:** `app/test/goldens/*.png`

## Colours

Sampled from the mockup board; the logo's gold is kept for the star.

| Token | Hex | Used for |
|---|---|---|
| `blue600` **primary** | `#0561E6` | buttons, headers, links, the student's chat bubbles |
| `blue700` / `blue800` | `#0253D5` / `#0245B0` | hero gradient end, pressed states |
| `blue500` | `#0A7AF5` | bright accents |
| `blue200` / `blue100` | `#B8D8FF` / `#E2F1FE` | borders, the tutor's chat bubble, selected rows |
| `blue50` | `#F3F8FF` | page background |
| `yellow` **call to action** | `#FEE517` | the main button on blue screens ("Get Started") |
| `yellowDeep` / `yellowTint` | `#FFC21A` / `#FEF5D2` | accents, the "I'm a Parent" card |
| `gold` | `#FEBF00` | the logo star |
| `ink` | `#182B95` | headings |
| `body` / `muted` / `faint` | `#2B3A67` / `#6B7AA8` / `#9AA7CC` | text, secondary text, placeholders |
| `line` | `#DCE8F8` | card and field borders |
| `success` / `warning` / `danger` | `#1BB464` / `#FC7B0A` / `#E5484D` | feedback |

**Subjects** each have a solid accent (icon badges, text on a tint) and a pastel tint (the card
behind it). `SubjectStyle.of(name)` returns them, so a subject looks the same everywhere:

| Subject | Accent | Tint |
|---|---|---|
| Mathematics | `#0561E6` | `#DCEBFF` |
| English Language | `#8439E7` | `#E8DEFE` |
| Science | `#1BB464` | `#D2F5DD` |
| Our World and Our People | `#0EA5B7` | `#D3F3F6` |
| Social Studies | `#FC7B0A` | `#FFEAD7` |
| Computing | `#5B5BE8` | `#E3E4FF` |

## Type

**Nunito** (rounded, friendly, as in the mockups), bundled in `app/assets/fonts/` so it works
offline (SIL Open Font Licence, `OFL.txt` alongside). One variable font file; every style sets the
weight axis explicitly.

| Style | Size / weight | Use |
|---|---|---|
| `display` | 34 / 900 | splash headline |
| `title` | 26 / 800 | screen titles |
| `heading` | 20 / 800 | section titles |
| `subheading` | 17 / 700 | card titles |
| `body` / `bodyBold` | 15 / 500, 700 | text |
| `small` / `caption` | 13, 11.5 | secondary text |

## Shape and space

Radii: `md` 14 (fields, buttons), `lg` 20 (cards), `xl` 28 (sheets, nav bar), `pill` for chips and
the yellow CTA. Spacing is a 4-point scale (`TSpace.xs`…`xxl`); screens have 20 px side padding.
Cards use a soft blue-tinted shadow (`TShadows.card`).

## Components

All in `app/lib/core/design/widgets/`, exported by `design.dart`.

| Component | What it is |
|---|---|
| `TButton` | primary (blue), `cta` (yellow), outline, soft; loading state |
| `TTextField`, `TDropdownField` | rounded fields with a leading icon; password eye toggle |
| `TCard`, `OptionCard` | white lifted card; large tinted choice card |
| `IconBadge`, `NumberBadge` | solid circle with a white icon, or a topic's number |
| `Avatar`, `Pill`, `Greeting` | initials circle coloured from the name; small label; "Hi Ama 😊" |
| `HeroBackground`, `WaveClipper`, `SoftBlobs` | blue gradient hero, the wavy header edge, the light screens' corner arcs |
| `StepDots`, `Wordmark`, `TNavBar` | sign-up progress; the logo; bottom navigation |
| `Mascot` | the robot tutor (see below) |

## Placeholders to replace with real artwork

The mockups use illustrated portraits and a mascot. Until that artwork is delivered the app draws
stand-ins in code:

- **Mascot** (`widgets/mascot.dart`): a robot with a graduation cap, painted in code. Replace the
  body of `Mascot` with an `Image.asset` of the illustrator's file; every screen picks it up.
- **Splash hero** (`features/onboarding/welcome_screen.dart`, `_HeroArt`): the mascot on a glowing
  disc stands in for the girl's photograph.
- **Parent / Student cards** (`user_type_screen.dart`, `_RoleArt`): icons stand in for the two
  portraits.
- **Logo mark** (`assets/images/logo_mark.png`): cut from the supplied logo onto a transparent
  background; the wordmark beside it is live text in Nunito. Send an SVG or transparent PNG of the
  full logo if a pixel-perfect version is wanted.

## Screens, and what is not built yet

Built (all use real data): welcome, choose user type, create account, child details, choose subjects,
sign in, parent home, student home, subject topics, tutor chat (text and homework photo), profile.

Left out on purpose, because the feature behind them does not exist yet (the mockups show them, but
filling them with made-up numbers would mislead): the streak / XP / badges panel, practice
questions, progress and achievements, the parent dashboard's weekly stats, notifications (all
Milestone 3), and subscription plans (Milestone 4, with Mobile Money).

## Keeping the look stable

`app/test/screens_golden_test.dart` renders each screen to a PNG and fails if a later change alters
one. After a deliberate design change, refresh them with `flutter test --update-goldens` and look at
the diff. `app/test/flows_test.dart` drives sign-up, onboarding, sign-in and log-out through the real
screens.
