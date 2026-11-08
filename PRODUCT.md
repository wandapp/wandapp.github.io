# Product
<!-- impeccable:product-schema 1 -->

## Platform
web

## Stack
Delegated implementation choice: buildless static HTML, CSS and ES modules. GitHub Pages is the user's explicit hosting target. No runtime dependencies, telemetry, authentication, or private API calls.

## Users
People using Wand to access terminal work on their own computers. Chinese is the current interface language.

## Product Purpose
The official Wand download and installation entry. Success means visitors can download the macOS app or install everything with the single published curl command.

## Capabilities and Constraints
Internal modules ship independently, while end users choose App download or one automatic installer. There is no Core prerequisite or manual start step. The macOS preview targets macOS 13+ on Apple Silicon. It is not Apple-notarized. Only platforms verified in the manifest may be advertised; Linux availability is pending artifact verification. Download URLs must resolve to public GitHub Release assets before the manifest enables them. No invented platform support, testimonials, performance claims or licensing promises.

## Brand Commitments
Wand and the existing double-cat mark. The user requests the cleanliness of Linear and Apple Notes: short copy, clear layout and restrained typography. No invented marketing slogans or secondary badges.

## Evidence on Hand
Parent repository ARCHITECTURE.md and AGENTS.md; frontend/src/brand-mark.svg; release contract supplied by the parent implementation agent. Installation and distribution artifacts are built and verified by the parent agent.

## Product Principles
A page explains by placement. Downloads are truthful. Installation completes setup and startup; internal release boundaries do not become user chores. The website never handles terminal credentials or user session data.
