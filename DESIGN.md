---
name: Wand website
description: Existing Wand identity for downloads and installation
colors:
  paper: "#fff"
  ink: "#171719"
  muted: "#66666e"
  line: "#e5e5e8"
  surface: "#f6f6f7"
  accent: "#225c44"
  scroll-thumb: "#aaaab2"
  scroll-track: "#f6f6f7"
  scroll-hover: "#777780"
  focus: "#245dc2"
typography:
  display:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "clamp(42px,4.5vw,62px)"
    fontWeight: 650
    lineHeight: 1.12
    letterSpacing: "-0.04em"
  headline:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "32px"
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "-0.03em"
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
    fontSize: "16px"
    lineHeight: 1.8
  code:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, monospace"
    fontSize: "12px"
    lineHeight: 1.8
rounded:
  control: "8px"
  compact: "5px"
  preview: "12px"
spacing:
  small: "8px"
  medium: "16px"
  gutter: "32px"
  section-gap: "56px"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    rounded: "{rounded.control}"
    padding: "12px 20px"
  command-box:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.control}"
    padding: "8px 8px 8px 16px"
---

# Design System: Wand website

## Overview

**Creative North Star: "Wand, with the cleanliness of Linear and Apple Notes"**

The existing Wand double-cat identity on a white canvas, with restrained system typography and a black primary action. The user’s Linear / Apple Notes references establish cleanliness and brevity; no new visual identity is introduced.

**Key Characteristics:**
- Existing double-cat identity.
- Quiet white surfaces and clear type hierarchy.
- Short copy and visible installation actions.

## Colors

Runtime source of truth: `styles.css :root`; the frontmatter records its actual values. Ink and paper form the primary action. Muted text, surface and line organize secondary content. The restrained green accent belongs to terminal prompts, connection indicators and summary hover. Focus is blue; scroll-thumb, scroll-track and scroll-hover theme browser scrollbars.

## Typography

Display and body share the system stack defined above, grounded in the user’s Apple Notes reference. Monospace is reserved for commands and terminal content. The body role describes installation explanatory text; supporting copy uses 12–14px. The hero lead uses 25px/1.65 on desktop, then 22px and 20px at narrower breakpoints. Illustration-only labels use 9–12px and do not carry essential instructions.

## Layout

The container is 1184px including 32px horizontal padding, giving 1120px content width. Hero and installation use `.88fr 1.12fr` columns with a 56px gap. At 1000px the gap becomes 32px. At 800px sections become a single column, gutters become 24px and the hero centers. At 420px gutters become 20px. Hero vertical padding is 112px on desktop; installation uses 72px above and 88px below. These are observed values, not a newly imposed spacing scale.

## Elevation & Depth

Only the illustrative terminal window is lifted: `0 18px 60px #17171918, 0 2px 8px #1717190d`. Installation command surfaces and section separators remain flat. The shadow frames an illustration; it is not a reusable feature-card treatment.

## Shapes

Controls and command surfaces use the control radius; the terminal preview uses the larger preview radius. Copy-button hover surfaces and selected illustrative sessions use the compact radius. Dividers are thin solid lines. The preview clips its window chrome to its rounded boundary.

## Components

The primary anchor has a 48px minimum height and 204px minimum width, with a 19px authored SVG. Hover darkens to `#37373c`; active links and buttons use opacity `.75`. The background transition is `.16s ease-out`.

Copy buttons have a 44px minimum height, a transparent resting surface, and a surface-line hover fill. Disabled buttons use opacity `.45`. Copy results are announced through a live region with a minimum reserved height; denial selects the exact command for manual copying. At narrow widths the visible copy label is hidden while its accessible name remains.

Navigation is plain text; native details elements expose secondary instructions. The footer contains only the brand and GitHub link. Focusable links, buttons and summaries use a 2px focus outline with 5px offset. Reduced motion disables transitions and smooth scrolling; forced colors preserve explicit outlines and control borders. Commands wrap without horizontal overflow.

The terminal connection preview is explicitly captioned as an illustration. Its compact chrome is not a functional control surface.

## Do's and Don'ts

- Do preserve the existing double-cat mark.
- Do use placement, hierarchy and whitespace to explain the page.
- Do keep release availability and recovery messages truthful.
- Don’t add slogans, secondary badges or decorative marketing copy.
- Don’t present the terminal illustration as a real application screenshot.
- Don’t introduce decorative gradients or repetitive feature cards.
