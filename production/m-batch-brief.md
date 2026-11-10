# M batch brief (owner feedback 9 Nov 2026): shared by every agent

You are one of three agents working **in the same checkout at the same time**
(`C:\Users\Fergus\Documents\code\RLDB`, branch `build/rldb-game`). There is no worktree.

## Hard rules
- **Touch only the files in your ownership list.** If you need a change in someone else's file, stop and say so
  in your report; do not edit it.
- **Do not commit, do not stage, never `git stash`, never `git checkout`/`git restore` a file.** The lead commits.
- No keyboard-shortcut hints anywhere in the UI (no "Esc", keycaps, hotkey labels). The shortcuts keep working.
- Doc comments (`##`) on public functions; static typing; gameplay values as constants or data, not magic numbers
  scattered in code.
- Sounds and visuals must never reveal hidden information.

## Engine and commands
- Godot **4.7.2** (the project was just upgraded from 4.6.1). Console exe:
  `/c/Users/Fergus/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe` (call it `$G`).
- The Godot project root is `rldb/`, not the repo root. Code: `rldb/src/`, tests: `rldb/tests/`.
- Targeted tests only (the full suite is the lead's job), run from `rldb/` without `-d`:
  `$G --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/<path> --ignoreHeadlessMode -c`
  Check the exit code. Net tests use ENet port 24721 and clash when run in parallel; avoid them.
- Python 3.13: `/c/Users/Fergus/AppData/Local/Programs/Python/Python313/python.exe`.
- Screenshot drivers live in `rldb/src/dev/` (e.g. `--shots=<dir>`, `--f02-shots=<dir>`, `--deckbuilder-shots=<dir>`,
  `--bot-shots=<dir>`; read the driver to see the flag). Run windowed: `$G --path . -- --<flag>=<dir>`.
  You may add a small driver of your own under `rldb/src/dev/` (that file is yours).
- Evidence: each player-visible change needs a retained screenshot in
  `production/qa/evidence/2026-11-09-m-batch/` (JPG quality 88, at most 1600 px wide; never PNG). Name files
  `m<item>-<what>.jpg`. Check the screenshot yourself (Read the image) before claiming it is right.
- Automated runs must use TEST paths for user files (DeckStore, PlayerStats); never touch the owner's saved decks.

## Report back (your final message)
Per item: what was wrong, what you changed (files and functions), how you verified it (test names, screenshot
paths), and anything you could not do or decided on the owner's behalf.
