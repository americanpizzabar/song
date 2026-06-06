# Style-prompt formula (Suno & ACE-Step)

The "Style of Music" prompt (a.k.a. tags / style prompt) is a single
comma-separated string describing the *sound*, not the story. Keep it tight —
roughly 8–15 descriptors, ordered most → least important.

## Formula

```
<genre>, <sub-genre/era>, <mood>, <tempo/BPM>, <key (optional)>,
<lead instruments>, <rhythm/production>, <vocal type>, <mix/texture>
```

### Examples

**City pop:**
```
city pop, 80s Japanese, nostalgic and breezy, 112 BPM, electric piano,
slap bass, clean funk guitar, brass stabs, gated reverb drums, female vocal,
warm analog mix
```

**Emotional EDM:**
```
future bass, euphoric yet melancholic, 150 BPM, supersaw chords,
sidechained pads, heavy 808 sub, vocal chops, big festival drop, bright mix
```

**Lo-fi study beat (instrumental):**
```
lo-fi hip hop, chill jazzy, 78 BPM, dusty Rhodes piano, mellow sub bass,
boom-bap drums, vinyl crackle, instrumental, warm and dusty
```

## Do

- **Lead with the genre.** It anchors everything downstream.
- **Name specific instruments.** "slap bass" > "bass"; "Rhodes" > "keys".
- **State BPM explicitly** when energy matters.
- **Specify the vocal** (or `instrumental`) every time.
- **Add a mood pair** ("euphoric yet melancholic") for emotional depth.

## Don't

- **Don't put lyrics or story in the style prompt.** Lyrics go in the lyrics
  field with section tags.
- **Don't name real artists or songs.** Use the *sound* instead ("80s funk
  pop, smooth male falsetto") — safer and more reliable.
- **Don't overload it.** 25 adjectives muddy the result; pick the load-bearing
  ones.
- **Don't contradict yourself** ("aggressive calm ballad at 180 BPM").

## Mapping to fields

| Our file field | Suno field | ACE-Step param |
| --- | --- | --- |
| `style` (front-matter) | Style of Music | `tags` / `prompt` |
| Lyrics body (tagged) | Lyrics | `lyrics` |
| `title` | Title | (filename) |
| `length` | — (length slider) | `audio_duration` |
