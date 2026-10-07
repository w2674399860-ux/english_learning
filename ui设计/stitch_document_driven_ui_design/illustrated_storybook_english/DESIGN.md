---
name: Illustrated Storybook English
colors:
  surface: '#fdf9f2'
  surface-dim: '#dddad3'
  surface-bright: '#fdf9f2'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f7f3ec'
  surface-container: '#f1ede6'
  surface-container-high: '#ebe8e1'
  surface-container-highest: '#e6e2db'
  on-surface: '#1c1c18'
  on-surface-variant: '#584045'
  inverse-surface: '#31302c'
  inverse-on-surface: '#f4f0e9'
  outline: '#8c7075'
  outline-variant: '#e0bec3'
  surface-tint: '#b32053'
  primary: '#b32053'
  on-primary: '#ffffff'
  primary-container: '#ff5c8a'
  on-primary-container: '#640028'
  inverse-primary: '#ffb1c0'
  secondary: '#3c6a00'
  on-secondary: '#ffffff'
  secondary-container: '#b8f47a'
  on-secondary-container: '#407100'
  tertiary: '#725c06'
  on-tertiary: '#ffffff'
  tertiary-container: '#c5a951'
  on-tertiary-container: '#4e3e00'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffd9df'
  primary-fixed-dim: '#ffb1c0'
  on-primary-fixed: '#3f0017'
  on-primary-fixed-variant: '#90003d'
  secondary-fixed: '#b8f47a'
  secondary-fixed-dim: '#9dd761'
  on-secondary-fixed: '#0e2000'
  on-secondary-fixed-variant: '#2c5000'
  tertiary-fixed: '#ffe083'
  tertiary-fixed-dim: '#e2c469'
  on-tertiary-fixed: '#231b00'
  on-tertiary-fixed-variant: '#564500'
  background: '#fdf9f2'
  on-background: '#1c1c18'
  surface-variant: '#e6e2db'
typography:
  display-lg:
    fontFamily: Bricolage Grotesque
    fontSize: 38px
    fontWeight: '800'
    lineHeight: 46px
  display-lg-mobile:
    fontFamily: Bricolage Grotesque
    fontSize: 30px
    fontWeight: '800'
    lineHeight: 38px
  headline-lg:
    fontFamily: Bricolage Grotesque
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
  headline-md:
    fontFamily: Bricolage Grotesque
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 30px
  headline-sm:
    fontFamily: Bricolage Grotesque
    fontSize: 18px
    fontWeight: '700'
    lineHeight: 26px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 17px
    fontWeight: '500'
    lineHeight: 26px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 15px
    fontWeight: '500'
    lineHeight: 22px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 18px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '700'
    lineHeight: 22px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '700'
    lineHeight: 18px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '700'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1.25rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

This design system is crafted specifically for early-stage language learners who experience cognitive resistance and apprehension around learning English. Grounded in a tactile, illustrated storybook aesthetic, the design turns an otherwise clinical mobile study tool into a warm, inviting picture-book sanctuary.

### Brand Personality & Emotional Atmosphere
- **Comforting & Low-Stakes:** Removes test-taking anxiety through warm, creamy paper backdrops and hand-hewn organic shapes.
- **Warm & Encouraging:** Visual language evokes an artisanal children's picture book or an illustrated travel journal—celebrating imperfect, hand-drawn warmth over rigid, mechanical precision.
- **Tactile & Playful:** Every element feels printed, cut, or stamped onto heavyweight textured paper, providing immediate sensory feedback.

### Aesthetic Movement: Tactile Storybook Skeuomorphism
The interface pairs gouache-flat color blocking with deliberate, hand-drawn ink contours. Pure digital blacks (#000000) and sterile whites (#FFFFFF) are strictly avoided in favor of deep charcoal-ink contours and creamy sunlit paper surfaces. Dynamic physical states (tactile offset hard-shadows that compress under touch) mimic soft rubber stamps and layered construction-paper cutouts.

## Colors

The palette simulates matte watercolor and gouache washes on absorbent, unbleached cotton paper. Colors retain rich saturation without emitting artificial neon glare.

### Palette Architecture
- **Primary Ink & Line Contour (`#2D2926`):** Deep charcoal ink, substituting raw black. Used for all variable-width strokes, physical drop shadows, icon lines, and high-emphasis body text.
- **Primary Rose Gouache (`#FF5C8A`):** Energetic, cheerful, and approachable. Used for primary call-to-actions, core completion badges, and milestone celebrations.
- **Secondary Meadow Sage (`#7CB342`):** Grounded botanical green signifying steady growth, streak indicators, correct answer feedback, and vocabulary mastery checkpoints. Deep green accent: `#556B2F`.
- **Tertiary Buttercream (`#FFE082`):** Soft luminous cream yellow used for tip cards, coin counters, hints, and active audio soundwave indicators.
- **Canvas Base (`#FAF6EF`):** Unbleached warm cream sketchbook paper. Surface containers and cards utilize pristine milk cream (`#FFFDF9`) to establish soft, paper-layer separation.
- **Error Vermilion (`#E65100`):** Soft baked terra-cotta used for incorrect states, preserving an encouraging, gentle tone rather than an aggressive digital warning.

## Typography

Typography bridges expressive character with high legibility. 

- **Display & Headings:** Set in *Bricolage Grotesque*, delivering quirky, expressive, hand-drawn letterforms with deliberate flare joints that mirror natural calligraphic ink pooling.
- **Body & Functional UI:** Set in *Plus Jakarta Sans* paired with rounded Chinese system sans-serifs (such as PingFang SC with medium/bold round terminals), providing friendly, balanced, and open-countered readability for English vocabulary notes, phonetics, and simplified Chinese explanations.
- **Typographic Rules:** All English word prompts must maintain explicit letter-spacing (0.015em) and increased line height to accommodate International Phonetic Alphabet (IPA) annotations and Pinyin guidance comfortably.

## Layout & Spacing

The layout system is tailored for one-handed mobile touch engagement while preserving the breathing room of an open-format storybook.

### Grid & Canvas Structure
- **Canvas Margins:** Fixed `1.25rem` (20px) outer edge margins ensure comfortable separation from physical mobile bezels.
- **Vertical Rhythm:** Relies on a base 4px/8px rhythm (`space-sm` = 8px, `space-md` = 16px, `space-lg` = 24px).
- **Thumb-Zone Optimization:** Interactive elements, card stacks, and answer trays occupy the bottom 60% of the viewport. Visual scene illustrations and word context paintings settle gracefully into the upper 40%.
- **Safe Area Insets:** Ample bottom margins (dynamic safe-area padding + `space-md`) protect interactive floating action bars and primary navigation trays from gesture navigation conflicts.

## Elevation & Depth

This design system avoids blurry digital ambient dropshadows entirely. Depth is achieved strictly through **tactile paper layering, crisp dark-ink boundary strokes, and solid offset stamp-shadows**.

### Elevation Mechanics
1. **Level 0 (Desk/Sketchbook Canvas):** Colored in textured parchment `#FAF6EF`. Pure flat background.
2. **Level 1 (Paper Cutout Cards):** Elevated with a solid 2px outline of charcoal ink (`#2D2926`) and an un-blurred 3px hard offset shadow (`box-shadow: 3px 3px 0px #2D2926`).
3. **Level 2 (Interactive Floating Action Blocks & Buttons):** Supported by a 2.5px solid stroke and a 4px hard stamp shadow (`box-shadow: 0px 4px 0px #2D2926`).
4. **Pressed State (Tactile Compression):** When tapped, buttons compress directly into their shadow (`transform: translateY(3px); box-shadow: 0px 1px 0px #2D2926`), mirroring the physical resistance of a mechanical stamp or soft rubber button.
5. **Level 3 (Modal Story Sheets):** Sheet containers float over a warm dimmed scrim (`rgba(45, 41, 38, 0.45)`), surrounded by a full 3px charcoal boundary.

## Shapes

Shapes capture an organic, hand-crafted silhouette—soft, human, and intentionally avoiding clinical grid corners.

### Shape Architecture
- **Standard Cards & Surfaces:** Employs playful, pillowy radii (`border-radius: 22px` to `26px`), simulating heavy cardstock cut with rounded shears.
- **Asymmetric Deformations:** Key learning cards can use subtle organic asymmetric border radiuses (e.g., `24px 28px 22px 26px`) to enhance the hand-cut paper feel.
- **Line Consistency:** Outlines must remain uniformly weighted across single components: 2px for minor tags/cards and 2.5px for buttons and critical containers. Stroke corners must use round joins (`stroke-linejoin: round; stroke-linecap: round;`) to eliminate harsh vertex edges.

## Components

### Buttons
- **Primary Action (Touch Target: min-height 56px):** Filled with Primary Rose (`#FF5C8A`), enclosed by a 2.5px `#2D2926` ink stroke, featuring white/cream bold text and a 4px vertical ink shadow (`0px 4px 0px #2D2926`). Radius set to 24px.
- **Secondary Action:** Filled with Warm Paper (`#FFFDF9`) or Buttercream (`#FFE082`), 2px `#2D2926` stroke, dark charcoal text, and a matching hard shadow.
- **Interactive State:** `transform: translateY(3px)` with reduced shadow depth on press.

### Learning & Word Cards
- **Word Presentation Card:** Background `#FFFDF9`, featuring hand-drawn style dashed or solid border accents. Contains illustrated iconography, word, phonetic guide, and simple Chinese meaning. Offset hard shadow of 3px down-right.
- **Selected Word State:** Fills with vibrant Buttercream (`#FFE082`) or Meadow Sage (`#7CB342`) with an animated gentle wiggle effect (rotation between -1° and +1°).

### Vocabulary Chips & Tags
- **Pill Shape:** Radius 16px, min-height 38px, lightweight 1.5px `#2D2926` outline.
- **Resting:** Flat cream background.
- **Active/Selected:** Primary Rose or Meadow Sage fill with a 2px dark offset shadow.

### Form Inputs & Text Fields
- **Container:** Height 56px, background `#FFFDF9`, 2px solid `#2D2926` border, `rounded-xl` (20px).
- **Focus State:** Stroke remains `#2D2926` with a soft buttercream highlight band or a subtle organic wobble line.
- **Placeholder:** Muted warm charcoal (`rgba(45, 41, 38, 0.4)`).

### Choice & Checkbox Selectors
- **Radio & Checkboxes:** Custom hand-drawn appearance. 28px circular or squircle containers with 2.5px stroke. Checked states reveal a thick, playful hand-drawn tick or solid gouache dot fill.

### Audio & Pronunciation Prompts
- **Speech Bubble Container:** Rounded speech balloon featuring an integrated hand-drawn triangle tail pointing toward the illustration mascot. Tap triggers an animated soundwave pulse rendered in Meadow Sage (`#7CB342`).