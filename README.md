# Runeglow

**Never miss a proc.** Runeglow puts a glowing icon on your screen the moment an enchant or trinket
procs, with the time it has left counting down right inside the icon. Drag each icon wherever your eyes
already are.

Made for **World of Warcraft: Forever**.

## What it tracks

| Proc | From | What it does |
| --- | --- | --- |
| **Revelation** | Weapon enchant | Your next non-periodic spell gets 100% more crit chance |
| **Insight** | Weapon enchant | +100% Spirit for 10 seconds |
| **Recovery** | Weapon enchant | Heals you for 5% of your health when you are dodged or parried |
| **Molten Heart of the Mountain** | Trinket | +55 attack power, doubled in volcanic areas |
| **Frozen Heart of the Mountain** | Trinket | Up to +29 Frost and Shadow spell damage, doubled in snowy areas |
| **Dormant Heart of the Mountain** | Trinket | Up to +40 healing and +13 damage |
| **Holy Strength** | Crusader | +100 Strength for 15 seconds |

Track any other buff with `/runeglow add <buff name>`.

## Features

- **One icon per proc**: a dark frame with a violet border, the proc's name above it and the countdown
  in the middle. It pulses while the proc is up and disappears when it ends.
- **Put each icon anywhere**: toggle **Preview icons** in Options (or run `/runeglow preview`) to show
  them all at once, drag them into place, then lock them with **Lock positions** or `/runeglow lock`.
- **Or keep them together**: untick "Own icon" for a proc and it joins a compact row of smaller icons,
  along with any buffs you added yourself.
- **Options** under *Options > AddOns > Runeglow*: enable, lock, preview, reset positions, which procs
  to track, icon sizes and scale.

## Commands

| Command | What it does |
| --- | --- |
| `/runeglow` | Open the options |
| `/runeglow preview` | Show every icon with a looping timer, for positioning |
| `/runeglow lock` / `unlock` | Stop or allow dragging |
| `/runeglow scale <0.5-2.0>` | Set the scale of every icon and the row |
| `/runeglow reset` | Put every icon back at its default position |
| `/runeglow add <name>` / `remove <name>` | Track another buff, or stop tracking one |
| `/runeglow list` | The buffs being tracked |
| `/runeglow scan` | List the buffs on you by name |
| `/runeglow status` | What each tracked buff was last read as |

`/rglow` works as a shorter alias.

## Good to know

- **Buffs are matched by their English name.** If a proc never lights up, run `/runeglow scan` while it
  is active, then `/runeglow add` the exact name it shows.
- **In combat the game may hide buffs from addons.** When that happens, an icon that is already showing
  keeps counting down on its last known timer, and everything is checked again when combat ends.
- **Recovery** is an instant heal. If the game gives it no buff, there is nothing to show.

## Releasing

Releases are built by [BigWigsMods/packager](https://github.com/BigWigsMods/packager) in
`.github/workflows/release.yml`. Add the new version to `CHANGELOG.md`, then tag and push:

```bash
git tag v1.0.1
git push origin v1.0.1
```

The tag becomes the version in the TOC. Every tag makes a GitHub release with the zip; it also goes to
CurseForge once `## X-Curse-Project-ID` is set in `Runeglow.toc` and the repository has a `CF_API_KEY`
secret.

## License

MIT, see `LICENSE`.
