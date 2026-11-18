# Owner feedback batch, 18 Nov 2026 (P batch)

Owner's text copied verbatim (typos kept). Standing rule added to CLAUDE.md ("UI text rule: show, don't tell").
Evidence: `production/qa/evidence/2026-11-18-p-batch/`.

> one running theme is that there is lots of superfluous text prompts around the place ... no unnecessary random
> plain text hints about mechanics that are implied/explained through the tutorial/shown elsewhere graphically, e.g we
> don't want filled/empty gem slots denoting picks and then also text saying 3/4 picks selected or whatever, gems or
> something else is good, text is not good. always priorities graphical representations of information over just
> spelling it out in plain boring text, and no duplicated information

## The list (verbatim)

- remove the 'X won game 1 (turn x x - x)' text on the post rewards screen
- also remove the 'you lost last game, so you choose who goes first' text
- Remove the 'bot is ready text'
- Remove right click to inspect text from pile inspector right panel tooltip
- Tribute now also means spirit summon as well as fusion/arcane, so radablast should give infiltrate to an arcane summon
- Reword 'end of its controllers turn' to end of your/your opponents turn dynamically
- Buff/debuff options on heretic of the divine order (anjd any other cards) should be colour coded like the types on chaos witch
- remove the player is drafting x o x text tag thing on the draft page, the right panel is enough, we can add the card count there though
- the draft modal once you're finished drafting and waiting for an opponent should ber thjinner, not so wide
- Remove game x complete from the title, just say rewards
- Start next duel should say ready up instead
- Remove 'Player won game x turn x..." text from the rewards screen
- Match paused after a series is complete thing doesn't need to happen, we should improve the post series handling, you should be allowed to leave gracefully, no opponent reconnecting stuff
- 'Play tutorial' prompt, should just say 'Tutorial'
- sdhare anonymous gameplay statistics tooltip should have a max width
- Remove logged in as player-name from the join game modal
- When you browse lobbies it shows two modals, we don't need the first modal, join game should just show the public lobbies straight away wiothout the intermediary modal
- remove the player-nname chose you to go first text on the post rwards screen
- Rise of the arcane title subtext should be the same width as the legion main title
- The right panel remains as the draft panel once the game starts if you don't select a card, this is a bug
- Chat should be an icon not text button, and we should add an appendix icon
- make the leather backgreounbd texture tileable
- Take picks out of the gem container on the reward screen, move it to a title
- Remove the number to the right of rwards chgosen text on rewards screen
- You shouldn't be able to activate spells during battle phase, even set spells
- on remove a card list, if a card is clicked, the hover should not show the preview, also clicking on a selectred card should unselect it and reeanble hover preview on thenright
- if no card is selected during the game, hovering a card should show it in the preview right pane, if one is selected that one starys there even on hover of another card
- An empty field zone should not have cursor pointer,m and clicking it should also deselect your selectio
- I want new field image options, the green forrest one is great, can we have a few other options, fire, water, and lightning options in a similar style, do this one first so I can pick while you're implementing the rest
- Your deck viewer and and card list should be ordered by cost (but basics fist)
- tooltip on pile viewer should colour code the card stats better (race type cost etc)
- Picking a buff to apply on courages soldier or any other card should allow you to cancel it still if it's not mandatory
- Card list right pane should be wider
- At the bottom of the card list details pane it shows the unit type/summon type in plain text, that should be removed, just use the info at the top is fine

## Progress

| # | Item | Status | Notes |
|---|------|--------|-------|
| P5 | Tribute includes Spirit summons; Radablast | done | Spirit materials (exhausted from Spent) are tributed: their tribute bonus (Radablast's Infiltrate, Magentric's Cleanse, Da Mage's Pierce) reaches the Spirit unit and their "If this Unit is Tributed" effects fire. Radablast already gave Infiltrate to an Arcane summon; now tested. |
| P6 | "end of its controller's turn" | done | Status help reads "your turn" / "your opponent's turn" for the viewer's own / the opponent's cards (card views carry `mine`); spectators and pile lists keep the general wording. |
| P25 | No Spells in the Battle Phase | done | Set Spells can only be activated in the Setup or Recovery Phase too. |
| P32 | Cancel an optional buff pick | done | An optional "1 of any Buff/Debuff" choice offers Skip (Courageous Soldier); ability choices were already cancellable. |
| P1, P12, P18 | Result / chooser lines on the rewards and next-game screens | done | "X won game 1", "you lost last game, so you choose" and "X chose you to go first" are gone (the score and seat plates show it). |
| P3 | "Bot is ready" | done | Removed. An online opponent who is ready gets a green tick on their name plate instead. |
| P4 | Pile inspector tooltip | done | No "Right-click to inspect" line (nor on reward, draft offer or card list cards). |
| P7 | Buff/debuff choices colour coded | done | Status choices use the Type-button grid, tinted in the status colour with its badge (Heretic, Courageous Soldier). |
| P8 | Draft "is drafting" chip | done | Removed; the right pane title keeps the card count. The "Pick N of 12" line beside the pips is gone too. |
| P9 | Draft waiting modal | done | Narrower (560 px). |
| P10, P11 | "Rewards" title, "Ready up" | done | |
| P13 | Paused after the series | done | Once the series is over nobody is paused or reconnected; leaving is free. |
| P14 | "Tutorial" | done | |
| P15 | Statistics tooltip width | done | Wraps at 360 px. |
| P16, P17 | Join game | done | Opens the public lobby list straight away; no intermediate modal or "Logged in as" line. |
| P19 | Subtitle width | done | "RISE OF THE ARCANE" is tracked to the width of LEGION. |
| P20 | Draft panel stuck after the game starts | done | Closes when the game starts. |
| P21 | Chat / Appendix icons | done | Chat is an icon; a new Appendix (book icon) shows the Type cycle and every Buff, Debuff and Rune. |
| P22 | Leather texture | done | The panel leather (`materials/leather.png`) now tiles without seams. |
| P23 | Picks heading | done | "Picks" is a heading over the gems. |
| P24 | Rewards chosen count | done | Removed. |
| P26 | Remove-a-card list | done | Hover previews only with nothing selected; clicking the selected card deselects. |
| P27 | In-match hover preview | done | Hover shows the card while nothing is selected; a selected card stays. |
| P28 | Empty zones | done | Arrow cursor unless the zone answers a choice; clicking one deselects. |
| P29 | Table options | in progress | Second set (distinct landscapes, 2960x2160) awaiting the owner's pick. |
| P30 | Cost order, basics first | done | Card list, deck viewer. |
| P31 | Pile tooltip colours | done | Category, cost, Race and Type chips as in the details pane. |
| P33, P34 | Card list pane | done | Wider (480 px); the plain kind line under the stats is gone. Reward sub-panel notes removed. |
