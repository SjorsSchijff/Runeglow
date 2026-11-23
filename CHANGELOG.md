# Runeglow

## 1.0.0

First release.

- **One icon per proc**, with the countdown inside it (and, with *Show proc names*, its name above): Revelation and Insight
  (weapon enchants), Molten Fury, Chthonic Power and Eternal Power (the Heart of the Mountain trinkets)
  and Holy Strength (Crusader). Every icon is the buff's own icon from the game. Icons pulse while the
  proc is up and show a stack count when there is one.
- Built-in procs are found by spell ID, so they work in any client language. Recovery is listed but off
  by default: it is an instant heal with no buff to show.
- **A shared row** of smaller icons, with the timer on the icon, for procs you take off their own icon
  and for any buff you add with `/runeglow add <name>`.
- **Options** under *Options > AddOns > Runeglow*: enable, lock, preview, reset positions, which procs to
  track and which get their own icon, icon sizes and scale.
- **Positioning**: drag icons while unlocked; *Preview icons* (or `/runeglow preview`) shows them all with
  a looping countdown. Changing the scale keeps every icon where you put it.
- **Commands**: `/runeglow` (or `/rglow`) with `preview`, `lock`, `unlock`, `scale <0.5-2.0>`, `reset`,
  `add`, `remove`, `list`, `scan`, `status` and `help`.
- `/runeglow scan` lists the buffs on you by name, to find a proc's exact name.
- Buffs the game hides from addons in combat are handled safely: an icon already showing keeps counting
  down, and everything is checked again when combat ends.
