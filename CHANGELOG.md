# Changelog

## 0.1.3 - 2026-10-14

- Fixed Gargul synchronization for WoW Forever character names containing spaces.
- Added a native Gargul 8.0.1 data bridge because its CSV parser treats spaces as column separators.
- Preserved capitalization for both parts of Forever character names.
- Preserved the CSV integration path for clients whose character names do not contain spaces.

## 0.1.2 - 2026-10-14

- Fixed stretched draft-roster checkmarks by keeping the checkbox at its native size.
- Improved roster readability for long Forever names and hid duplicate main-name aliases.
- Added alternating roster-row backgrounds and more space below manual-entry hints.
- Added an automatic GitHub Release workflow that publishes an install-ready addon ZIP.

## 0.1.1 - 2026-10-14

- Added native WoW Forever interface `16001` metadata and a Camelot TOC.
- Revalidated the integration against Gargul 8.0.1's shipped Forever build.
- Added `/oa status` diagnostics for the client, Gargul, database, and integration APIs.
- Made Gargul synchronization fail safely when required integration APIs are unavailable.
- Added mocked core behavior tests and included them in automated validation.
- Updated the packaged ZIP and in-game checklist for Forever and Gargul 8.0.1.

## 0.1.0 - 2026-09-14

- Added explicit officer-controlled raid drafts.
- Added current-group roster capture with manual attendance corrections.
- Added main/alt alias support with retroactive history consolidation.
- Added permanent raid archive with reversible voiding.
- Added configurable rolling raid window, defaulting to 10 raids.
- Added attendance summary and full-history CSV exports.
- Added Gargul-compatible Boosted Rolls export.
- Added direct Gargul 8.0.0 synchronization and separate manual broadcast.
- Added an in-game roster review and export interface.

