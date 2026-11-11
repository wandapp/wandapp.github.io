---
name: Wand website
description: Install-first Wand II page in the existing ink-and-paper identity, light and dark
colors:
  paper: "#fff"
  ink: "#171719"
  ink-2: "#3a3a40"
  muted: "#6b6b73"
  faint: "#74747c"
  line: "#e7e7ea"
  surface: "#f5f5f6"
  stage: "#f1f1f3"
  accent: "#1f6b4b"
  focus: "#245dc2"
  selection: "#d6e4f7"
  cmd-bg: "#161618"
  cmd-ink: "#f2f2f3"
  cmd-muted: "#8d8d96"
  cmd-line: "#2a2a2e"
  copied: "#6fd3a3"
  traffic-red: "#ff5f57"
  traffic-yellow: "#febc2e"
  traffic-green: "#28c840"
  dark-paper: "#111113"
  dark-ink: "#ededef"
  dark-muted: "#9a9aa3"
  dark-faint: "#8a8a93"
  dark-line: "#26262a"
  dark-accent: "#5fc596"
typography:
  display:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"PingFang SC\", \"Segoe UI\", sans-serif"
    fontSize: "clamp(56px, 8vw, 96px)"
    fontWeight: 700
    lineHeight: 1
    letterSpacing: "-0.045em"
  lead:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"PingFang SC\", \"Segoe UI\", sans-serif"
    fontSize: "clamp(18px, 2vw, 21px)"
    lineHeight: 1.6
  headline:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"PingFang SC\", \"Segoe UI\", sans-serif"
    fontSize: "28px"
    fontWeight: 650
    letterSpacing: "-0.03em"
  body:
    fontFamily: "-apple-system, BlinkMacSystemFont, \"PingFang SC\", \"Segoe UI\", sans-serif"
    fontSize: "15px"
    lineHeight: 1.8
  small:
    fontSize: "13px"
  label:
    fontSize: "11px"
  nav:
    fontSize: "14px"
  brand:
    fontSize: "17px"
  code:
    fontFamily: "ui-monospace, \"SF Mono\", SFMono-Regular, Menlo, monospace"
    fontSize: "15px"
rounded:
  compact: "6px"
  row: "7px"
  control: "8px"
  segment: "9px"
  command: "12px"
  window: "14px"
spacing:
  small: "8px"
  medium: "16px"
  gutter: "32px"
  section: "112px"
components:
  command:
    backgroundColor: "{colors.cmd-bg}"
    textColor: "{colors.cmd-ink}"
    rounded: "{rounded.command}"
    padding: "8px 8px 8px 20px"
  channel-switch:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.segment}"
---

# Design System: Wand II website

## Overview

**Creative North Star: "Wand, with the cleanliness of Linear and Apple Notes"**

The page is the install command. The "Wand II" wordmark, whose II is the double-cat mark itself (cap height, on the baseline, a word space after Wand; the same lockup as the apps), and one line of copy, then one row of four highlights (端到端加密 · 终端常驻 · 多台主机 · 原生 Mac App, each a bold term and one short line, divided by hairlines), then a dark command bar with a 正式版 / Beta switch; the dmg download is a quiet secondary link under a hairline. Below, a real screenshot of the web client (light and dark via `<picture>`, captioned 网页端) rests on a light stage band and starts inside the first screen at 1440×900, then a hairline definition list answers the follow-up questions, end-to-end encryption first. Existing double-cat mark, system typography, ink on paper; a full dark scheme follows the system setting.

## Colors

Runtime source of truth: `styles.css :root` (light) and its `prefers-color-scheme: dark` block; the frontmatter records both. Ink and paper carry text; muted is body copy in the guide, faint is metadata and must keep ≥4.5:1. The command bar is always dark (`cmd-*`) in both schemes. Green accent marks prompts, passing output and connection dots only; focus and terminal paths use blue. Traffic-light colors belong to the window illustration only.

## Typography

System stack throughout (the user's Apple Notes reference). Monospace only for commands and terminal content. Display is the wordmark only.

## Layout

Container 1184px with 32px gutters (20px under 640px). The hero is a centered column; the install block is 736px wide so the Beta command fits one line on desktop. The guide is a `1fr 2.2fr` grid on desktop and a single column under 900px; each row is `140px 1fr`. Under 640px the app sidebar and the `$` prompt hide and the copy button keeps only its icon. Command lines break between words only, except under 400px where the URL may break.

## Elevation & Depth

Two lifted objects: the command bar (short dark shadow) and the screenshot (layered soft shadow, 14px radius). Everything else is flat on hairlines.

## Motion

One authored moment: the channel switch thumb slides with an exponential ease-out (0.42s). Reduced motion removes it.

## Components

- Channel switch: a radiogroup of two buttons with a sliding thumb; arrow keys switch. `#beta` in the URL opens on Beta and the switch keeps the hash in sync.
- Command bar: the visible command is rebuilt from `release.js` per channel; copy shows a check for 2.4s and the live status line announces success or selects the text when the clipboard is denied.
- Guide: `dl` rows on hairlines, never cards.

## Do's and Don'ts

- Do preserve the double-cat mark (drawn via CSS mask so it takes the ink of either scheme). It is the II of Wand II everywhere: header, hero and footer; never a separate mark beside or above a typed II.
- Do keep every claim on the page true to what the installers do.
- Don't add slogans, eyebrows, badges or feature cards; the four-item highlight row is the only feature list, text on hairlines.
- Screenshots are real captures (`assets/screen-{light,dark}.webp`, 2560×1440) with no private hosts, paths or session content; no drawn window chrome around them.
