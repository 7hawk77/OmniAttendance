# Manual Test Checklist

Use a copied WoW installation or a non-live raid before relying on the addon for loot.

## Loading

- Put the repository contents in a folder named `OmniAttendance`.
- Confirm both Gargul 8.0.0 and Omni Attendance are enabled.
- Log in and confirm there are no Lua errors.
- Run `/oa` and verify the window opens.

## Explicit recording

- Join a party or raid and run `/oa start Test Raid`.
- Confirm all current group members appear checked.
- Reload the UI before saving and confirm the draft still exists but no official raid was added.
- Run `/oa cancel` and confirm no attendance was recorded.
- Start again, uncheck one player, manually add another, and save.
- Run `/oa raids` and verify exactly one official raid exists.

## Alts and corrections

- Run `/oa alias Altname Mainname`.
- Add Altname to a new draft and confirm Mainname receives the credit.
- Add a player with `/oa add Altname Mainname` and verify the alias is created.
- Run `/oa edit 1`, change attendance, save, and verify no second raid was created.
- Run `/oa void 1` and verify the raid leaves the rolling calculation but remains in History CSV.
- Run `/oa restore 1` and verify it counts again.

## Rolling window and exports

- Save at least 11 test raids.
- Confirm the default score uses only the latest 10 active raids.
- Run `/oa window 8` and verify scores recalculate without deleting history.
- Verify Summary CSV has one 1/0 column for each raid in the current window.
- Verify History CSV contains every raid, including voided raids.
- Verify Gargul CSV has no header and uses `Main,100+bonus,Alt...`.

## Gargul

- Run `/oa sync`.
- Open Gargul Boosted Rolls and verify points and aliases.
- Confirm Gargul is enabled with default points 100, no reserve threshold, and Increased Both roll mode.
- With raid leader or assistant status, run `/oa broadcast`.
- On a second client with Gargul, accept or trust the sender and verify the same data arrives.
- Test two reserved players and verify a +10 player rolls 11-110 while a +1 player rolls 2-101.

## SavedVariables backup

- Log out normally.
- Confirm `OmniAttendance.lua` exists under the account SavedVariables folder.
- Copy it elsewhere and verify the archived raids are readable Lua data.
