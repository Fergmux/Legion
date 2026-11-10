# Sound effects: owner notes, 9 Nov 2026

The owner listened to the L1 ElevenLabs set and flagged six cues. Nothing has been regenerated. This file
explains each cue: what plays it, where its file is, what it should sound like, and prompts to try in
ElevenLabs (Sound Effects, model `eleven_text_to_sound_v2`).

## How to try a take and get it into the game

1. In ElevenLabs Sound Effects, paste a prompt, set **Duration** to the value given (not "auto") and **Prompt
   influence** to the value given. Generate 3-4 takes per prompt.
2. Save the ones you like as `production/audio-staging/<cue>/<anything>.mp3` (this folder is gitignored and is
   not on this PC yet; just create it). For example `production/audio-staging/defeat/mine1.mp3`.
3. Tell me which file is the keeper. I master it to the cue's loudness tier (`tools/sfx_master.py`: trim, fade,
   true-peak -1 dB, loudness target) and replace `rldb/assets/audio/sfx/<cue>.wav`.
   - Mastering needs ffmpeg and uv (numpy/scipy), and neither is installed on this PC yet. I can install them
     when you have takes ready.
4. To listen to the current file, open `rldb/assets/audio/sfx/<cue>.wav` in any player.

General tips for this generator: describe the physical sources (instrument, material, room), give one event and
say "single" or "one", say "no voice, no melody" when you want an effect rather than music, and say "dry" or
"small room" for UI sounds so they don't come back drenched in reverb. Musical stingers come out best when you
name the instruments and the shape ("rises then resolves on a held chord").

## 1. Dropdown option chosen (new)

- **Cue:** none until now. Choosing an item in a dropdown (Settings: window mode, anti-aliasing; main menu: series
  length, deck mode) made no sound.
- **Fix in this batch:** dropdowns now play the existing `select` cue (`rldb/assets/audio/sfx/select.wav`, a
  small wooden tick, 0.10 s) when an option is picked. If you want a sound of its own, I will add a
  `dropdown_select` cue for your take.
- **Target:** UI tier (about -24 LUFS), 0.08-0.25 s, instant attack, one event. It should feel like something
  settling into place, a little softer than a button press.
- **Prompts** (Duration 0.5 s, the shortest the generator allows; I trim it. Prompt influence 0.6):
  - `Single soft click of a small brass latch snapping shut, short and clean, close-mic, dry`
  - `One wooden game token slid into a notch with a soft click, very short, close-mic, dry`
  - `Tiny parchment tab flicked once with a soft papery tick and a faint chime, very short, dry`

## 2. Draft hover (new option wanted)

- **Cue:** `card_hover`, file `rldb/assets/audio/sfx/card_hover.wav` (0.18 s, hover tier -32 LUFS). It is shared
  by every card hover: hand, draft, rewards, catalogue. The draft turns it on in
  `rldb/src/ui/game/deck_select_view.gd` (`cw.hover_sound = true`).
- **Current sound:** a playing card sliding a few centimetres on felt.
- **Target:** quiet, under 0.2 s, played many times in a row, so no pitch, no sparkle tail, nothing tiring. The
  draft offer cards lift and tilt on hover, so a tiny lift or whoosh fits better than a slide.
- **Your choice:** a new take can replace `card_hover` everywhere, or become a draft-only `draft_hover` cue (I wire
  it). Tell me which.
- **Prompts** (Duration 0.5 s, Prompt influence 0.7):
  - `Very soft quick whoosh of a playing card lifted off a table, tiny airy swish, quiet, close-mic, dry`
  - `Single thick card gently tilted and lifted, faint papery flutter, very short and quiet, dry`
  - `Soft breath of air as a card rises, tiny muted swish with no tail, quiet, close-mic`

## 3. Draft card picked, and the next cards dealt (new options wanted)

Two cues play here, in `rldb/src/ui/game/deck_select_view.gd`:
- **`draft_pick`** plays when you click a card to take it. File `rldb/assets/audio/sfx/draft_pick.wav`, 0.70 s,
  ui_major tier -18 LUFS. Current sound: card snapped up with a soft magical chime.
- **`draft_reveal`** plays when the next three cards fan in, and **`card_flip`** plays as each card flips. Files:
  `draft_reveal.wav` (0.62 s, card tier -16) and `card_flip.wav` (shared with every face-down reveal in a match).

**Target for the pick:** decisive and rewarding, 0.3-0.7 s: a card taken into your hand with a small "yours now"
flourish. It must not be louder than `confirm`.

- **Pick prompts** (Duration 0.7 s, Prompt influence 0.55):
  - `Playing card swept off a table into a hand with a crisp paper snap and a short warm magical shimmer`
  - `Card claimed with a quick papery whoosh ending in a soft bright crystal ping, short, fantasy`
  - `Decisive card snap followed by a small glowing rune hum that fades quickly, fantasy, short`

**Target for the deal:** 0.5-1.0 s, three quick soft card lands rolled into one gesture, light, not a whoosh.

- **Deal prompts** (Duration 1.0 s, Prompt influence 0.5):
  - `Three playing cards dealt quickly onto a felt table, soft rapid paper slaps, light and clean, close-mic`
  - `Cards fanned out across a wooden table in one quick sweep with a faint sparkle, short, dry`
  - `Quick deal of three thick cards, papery flicks in fast succession, soft magical glimmer at the end`

## 4. Game start (replace: "absolutely awful")

- **Cue:** `game_start`, file `rldb/assets/audio/sfx/game_start.wav` (3.0 s, stinger tier -12 LUFS). It plays when
  the coin flip lands (`rldb/src/ui/fx/coin_flip.gd`), right before the opening deal.
- **Current sound:** a generated brass horn fanfare over war drums. Generated horns come out thin and
  out-of-tune, so the new prompts avoid horns entirely.
- **Target:** 1.5-3.0 s, "the duel begins": weight and anticipation rather than a melody. It sits just before
  `card_draw` x4, so it should land and get out of the way.
- **Prompts** (Duration 2.5 s, Prompt influence 0.45; music sounds benefit from a lower value):
  - `Two deep cinematic war drum hits and a low metallic sword ring that swells, start of a duel, fantasy, no voice, no horns`
  - `Large bronze gong struck once with a soft mallet, deep shimmering bloom with a magical rune hum rising under it, epic, no voice`
  - `Heavy wooden door slammed in a stone hall followed by a rising magical whoosh and a single taiko hit, dramatic, no voice`
  - `Orchestral string swell rising into one powerful timpani and cymbal hit, short epic cue, no brass, no voice`

## 5. Defeat (replace: "god awful")

- **Cue:** `defeat`, file `rldb/assets/audio/sfx/defeat.wav` (3.0 s, stinger -12 LUFS). It plays on the game-end
  screen when you lose (`rldb/src/ui/fx/fx_game_end.gd`); the tutorial's fail state uses it too.
- **Current sound:** a sad descending horn phrase. Again, generated horns are the problem.
- **Target:** 2-3 s, a soft fall rather than comic or melodramatic: the light going out. It should not punish
  you, because players hear it after every lost game in a series.
- **Prompts** (Duration 3.0 s, Prompt influence 0.45):
  - `Low cello note sliding downward with a soft deep drum and a fading reverb tail, somber, cinematic, no voice, no brass`
  - `Magical flame snuffed out with a low descending whoosh and a dull crystal chime fading into silence, melancholy`
  - `Single deep church bell toll in a stone hall, slow long decay, solemn, no voice`
  - `Dark harp glissando falling downward into a soft low drone that fades, sad fantasy, no voice`

## 6. Victory (make it "way more epic and fun")

Two cues:
- **`victory`** plays when you win a game. File `rldb/assets/audio/sfx/victory.wav`, 2.3 s.
- **`victory_big`** plays when you win the series. File `victory_big.wav`, 4.2 s.

Both are stinger tier (-12 LUFS) and play from `rldb/src/ui/fx/fx_game_end.gd` and the tutorial's last lesson.

**Target:** joyful, big and a little playful, with a clear resolving chord at the end. Strings, choir-like pads,
bells, timpani and cymbals generate far better than brass solos. I can widen the length window to 4 s for
`victory` and 6 s for `victory_big` if a longer take sounds better.

- **`victory` prompts** (Duration 3.0 s, Prompt influence 0.4):
  - `Short joyful orchestral victory cue, fast rising strings and glockenspiel into a big timpani and cymbal hit with a bright resolving chord, fun, fantasy, no voice`
  - `Triumphant fantasy celebration, sparkling chimes cascading upward into a booming drum hit and a warm major chord, playful, no voice`
  - `Epic victory sting, choir-like pad swells with bells and a cymbal crash, ends on a bright held chord, no voice`
- **`victory_big` prompts** (Duration 5.0 s, Prompt influence 0.4):
  - `Grand orchestral fantasy finale, soaring strings and choir-like pads, rolling timpani building to a huge cymbal crash and a glorious held major chord, no voice`
  - `Epic celebration fanfare with bells, timpani and full strings, rising then bursting into a triumphant resolving chord with sparkles, no voice`
  - `Heroic fantasy victory anthem sting, pounding drums and swelling orchestra into a massive final hit with a shimmering magical tail, no voice`
