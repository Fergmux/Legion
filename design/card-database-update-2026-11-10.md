# Card database update, 10 Nov 2026 ("CD - JB edit")

Source: `rules/sources/RLDB Master - Card Database (2026-11-10).csv` (the owner's "RLDB Master - CD - JB edit.csv").
Compared by id against the active sheet `RLDB Master - Card Database (2026-11-03).csv`. Every id of the old sheet is
still present; 4 new ids (192-195) and 2 new rows without an id (Divine Serpent - Tail, The Great Leviathan).

## Owner's brief (verbatim)

> Okay we have a new csv with some balance changes as well as some new cards and changes to existing cards
> please compare against the existing csv and figure out all the differences, some have changed their name so check ids
> some big changes are the new cards: Mithral Dome, A Great Heist, Trap Hole of Suppression, Trap Hole of Spikes,
> Divine Serpent - Tail, The Great Leviathan
> Edwin now has an evolution, evolving into Avatar of the flame spirit which like the symbiote evolutions should be
> removed as a regular card, avatar has an effect change too
> solomon the captain now evolves into solomon the tyranical which is no longer fusion and is instead 3 cost, also
> removed as regular card just evolution
> dante is now a fusion instead of a three cost with some effect changes
> krakishin (id 70) has a new on field effect
> shimmer serum has been reworked too
> also deck virus is in the csv but we want to temporarily remove it from the game, keep the code but show it as
> disabled in the deck builder/existing decks and don't show it in the draft, in the future we might want to disable
> more cards so add an easy way to toggle this in the code (doesn't need to be in game)

## New cards

| id | Card | Kind | Cost | ATK/DEF | Text |
|----|------|------|------|---------|------|
| 192 | Mithral Dome | Power | 1 | | If your Spell, Trap or Power would be Destroyed, you can Destroy this card instead. |
| 193 | A Great Heist | Spell | 2 | | Take Control of an opponent's Power (text sits in the sheet's On Field column) |
| 194 | Trap Hole of Suppression | Trap | 1 | | If your opponent Summons a Unit in this card's Column: apply 1 Debilitate to their Units in this Column. |
| 195 | Trap Hole of Spikes | Trap | 1 | | Same trigger: Destroy their Units with 10 ATK or less in this Column. |
| (196) | Divine Serpent - Tail | Unit, Beast, Water | 1 | 8/6 | Once per turn: you can make your opponent's Units Permanently lose -4 ATK. (Soul's old effect) |
| (197) | The Great Leviathan | Unit, God, ? | 4 | 40/28 | On Summon: Destroy all Spells, Traps and Powers, then apply 1 Eternal and 1 Cleanse to this Unit. On Field: if your opponent Controls a Unit, this Unit can make a second attack. |

## Evolutions (new chains)

- 16 Edwin, Initiatus of The Order evolves into **14 Avatar of the Flame Spirit** ("If this Unit has Burn applied and ATK is more than Base: you can Evolve this Unit"). Avatar becomes evolution-only.
- 37 Solomon, the Captain evolves into **181 Solomon, the Tyrannical** (same condition). Tyrannical becomes a 3-cost Unit (was a Warrior + Fire Fusion), evolution-only.
- 155 Symbiote Spawn -> 156 Larva -> 157 Siphonophore: unchanged chain; the sheet now states it ("Evolution: at the start of your turn: you can Evolve this Unit.").
- 160 Divine Serpent - Soul: "if you control Divine Serpent Head, Body & Tail, you can Evolve this Unit, then Exhaust Head, Body & Tail" (target not named in the sheet).

## Changed cards

Behaviour changes (code):
- 14 Avatar of the Flame Spirit: 18/14; no On Summon; On Field "If you Destroy an opponent's Unit: apply 1 Rune to a Unit."; On Destruction "Apply 10 Burn to the Unit that Destroyed this Unit."
- 18 Corrupted Narzyl: 14 ATK; Runes equal to the destroyed Unit's Cost (was 1).
- 20 Spirit Bomb -> **Spirit, the Virtuous**: 24 -> 20 DEF; +6 per opponent Unit (was +4); On Destruction "apply 1 of any Buff to a Unit" (was 1 Pierce).
- 36 Dante: now a **Fusion** (Warrior Unit + Fire Unit), 28/18; Burn 5 (was 10) and +2 ATK per Burn (was +1).
- 38 The Lone Warrior: On Summon "apply Reveal to a Spell/Trap" (was destroy a card with Reveal); -4 per adjacent (was -6); "Unaffected by Trap Effects" (was "cannot receive Buffs or gain ATK/DEF"); new "Once per turn: you can Destroy a card with Reveal."
- 45 Magic Cylinder -> **Dimensional Redirect**: cost 2 (was 1).
- 46 Mirror Force -> **Sorcerer's Forcefield**: the sheet now says 4 or more cards (already the rule).
- 47 Damage Conversion -> **Dimensional Conversion**: cost 1 in the sheet (already the rule).
- 48 Overextend: "Your opponent's Units Permanently lose -10 ATK." (all of them; was one Unit -20).
- 49 Trap Hole -> **Trap Hole of Ensnarement**: only a Summon in this card's Column; 2 Paralyse to all their Units in this Column (was 3 on the Summoned Unit).
- 50 Wabuku -> **Perfect Dodge**, 51 Rushed Recklessly -> **Defensive Rally**: only an attack on a Unit in this Column.
- 70 Krakeshin: 16/22; new "Once per turn: you can apply 1 Debilitate to a Unit in this Column."
- 86 Get Well Soon: 6 Medic (was 4).
- 87 Shared Fate: any of your cards destroyed by an Effect (was a Unit).
- 92 Preservation Jar: cost 1 (was 2).
- 135 Dragon Rider: 10 ATK; the Dragon gains +10 (was +14).
- 138 No Hubris: "Apply 1 Cleanse to a Unit, then apply 1 Curse to a Unit." (was destroy a Buffed Unit).
- 143 Typhoon Simorgh: 20 ATK; the ATK/DEF switch is your Units only.
- 149 Marked by the Abyss: "Your base AP increases by +1 AP." (was +1 AP at turn start with a card in Exhaust).
- 155/156/157 Symbiotes: no Eternal on Summon any more; Larva costs 1, Siphonophore 2.
- 158 Divine Serpent - Head: 12/4; 159 Body: 2 ATK, Adjacent +8 DEF (was +10); 160 Soul: 16 DEF; the 30-damage combo is gone from all three; Soul's On Field is now "Once per turn: you can add a Water Unit from Draw to Hand, until the end of this turn, that Unit costs -1 AP."
- 179 Tyrant's Lantern: now a **Spell**, cost 1: "Apply 1 Burn to a Unit, until the end of this turn: that Unit gains +4 ATK and is Fire Type."
- 181 Solomon, the Tyrannical: Unit, cost 3, 30/14; sacrifices the Unit it is Protected by (was Protecting; Destroy, was Exhaust); On Destruction take -10 (was -12).
- 182 Shimmer Serum -> **Street Venom**: the Spell itself Permanently costs +1 AP each time it is activated (was the Unit).
- 183 Yamata: 8/0; 8 Eternal and 8 Nimble; 4 Poison (was 6); On Destruction "Your opponent can add a Power from Draw or Spent to Hand, until the end of this turn: that Power costs 0 AP."
- 189 Owlbear Druid: material "Unit with 20 or more ATK or DEF + Physical Unit" (was Beast + Physical).
- 190 Snow Tiger Paladin: both effects are continuous (were checked at turn start).

Stat-only changes: 9 Tag Team - F 10/18, 10 Tag Team - W 18/2, 11 Tag Team - J 14/12, 12 Tag Team - X 20/18, 13 Chaos Witch
16/24, 15 Da Mage 18, 24 Chidori 14, 31 Cosmic Dragon 26, 57 Geolock Colossus 22, 69 Magentric 20, 77 Radablast 20 DEF,
102 Waang 16, 147 Demented Apparition 26 ATK.

Renames only: 24 Chidori Monk -> Chidori, Monk of Speed; 26 Brinekeeper Summoner -> Tag Team - C (also Water -> Physical);
40 Aleister the Invoker -> Aleister the Inventor; 61 Sanctified Blade -> Sanctified Paladin; 68 Seppuku -> Zeph, Monk of
Ancient Wisdom; 82 Fusion Ceremony -> Fusion Configuration.

Wording only ("Destroy ..." -> "You must Destroy ...", "apply ..." -> "You can apply ...", tidy-ups): 9, 10, 11, 25, 26,
32, 43, 54, 56, 60, 62, 63, 65, 66, 73, 79, 94, 98, 99, 145, 147, 150, 154, 161, 164, 171, 173, 175, 188. Behaviour already
matches except where a "can" is new (66 Nyxthral's Eternal becomes optional).

## Disabled cards

- 44 Draw Virus: kept in code and data, but disabled: shown greyed in the deck builder and in saved decks, never drafted,
  offered as a reward or put in a starter deck. A single list in code (`CardDB.DISABLED`) turns any card off or on.

## Importer corrections to revisit

- Drop: 48 Overextend (the sheet now states the new rule), 154 Sneaky Snunday (the sheet now matches), 47 cost (the sheet
  now says 1). Update 135 Dragon Rider to +10 (keeping the lowercase "this Unit" after the colon).
- Keep: 21 "you opponent summons" typo fix (still in the sheet), 146, 147, 170, the "inspired" name fixes for 189/190.

## Starter decks affected

- Avatar (now evolution-only) is in The Small and Mighty, World Dragon's Dimension and Yamata's Fire.
- Solomon, the Tyrannical (now evolution-only) is in Yamata's Fire.
- Divine Serpent's Rising has Head, Body and Soul; the Tail is new.

## Owner answers (10 Nov)

- Evolution is a Summon (all of them, the Symbiotes included): On Summon fires, then the summon-response window.
- An Evolve may happen whenever its condition holds, except when a Summon is impossible (Battle Phase, the opponent's
  turn). Statuses, Runes and stat/cost changes are kept (already the rule).
- Keep the old materials: Bastion Wyrm (93) "Unit with 20 or more ATK or DEF + Physical Unit"; Owlbear Druid (189)
  "Beast Unit + Physical Unit" (the sheet had overwritten Owlbear's with Bastion Wyrm's).
- Draw Virus: a saved deck that holds it plays without it.
- The Great Leviathan is evolution-only (Divine Serpent - Soul evolves into it).
- Starter decks: base forms (Avatar -> Edwin, Solomon, the Tyrannical -> Solomon, the Captain); Divine Serpent's
  Rising adds the Tail.
- Fix obvious typos in the sheet text (spelling, grammar, spacing only).
- New art generated (GPT Image 2.5, references from existing art); owner picks: 192 opt 1, 193 opt 2, 194 opt 3,
  195 opt 3, 196 opt 3, 197 opt 2.

## Decisions taken for the owner (review welcome)

- Ids: Divine Serpent - Tail = 196, The Great Leviathan = 197 (stable from now on).
- Evolve timing: a card whose Evolve text is "At the start of your turn" (Symbiotes) keeps the start-of-turn prompt; a
  card with a state condition (Edwin, Solomon, Soul) gets an on-card **Evolve** button in its controller's Setup or
  Recovery Phase while the condition holds. Free, not once per turn, no activation window (it is a Summon).
- Soul's Evolve exhausts one Head, one Body and one Tail after evolving, before the Leviathan's On Summon.
- A Great Heist: control is permanent (no end-of-turn return); the Power keeps its owner.
- Mithral Dome: the replacement is always taken (the engine cannot ask in the middle of a destruction). It never
  replaces itself.
- Marked by the Abyss: +1 base AP while it is in play; several copies do not stack.
- Spirit, the Virtuous: "1 of any Buff" offers Eternal, Pierce, Cleanse, Medic, Infiltrate or Nimble (Retain only acts
  in Hand, so it is left out).
- Yamata's On Destruction: the opponent chooses (optional) a Power from their own Draw or Spent.
- The Lone Warrior's "Unaffected by Trap Effects": a Trap's effect never selects or reaches it.
- Disabled cards: `CardDB.DISABLED` in `legion/src/core/card_db.gd` (one list; add or remove an id).
