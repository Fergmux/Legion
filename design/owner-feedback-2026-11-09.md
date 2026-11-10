# Owner feedback batch, 9-10 Nov 2026 (M1-M13 + sounds)

Logged so the brief survives a context compact. The owner's text is copied verbatim (typos kept). Agent brief:
`production/m-batch-brief.md`. Evidence: `production/qa/evidence/2026-11-09-m-batch/`.

## Setup changes (this batch)

- New PC. The project moved from Godot 4.6.1 to **Godot 4.7.2** (owner: "Upgrade to 4.7.2"). Before the switch the full
  suite passed 2243/2243 on 4.7.2. `project.godot` features, `project.yaml`, `docs/engine-reference/godot/VERSION.md`,
  README, `tools/export_all.py` and the publish-release skill now name 4.7.2. Export templates 4.7.2 installed.
- Python 3.13, ffmpeg and uv installed (winget, per user).

## The list (verbatim)

1. Can't click on the in game menu when it's open
2. Hovering over a card in the draft does not keep its hover effect
3. The cursor is good but too big
4. The best of three bit I don't like the position of, it hides the opponent's hand and other stuff, it should instead live somewhere else, maybe within the menu
5. When curse is applied to a unit with a buff the animation ordering is wierd, we should show
6. Preview modal should seperate effects light tthe right pane, coloured section for summon/field etc, not just one 'rules' section (spawn has one rules section but larva has them seperated? these should be consistent)
7. When right clicking on a card in the deck build to inspect it, the animation grows to the wrong location, it should grow to the destination location
8. New cards are in the wrong order in the deck, they should be nect to their other card types
9. The player health sections overlap the field, the main players section should be moved down to not overlapt he field zones, the opponents card should be moved up and the menu button should go to the left of it, it doesn't need to say menu on it it can be an icon button
10. When you go to the options menu it should not automatically select settings
11. The card backs are sick, the violet one should be inproved to match the others level of awesome, but keeping the same egenral style/design. Also how did you generate the cards, I really like them but they have alot fo shadow whcih gives them a sort of 3d effect but they are supposed to be kind of flat, I don't mind a bit of texture but not this deep well feeling, the gilded sun one is pefect but the others are a bit too deep visually.
12. The backgrounds are great but a bit distracting, there should be a very faint darkening effect on the image, either an image effect or a big square that is 95% trasnparent or something, just to detract less from the main game elements
13. There's a sort of spotlight effect coming down fromn the top of the screen, I like the idea but not the execution, can we make it a more circular glow focused on the center of the table so it feels like the light is above the table not over to one side of it.

Sound effects:
1. Selecting a dropdown option should have a sound effect
2. Draft hover sound effect new option
3. Draft card selected new draw sound effect new options
4. Start of games horns absolutely awful, new effect for sure
5. Defeat sound effect is god awful
6. Victory sound effect should be way more epic and fun

Follow-ups (verbatim):
- Item 5 answer: "Curse first, then buffs fade"
- "the summon sound effect should have some new options" ... "card draw should be one cars swish type sound that is played
  for each card drawn" ... "the summon sound effect ... should be a soft not super magical type sound" ... (retry) "summon needs
  to be a bit more obvious, with a slight thunk for impact"
- "the select card effect for both draft and card rewards are bad, they should use the same effect"
- "the sections on the right on the game screen, have a margin now? they should go right up to the edge of the screen, don't
  want to see that brown background, they also should have less margin between the sections"

## Progress

| # | Item | Status | Notes |
|---|------|--------|-------|
| M1 | Menu clickable | done | The click-off catcher was a later sibling and took the menu's clicks; now added before the menu. |
| M2 | Draft hover kept | done | The opponent's progress rebuilt the whole modal; it now updates in place, and a card rebuilt under a still pointer comes back hovered. |
| M3 | Smaller cursor | done | Follows OS display scaling only: 28 px at 100%, 42 at 150% (was up to 80 px on a 4K window). |
| M4 | Series score in the menu | done | Top of the in-game menu; a best-of-1 shows no series section. |
| M5 | Curse / Cleanse order | done | Curse lands (badge and sound), then each cleared buff fades one by one, then Curse fades if spent. Same for Cleanse. |
| M6 | Coloured rule sections everywhere | done | `MatchView.summary_view` now carries `text_parts`; every inspect entry point matches. |
| M7 | Deck builder inspect origin | done | The zoom starts from the card clicked and lands on the inspector card's final rect. |
| M8 | New cards ordered by kind | done | Catalogue order: kind first, then sheet order; no-index cards sit at the end of their kind. |
| M9 | Plates clear of the field; icon menu button | done | Checked at 1280x720, 1280x800, 1600x900, 1920x1080, 2560x1440. Chat and Lobby popups also open under their buttons now. |
| M10 | Options opens empty | done | Closing a section stays in Options; Back returns to the main menu. |
| M11 | Flatter painted backs; richer Violet | done | Owner picks: Wyrm 2, Grove 1, Tide 3, Runes 3, Starfield 1, Violet 1 (now painted). GPT Image 2.5 via ElevenLabs (edit of each back with Gilded Sun as the style reference). |
| M12 | Tables recede | done | Match only: +6-10% darkening and 8-14% desaturation per table. |
| M13 | Round table glow | done | Soft radial glow on the field centre, breathing 0.06-0.09. |
| S1 | Dropdown sound | done | `dropdown_select` on any OptionButton choice (owner's take 1). |
| S2 | Draft hover | done | Draft-only `draft_hover` (owner's take 2); other card hovers keep `card_hover`. |
| S3 | Draft pick / deal | done | `draft_reveal` = owner take 4. Draft pick and card rewards share one swish (owner pick C1) in `draft_pick` and `reward_pick`. |
| S4-6 | Game start, defeat, victory, series victory | done | Owner takes 5-8. |
| - | Card draw | done | One airy whisk per card (owner pick B2). |
| - | Summon | done | Whoosh landing in a wooden thunk (owner pick v3 A2). |
| - | Sidebar flush | done | Panels run to the screen edges with a 4 px gap between sections. |
| - | Trap sound | done | `trap_spring` = owner pick A2 (card flip snap, dark whoosh, low boom). |
| - | Opening-deal extra sound | done | The old shuffle cue over the deal is gone; the owner's new shuffle plays first while the hand stays hidden, then the normal card_draw per card. |
| - | Sacrifice | done | Owner pick v2 D1 (black-flame hiss, faint wailing sigh). |
| - | Shuffle | done | Owner pick D1 (wash shuffle); plays at every game start before the deal and when Spent is recycled into Draw (new `shuffle` fx event, presentation only). |
| - | Mute when unfocused | done | Settings > Sound toggle (off by default): the Master bus is silent while the window is unfocused. |
| - | Stats info tooltip | done | The privacy note is now an info icon's tooltip beside the sharing toggle. |
| - | Menu score plaque | done | Compact: only the cartouche, "BEST OF n" over names and dots in the seat colours (gold / blue, owner-approved); gems removed. |
| - | Draft pick drowned out | done | Owner: "the shuffle effect is totally overriding it". The next offer's deal cue started with the pick; the reveal now waits `PICK_SETTLE` (0.5 s) so the card swish is heard first. |
| - | Draft offer cue removed | done | Owner: "If there's already a flip sound just play that for each card and remove this extra sound effect." The new offer plays only each card's `card_flip` (one flip under reduced motion); `draft_reveal` is no longer played. |
| - | Draws one at a time | done | Owner: "the draw cards sound effect seems to play all at once, it should be 4 distinct draw sound effects with a bit of delay between them, same for the animation". Each drawn card (and the opening deal) leaves the deck `GameHandView.DRAW_STEP` (0.22 s, was 0.07) after the last with its own `card_draw`; the opponent's draw ghosts match. One sound under reduced motion. |
| - | View your deck button | done | Rewards footer: a secondary button with the tome glyph, the same size as Finish / Skip (was a text link). |
| - | Violet Sigil v3 | done | Owner pick 2 of the "rich but crisp" set (reference: Gilded Sun, Tide, Starfield). |

All sound takes: ElevenLabs flow "RLDB sound options 9 Nov"; selections in `design/audio/sfx-selection.json`, mastered by
`tools/sfx_master.py` (staging in `production/audio-staging/`, gitignored).

## Decisions taken for the owner (review welcome)

- Cursor base 28 px (owner suggested 32 at 100%); the art fills its square, so 28 already reads a little larger than the Windows arrow.
- Options opens on the menu painting with no crest (matches Play and Decks).
- Table picker thumbnails keep the full art; only the match table recedes.
- Every new status badge joins its card when its stamp lands (not just Curse / Cleanse); reduced-motion status stagger 0.12 -> 0.25 s.
- `CardDB.all()` keeps sheet order (seeded draft / reward pools depend on it); only displayed lists use the new catalogue order.
- Draft picked list keeps pick order.

## Not done / open

- Credits files (`rldb/assets/CREDITS.md`, `rldb/data/credits.json`) should mention the 10 Nov card back regeneration.
- About 11,800 ElevenLabs credits were wasted on a first card-back batch rendered 16:9 by mistake (re-run in 2:3).
