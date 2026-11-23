<!-- The CurseForge project page. Summary (one line):
A glowing countdown icon for every enchant and trinket proc in WoW Forever: Revelation, Insight, Crusader and the Heart of the Mountain trinkets, each placed wherever you want.
-->

# Runeglow

**Never miss a proc again.** Runeglow puts a glowing icon on your screen the moment an enchant or trinket procs, with the time it has left counting down right inside the icon. Drag each icon to wherever your eyes already are: next to your character, under your target frame, beside your action bars.

Made for **World of Warcraft: Forever**.

## Tracked procs

| Buff | Comes from | Effect |
| --- | --- | --- |
| **Revelation** | Enchant Weapon - Revelation | Next non-periodic spell gets +100% crit chance (15 sec) |
| **Insight** | Enchant Weapon - Insight | Spirit +100% for 10 sec |
| **Holy Strength** | Enchant Weapon - Crusader | +100 Strength for 15 sec |
| **Molten Fury** | Molten Heart of the Mountain | +55 attack power, doubled in volcanic areas |
| **Chthonic Power** | Frozen Heart of the Mountain | Up to +29 Frost and Shadow spell damage, doubled in snowy areas |
| **Eternal Power** | Dormant Heart of the Mountain | Up to +40 healing and +13 damage |

Every icon is the buff's own icon from the game. Want something else? `/runeglow add <buff name>` tracks any buff.

## Features

- **One icon per proc**, with a big countdown in the middle. It pulses while the proc is up and vanishes when it ends.
- **Place every icon anywhere.** Turn on *Preview icons*, drag them into place, then lock them.
- **Or keep them together.** Any proc can join a compact row of smaller icons instead.
- **Clean by default.** Just the icon and the countdown; tick *Show proc names* if you want each name above its icon.
- **Stack counts** shown when a buff has them.
- **Scale and sizes** adjustable. Changing the scale keeps every icon exactly where you put it.
- **Works in any client language.** Built-in procs are found by spell ID, not by name.
- **Safe in combat.** If the game hides buff details from addons mid-fight, a showing icon keeps counting down and everything is checked again when combat ends.
- **Lightweight.** No libraries, no combat log, just a few event handlers.

## Setup

Open **Options > AddOns > Runeglow** to choose which procs to track, which get their own icon, sizes and scale, or type `/runeglow`.

## Commands

| Command | What it does |
| --- | --- |
| `/runeglow` | Open the options |
| `/runeglow preview` | Show every icon with a looping timer, for positioning |
| `/runeglow lock` / `unlock` | Stop or allow dragging |
| `/runeglow scale <0.5-2.0>` | Scale every icon and the row |
| `/runeglow reset` | Put every icon back at its default position |
| `/runeglow add <name>` / `remove <name>` | Track another buff, or stop tracking one |
| `/runeglow list` | Show what is being tracked |
| `/runeglow scan` | List the buffs on you by name (handy for `add`) |
| `/runeglow status` | What each tracked buff was last seen as |

`/rglow` works as a shorter alias.

## Good to know

- **Recovery** (Enchant Weapon - Recovery) is an instant heal and leaves no buff, so there is nothing to show. It is listed in the options but off by default.
- Buffs you add yourself are matched by name; use `/runeglow scan` while one is active to get the exact name.

## Feedback

Found a bug or want another proc tracked? Open an issue on [GitHub](https://github.com/SjorsSchijff/Runeglow/issues).
