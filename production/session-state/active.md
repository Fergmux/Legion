# Session checkpoint — Legion build

Read this first after compaction/crash.

- Spec: `rules/` 00–09; latest instruction `rules/09-PRODUCTION-QUALITY-PASS.md`.
- Authority for rules: `design/decision-register-answers.md` (user answers) + C-03/C-04 in `design/decision-register.md`.
- Playtest items: `design/playtest-improvements.md` (I-01..I-03 implemented, evidence recorded).
- Godot root `legion/`; Godot 4.7.2 (upgraded 2026-11-09 from 4.6.1). Exe `~/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe` (this PC: user Fergus; older notes say fergm). Python 3.13 at `~/AppData/Local/Programs/Python/Python313/python.exe`.
- Branch `build/legion-game` (never pushed). Latest: see `git log` (F02 pass after ace0329).
- Settings (project.yaml): rigor full, review full, team studio, qa full, multiplayer true, testing.strict all true.
- Latest work: `design/playtest-feedback-02.md` implemented; checklist `production/stories/playtest-feedback-02.md`; live driver `-- --f02-shots=<dir>`.
- Tests: 392 GdUnit4, all passing (`-a res://tests`, no `-d`). Perf probe: `tests/perf/perf_run.gd` (windowed).
- Evidence: `production/qa/evidence/2026-10-15-ui-v3/` (current), `2026-10-15-export-v3/` (exported build).
- Ledgers: `production/agent-ledger.md` (task/role/model), `production/stories/production-quality-pass.md`, `docs/requirements-checklist.md`.

## Open
- Steam real-environment verification (PQ-11) — needs Steam client running + second account.
- Fatigue default (2 HP/missed draw) awaiting user confirmation of the number.
- F02-13 sound balance awaiting the user's listening test; Plan B zero-target design check.
- Card art from user; optional asset list in `design/art/art-bible.md`.

## 2026-10-16 — Playtest feedback 03 (committed)
All 17 points plus card-kind colours (Trap red, Power light blue, Unit brown, Fusion dark blue, Ritual
purple, Spell green, Arcane grey; one shared back; log names tinted). Checklist:
`production/stories/playtest-feedback-03.md`. Suite 398/398, live driver 66/66 (editor + exported exe).
Open: user's Trap-missing-from-log case (not reproduced); frame-time check, sound balance, two-account
Steam test pending from the user.

## 2026-10-16 — Playtest feedback 04 (committed)
28 points (looks/UX, Fusion prompt bug, new rule: nothing from Hand in Battle, type-first rewards,
basic Race+Type change, coin flip, discard animation). Checklist:
`production/stories/playtest-feedback-04.md`. Suite 405/405, live driver 72/72 (editor + exe).

## 2026-10-18 card art + redesign (d22ad45)
- Card art in `legion/assets/art/cards/<id>.webp` (import: `tools/godot/import_card_art.gd`), status icons `assets/icons/status/`, UI grain `UiSurface` (`assets/art/materials/`). Doc: `design/card-redesign-2026-10-18.md`. Driver: `src/dev/card_redesign_shots.gd`.
- Known pre-existing driver failure (also on HEAD before this work): f04_series_driver "F06 no field hover during the zone choice".

## 2026-10-18 afternoon: owner feedback batch (design/owner-feedback-2026-10-18.md)
- Committed: 0382a76 (net attack mode), 5207296 Wabuku, 820f534 battle-phase extra lock, 7679cc3 Ritual Tribute,
  030c1ff Rune/Arcane cost changes, 767ae68 Host button, 1c9cb58 any-order draft, 84cbc7a extra basic reward,
  58044c0 status hover help, 918b4a8 slimmer stat badges.
- Owner is using the PC: only targeted headless suites run. PENDING when allowed: full suite, card_redesign_shots
  (badge look), f04 series driver (draft tabs, rewards tile, Invite), tutorial/F02/bot drivers, then export
  (check Get-Process Legion* first; never export over a running game).
- 17:40: all pending checks done (full suite 1099/1099; card, series 52/52, tutorial 207, F02 76, bot 4 drivers pass);
  later items 11-16 committed (395f0fc..a224127); both exes rebuilt and verified.

## 2026-10-20 release batch (design/owner-feedback-2026-10-20.md, brief production/release-batch-brief.md)
- Wave 1 merged on build/legion-game: G1 cards (a308eab), A1/A2/F1 chat+spectators (3d84fe9), E/F menus (merge),
  C1/C2 cloud stats + duel clock (rules deployed to rldb-b5593), B3/B4/B6/D13 rules, D8/B5/D6 FX, D-duel UI, TitleText +
  HpVial components. Fixes after merge: 3bed496, 438629c. Suite 1326/1326; drivers series 53/0, tutorial 204/0, F02 77/0,
  bot 4/0, cards 1 hover flake (real cursor over window; fails on control branch too).
- Design review: design/design-review-2026-10-20.md (110 findings, WP-1..WP-10).
- Wave 2: phase A agent (WP-1, WP-4, WP-2 + WP-3 integration) in a worktree; then phase B (WP-5..8 split board/menus),
  then WP-9/10, final review, export (check Get-Process Legion* first).
- yugiohsandbox dev has unpushed commit 59944c6 (game-time charts) -> push to dev at the end.
- Agents stop every 20 turns: resume with SendMessage. Never git stash (shared). Net tests clash on port 24721 when
  suites run in parallel (flake, rerun alone).
- 2026-10-20 late: USAGE LIMIT hit. Merged on build/legion-game: everything up to WP-1/4, WP-2/3 duel, menus part 1.
  Unmerged, in progress (worktrees kept): duel part 2 (.claude/worktrees/agent-afb6105c27ad2c978: WP-6, duel WP-5/7,
  sword tone-down, handed-over #16 #30 #49 #59 #67 #75 #92) and menus part 2 (.claude/worktrees/agent-a65a23da3fde1a236:
  tutorial #97-103, deck select #53-58, OrnatePanel motion, margin re-shoot). Next: finish/commit those, merge, full
  suite + drivers, export (check Get-Process Legion*), push yugiohsandbox dev (59944c6), final owner report.
- 2026-10-21 08:16: RELEASE BATCH DONE. All items merged on build/legion-game (last 7f7ddd8). Suite 1493/1493 exit 0;
  drivers tutorial 208/0, F02 77/0, bot 4/0, cards 0, series 53/0. Exported Legion.exe (playtest) + Legion-dev.exe (dev),
  build/Legion-friends.zip rebuilt. yugiohsandbox dev pushed (59944c6). Owner review list: design/owner-feedback-2026-10-20.md.
- 2026-10-21 16:15: OWNER BATCH 21 OCT (H1-H28) DONE, merged on build/legion-game. Suite 1557/1557 exit 0; tutorial 208/0,
  F02 77/0, bot 4/0, cards 0, series 52/1 (known F06 real-mouse flake). Exported build/windows (playtest) and zip;
  dev copy in build/windows-next-dev (Legion-dev was running). Review list: design/owner-feedback-2026-10-21.md.
- 2026-10-21 17:00: H24-H31 merged too (deck builder, Arcane/Fusion/Ritual sounds, no stance tag, no AP text). Suite 1558/1558
  exit 0; drivers green except the card-shots status hover (env: window now 4K; same on e6d12db). Exported both builds +
  build/Legion-friends.zip. Leftover: build/windows-next{,-dev} (owner deletes; rm denied).

## CHECKPOINT batch 22 Oct (J1-J31)
- Log: design/owner-feedback-2026-10-22.md (commit 7937b22). Six worktree agents launched: Lobby/chat J17-22, Draft J26-30,
  Duel panels J3/4/5/7/8/16, Duel controls J6/11/14/23/25, End-of-game J9/10/12/13/15, Menus J1/2/24.
- After merges: J31 perf review agent, full verify (suite + drivers), version bump 0.3.8, export (check Get-Process Legion*), friends zip.

## CHECKPOINT 21 Oct 00:50 — batch 22 Oct done
- All J1-J31 merged on build/legion-game (HEAD 7393f82, version 0.3.9). Suite 1706/1706 exit 0; drivers pass (series known F06 flake).
- J6 final: Trap Prompts button cycles Usable (eligible, default) / Always / Off.
- Exported 00:44: build/windows/Legion.exe, build/windows-dev/Legion-dev.exe (identical pck), build/Legion-friends.zip.
- Agents' maxTurns raised to 150 in .claude/agents/*.md (untracked).
- Open: pile stacks = next draw-call headroom; status_source.json Paralyse wording (owner sheet).

## Checkpoint 2026-11-03: card sheet "JB Edit"
- Adopted as rules/sources/RLDB Master - Card Database (2026-11-03).csv (commit c6bd26a). The importer handles the new layout; owner rulings are in design/card-database-update-2026-11-03.md.
- Running: agent A (main-deck behaviour + Trap 191), agent B (Extra Deck + Fusions 189/190), and an FX agent finishing K1/K4 in worktree agent-a675488230e878ac8.
- Next: merge A, B and FX; full suite + drivers; K log; version 0.3.10; export; report (also re-ask the Google Sheet A/B question).

## Checkpoint 2026-11-04
- 3 Nov sheet batch done and exported (0.3.10, HEAD a98467f; Basilisk/Seppuku self-material b074dc4, Dragon Rider no stance prompt behind a Dragon a98467f).
- ~50 older tests pin pre-3-Nov values and fail (deferred, owner tests manually). Open: art 189-191, Google Sheet A/B, Snow Tiger log-line hiding.
- Handoff for the next (ElevenLabs MCP) session: production/handoff/legion-context-2026-11-04.md.

## CHECKPOINT 2026-11-05: owner batch L1-L28 (READ FIRST AFTER COMPACTION)
- The owner's full brief is logged verbatim in design/owner-feedback-2026-11-05.md, along with clarifications, a
  progress table, extra improvements and deviations. Work unsupervised to production quality; credits authorised.
- At the end: full verify, version bump, export (Get-Process Legion* first), then the publish-release skill (GitHub).
- 2026-11-05: project on GitHub (PUBLIC) github.com/Fergmux/Legion, default branch build/legion-game; QA evidence stripped from the uploaded history. Release v0.3.10 (Legion-friends.zip + Legion-dev.zip). Skill /publish-release -> tools/publish_github.py (sync | release [--clobber]). Owner authorised pushing to that repo (supersedes "never push" for it).
- Owner is testing match backgrounds: legion/assets/art/background.jpg deleted on disk (uncommitted), candidates background1-4; originals in assets/art/backup (.gdignore).

## CHECKPOINT 2026-11-10: M batch (owner feedback 9 Nov) — READ FIRST AFTER COMPACTION
- New PC (user Fergus). Godot 4.7.2 (project upgraded from 4.6.1; full suite 2243/2243 on 4.7.2). Python 3.13, ffmpeg and uv
  installed via winget (paths: ~/AppData/Local/Microsoft/WinGet/Packages/...). Export templates for 4.7.2 NOT yet installed.
- Brief for agents: production/m-batch-brief.md. Owner's 13 items + 6 sound notes are in this conversation; log them to
  design/owner-feedback-2026-11-09.md before committing.
- Done (uncommitted, in this checkout): M1 menu clicks, M4 series score in menu, M9 plates + icon menu button, M13 round glow
  (agent ae9d); M3 cursor 28px@100%, M10 Options opens empty, M12 table recede/desat, dropdown_select hook (agent ad5b);
  M5 Curse/Cleanse FX order (agent acb5). Evidence: production/qa/evidence/2026-11-09-m-batch/.
- Running: cards agent (M2 draft hover, M6 text_parts in summary_view, M7 deck-builder inspect origin, M8 new-card order).
- Sounds: owner picks mastered into legion/assets/audio/sfx/ (dropdown_select, draft_hover, draft_pick, draft_reveal,
  game_start, defeat, victory, victory_big, card_draw, summon). design/audio/sfx-selection.json + sfx-cues.json updated;
  tools/tests/test_sfx_set.py OK. Brief: design/audio/sfx-owner-notes-2026-11-09.md.
- TODO after cards agent: wire draft_hover in the draft offer (deck_select_view / card_widget hover cue); Chat/Lobby popups
  cover the opponent plate (game_chat.gd / game_spectate.gd); full suite; check d14 inspector test; review screenshots;
  log batch; ask owner to commit; version bump + export need 4.7.2 templates.
- Card backs: owner picks (wyrm 2, grove 1, tide 3, runes 3, stars 1, violet 1) resized to 512x768 WebP in
  legion/assets/art/card_backs/; Violet Sigil is now painted (card_back.gd STYLES). Source: ElevenLabs flow "Legion card backs 9 Nov"
  (GPT Image 2.5, edit of old back + Gilded Sun style ref). Update legion/assets/CREDITS.md + data/credits.json.
- 2026-11-10: M batch complete and released as v0.5.0 (commits 1b48115..HEAD; batch log design/owner-feedback-2026-11-09.md).
  Ritual/Arcane set pieces now use one long cue each (ritual_full / arcane_full) with FxSummon.CLIMAX on the measured
  impact. ElevenLabs credits are exhausted (74 left); image work can use the owner's OpenAI key (Windows user env
  OPENAI_API_KEY, read at run time, never printed) via a gpt-image-2.5-sunburst script.

## 2026-11-10 card database update (CD - JB edit) - in progress
- Plan + owner answers + decisions: `design/card-database-update-2026-11-10.md`. Source pinned: `RLDB Master - Card Database (2026-11-10).csv`.
- Done (uncommitted): importer (Evolution: conditions, ids 196/197, material/typo corrections), evolution = Summon + on-card Evolve
  action (MatchEngine._op_evolve, CardScripts.evolve_abil), new cards 192-197 + behaviour changes in card_scripts, CardDB.DISABLED (44),
  starter decks, new art (owner picks), credits, tests `tests/unit/cards/cards_db_update_2026_11_10_test.gd`, python importer tests,
  evidence `production/qa/evidence/2026-11-10-card-db/` via `-- --carddb1110-shots=<dir>`.
- Next: full suite (log scratchpad suite7.log), fix stale tests, rebuild, commit when told.
