# OmniAttendance

OmniAttendance is a World of Warcraft Classic raid-attendance ledger built for Omni's rolling Soft Reserve system.

It records only officer-confirmed raid events, keeps the complete history permanently, calculates a configurable rolling attendance bonus, and sends `100 + attendance` points to Gargul's Boosted Rolls system.

## Core rules

- A raid is recorded only after `/oa start` followed by `/oa save`.
- Starting a raid captures the current group as a draft; the roster can be corrected before saving.
- Attendance is credited to the player's main, including attendance earned while playing an aliased alt.
- The default bonus is the number of attended raids among the latest 10 non-voided official raids.
- Old raids remain archived and can be used again by changing the rolling-window size.
- Gargul integration happens only when an officer explicitly uses **Sync Gargul** or `/oa sync`.
- Other players do not need OmniAttendance. Gargul can broadcast the resulting Boosted Rolls data.

## Commands

| Command | Purpose |
| --- | --- |
| `/oa` | Open or close the window |
| `/oa start [raid name]` | Create a draft from the current group |
| `/oa add Character [Main]` | Add or credit a player in the current draft |
| `/oa remove Character` | Remove a player from the current draft |
| `/oa save` | Save the reviewed draft as an official raid |
| `/oa cancel` | Discard the current draft |
| `/oa raids` | Print recent raid IDs |
| `/oa edit <raid ID>` | Load a saved raid for correction |
| `/oa void <raid ID>` | Exclude a raid without deleting its archive |
| `/oa restore <raid ID>` | Restore a voided raid |
| `/oa alias <Alt> <Main>` | Credit an alt to a main |
| `/oa unalias <Alt>` | Remove an alias |
| `/oa window <number>` | Change the rolling raid count |
| `/oa export summary` | Show attendance summary CSV |
| `/oa export history` | Show full archived history CSV |
| `/oa export gargul` | Show Gargul import data |
| `/oa sync` | Replace Gargul Boosted Rolls with current attendance points |
| `/oa broadcast` | Broadcast Gargul's current Boosted Rolls data |

`/omniattendance` is also accepted.

## Installation

1. Download the repository ZIP from GitHub.
2. Rename the extracted folder to `OmniAttendance`.
3. Place it in `World of Warcraft/_classic_era_/Interface/AddOns/`.
4. Enable **Omni Attendance** on the character-selection AddOns screen.
5. Install and enable Gargul for direct Boosted Rolls synchronization.

## Data and backups

Data is stored account-wide in `OmniAttendanceDB`. World of Warcraft writes SavedVariables when you log out or reload the UI. Back up the corresponding file in your account's `WTF/Account/.../SavedVariables` directory if desired.

## Status

Initial development version. In-game testing is required before relying on it for a live loot decision.
