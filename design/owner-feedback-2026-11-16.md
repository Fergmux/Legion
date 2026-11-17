# Owner feedback batch, 16 Nov 2026 (N batch)

Owner's text copied verbatim (typos kept). Evidence: `production/qa/evidence/2026-11-16-n-batch/`.

## The list (verbatim)

- add the view deck button to 'waiting for player pick' screen after a game
- We don't need the 'deck locked in' tags on that waiting screen either
- don't need the (15 cards) suffix
- remove the game 1 first to 4 wins text
- void basilisk, should allow you to summon in the place it is, as it gets destroyed, should probably be destroyed before the summon happens technically
- phase change chime too jarring, give me some softer alterantive to pick from
- view deck panel can't interract with it, close button/right click disabled etc
- remove 'your own cards show their actions too' text
- fusion animation should be a bit slower to match the sound effect
- direct damage sound effect a bit too clunky, give me some more magical alternatives
- remove the tooltip under evolution prompt
- remove the tooltiup at the top of pile viewer
- if trap has no target don't prompt for it
- remove tooltip on pile hover
- magical council does not trigger hot stove, it should proc when a spell is played for cheaper due to the power
- remove a card list should be ordered better, not the order they were added in, but same is in deck builder
- question mark units should show modified stats, i.e when they come to the field and take an atk/def, if they get changed by an effect we should still show them gree/red from the default base it was given
- reinforcements should not affect cards not in hand
- Dante on summon and on field effect should be in sepearet sections in the right pane
- When my opponent plays assassinate, and my energy capture triggers, it does not let me see who is being targeted for assassinate, I should be allowed to see the targetiung arrow of my enemies card for situations like this
- 'Waiting for opponent' text moves around with elipses
- Replace 'no duration' on status effect with 'permanent'
- Remove sneaky Sunday prompt by button
- Instead of 'next turn +1 ap' on delayed gratification text just make total gem slots more
- we should add an option to hide the game log which makes it just a very thin bar that says game log with a button to show it again

## Progress

| # | Item | Status | Notes |
|---|------|--------|-------|
| N5 | Void Basilisk exhausts first | done | Exhausted before the Fusion Summon (a cost, paid with the committing stance), so its zone is offered and the Fusion unit may land there; it is no longer its own material. |
| N6 | Softer phase chime | done | Owner pick: phase A take 1 (soft warm glass chime). Flow "Legion sound options 16 Nov". |
| N9 | Fusion slower | done | `FxSummon.LEN.fusion` 1.7 -> 2.3 s: the climax stays on the charge cue's peak (0.78 s); the resolution lasts as long as the impact cue rings. |
| N10 | Magical direct damage | done | Owner pick: damage D take 4 (crystalline magic impact, arcane surge, warm low boom). |
| N13 | Trap without a target | done | A Trap whose effect is on "all" matching units (Trap Hole of Spikes, ...) is not offered when none match. |
| N15 | Magical Council -> Hot Stove | done | A Power that lowers a card's cost (Magical Council, Saboteurs' Guild, Reinforcements) opens a Power-effect response window when that card is paid for (`GameCore.discount_powers`), so Hot Stove can answer it. Not when the cost was already 0. |
| N18 | Reinforcements in Hand only | done | Its -1 AP applies only to unit cards in its controller's Hand. |
| N1 | View deck on the waiting screens | done | The rewards footer's button (`GameRewardPanels.view_deck_button`) on the deck-locked-in wait and the next-game wait. |
| N2 | No "deck locked in" tags | done | Status chips removed from the deck-locked-in and next-game waiting plates (spectator plates keep theirs). |
| N3 | No "(15 cards)" suffix | done | Deck text and the deck popup heading ("Your deck"). |
| N4 | No "Game 1 · first to 4 wins" | done | Hidden in the in-game menu while the series is played; "X wins the series" still shows at the end. |
| N7 | View deck panel not interactive | open | Not reproduced (hot-seat and bot, every after-game screen: Close and right-click work). Needs the owner's repro: mode, screen, window size. |
| N8 | "Your own cards show their actions too" | done | Removed. |
| N11 | Evolve prompt hint | done | Removed. |
| N12/N14 | Pile viewer hint, pile hover tooltip | done | Both removed. |
| N16 | Remove-a-card order | done | Catalogue order, like the deck builder (`GameRewardPanels.remove_order`). |
| N17 | ?-unit stat colours | done | ATK/DEF badges compare with the base an effect set (base_atk/base_def), else the printed stat. |
| N19 | Dante sections | done | Every "Once per turn:" sentence is its own block; the other sentences stay under their own caption (On Field ...). General fix (`CardDetailsPanel.split_timings`). |
| N20 | Opponent's target arrow in a Trap window | done | While answering an activation, its already-chosen targets get the opponent's red arrow (`MatchView.event_targets`, positions only). |
| N21 | Waiting dots move the text | done | The dots are always laid out and only revealed, so the text stays still. |
| N22 | "No duration" -> "Permanent" | done | Reveal's help text. |
| N23 | Sneaky Snunday note by the phase button | done | Removed. |
| N24 | Delayed Gratification gems | done | Promised AP shows as extra pending gem sockets instead of "next turn +1 AP" text. |
| N25 | Hide the game log | done | Hide/Show button in the log header; hidden it is a thin "Game log" bar; remembered in the UI settings. |
