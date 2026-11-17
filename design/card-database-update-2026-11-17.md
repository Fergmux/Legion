# Card database update, 17 Nov 2026 ("10 Nov Changes" + mechanic renames)

Sources: the owner's `RLDB Master - CD - JB edit (1).csv` and `RLDB Master - 10 Nov Changes (1).csv` (Downloads).
Built into `rules/sources/RLDB Master - Card Database (2026-11-17).csv` (also written back to Downloads as
`RLDB Master - CD - JB edit (updated 17 Nov).csv`) by applying every AFTER / NEW row of the change sheet to the JB
edit, then the renames and the owner's answers below.

## Mechanic renames (owner, 17 Nov)

| Old | New |
|-----|-----|
| Ritual summon / Ritual Unit (Runes, cost `nR`) | **Arcane** summon / Arcane Unit (cost `nA`) |
| Arcane summon / Arcane Unit (Exhaust Spent units, cost `nA`) | **Spirit** summon / Spirit Unit (cost `nS`) |
| Evolution / Evolve | **Transformation** / Transform |

Code follows the new names (category keys `arcane` = Rune summon, `spirit` = Exhaust-Spent summon; `transform_*`).

## Owner answers (17 Nov)

- Transformation chains (transformed forms are transformation-only): Battle Komodo (35) -> Angered Komodo (199) ->
  Bloodlust Komodo (200); The Sweeper (29) -> The Lone Warrior (38); Soul of Crashing Ocean (160) -> The Great
  Leviathan (197); Soul of Burning Revenge (202) -> Zadus The Disavowed (203). Existing: Symbiotes 155 -> 156 -> 157,
  Edwin 16 -> Avatar 14, Solomon 37 -> 181.
- Every Spirit Unit is Exhausted whenever it leaves the Field (and its text says so).
- Notes implemented: Avatar 20/10 with On Summon "Apply 1 Debilitate to a Unit."; Mirrorflesh "Once per turn: you
  can apply 1 Debilitate to a Unit with higher ATK than this Unit."; Strength in Unity +2 per Race; Larva and
  Siphonophore draw once per turn (a button) instead of at the start of the turn; Mimic / Mirrorflesh wording names
  the Base ATK/DEF.
- Presentation notes (grey sword/shield with white numbers, no text on card faces with bigger art, the double hover
  sound / "spray can", dropping the right-hand Card Details pane, the Abysslord / Divine Serpent art swap): the
  owner's answer was skipped, so not done; to be asked again.
- Left for JB ("JB to update"): A Great Heist duration/cost.

## Sheet fixes made while building the master

- Draw Virus (44) row was blanked in the JB edit; restored (it stays disabled in code, `CardDB.DISABLED`).
- Divine Serpent - Tail (196) was missing from the JB edit; restored (the Leviathan transformation needs it).
- Emergency Evade's AFTER row is shifted one column in the change sheet; read as cost 1.
- Spirit Units without the Spirit summon requirement in their condition (the two Souls) got it, as every Spirit has.
- The "inspired" working names and the agreed typo fixes are now in the sheet itself.
- Void Basilisk's new wording ("then Exhaust this Unit and Units used from Spent") keeps the owner's 16 Nov ruling
  that Basilisk is exhausted before the summon (Spent materials are exhausted by the Fusion anyway).

## Implementation notes (decisions taken, review welcome)

- Transformations with a state condition (Komodos: "if this Unit Destroys a Unit"; Sweeper: "has had Eternal applied";
  Soul of Burning Revenge: 16+ Burn) use the on-card Transform button in the Setup/Recovery Phase, like Edwin. The
  "destroyed a unit" / "had Eternal" facts are marks kept for the rest of the game (cleared when it transforms).
- Every Spirit Unit is Exhausted whenever it would go to Spent from the Field (`has_flag_raw(..., "exhaust_on_spent")`).
- Gods as Spirits lost "This Unit Permanently costs +1 AP" (On Destruction), as in the sheet.
- Energy Capture answers a Rune being applied by the opponent (any effect) and an Arcane Summon.
- Man's Best Friend's guard ("you can apply 1 Eternal ... then Exhaust this Unit") is taken automatically (a choice
  cannot be asked in the middle of a destruction), like Mithral Dome.
- Tag Team - S: "Units in this Column" = only the units in its own column can be Fusion materials.
- Card faces leave out a Spirit Unit's summon requirement (the same long sentence on every Spirit); the details
  pane and the inspector show it as "Condition".
- Mirrorflesh's On Summon now reads "This Unit's Base ATK/DEF become the combined ATK/DEF of its Fusion Tributes,
  and its Type becomes theirs." (shorter, so the card can still be read); on the 150 px Extra Deck offer card its
  text ends in an ellipsis, like Akiramari's.
- Tutorial: Lesson 6 (Arcane) uses a Basic Warrior with 2 Runes (Accursed Zealot became Pickpocket); Lesson 7
  (Spirit) summons Neva the Divine Mother (Boom is an Arcane unit now).
- Starter decks: the Gods and Soul of Crashing Ocean moved to the Extra Decks (some now hold 4-5 Extra cards), Tritu
  to Moving Ocean's Main Deck, The Sweeper replaces The Lone Warrior.
- 17 Nov (owner): Enraged Komodo (200) is renamed Bloodlust Komodo.
