# Spectator Mode
[![luacheck](https://github.com/minetest-mods/spectator_mode/workflows/luacheck/badge.svg)](https://github.com/minetest-mods/spectator_mode/actions)
[![mineunit](https://github.com/minetest-mods/spectator_mode/workflows/mineunit/badge.svg)](https://github.com/minetest-mods/spectator_mode/actions)
[![License](https://img.shields.io/badge/License-MIT%20and%20CC--BY--SA--3.0-green.svg)](LICENSE)
[![Minetest](https://img.shields.io/badge/Minetest-5.0+-blue.svg)](https://www.minetest.net)

A mod for Minetest allowing you to watch other players in their 3rd person view.
You're invisible and undetectable for the players when you're in this mode.

Can be useful for admins or moderators in their task of monitoring.
Requires the privilege `watch`.

Normal players can also invite others to observe them.

## Dependencies

- `player_api` (included in [`minetest_game`](https://github.com/minetest/minetest_game))
- `default` (included in [`minetest_game`](https://github.com/minetest/minetest_game))

## Requirements

This mod requires MT 5.0.0 and above.

## Commands

All the commands can be modified in settings, here they are listed with their default names.<br>

`/watch <player name>` silently attach to player<br>
`/unwatch` (get back to your initial position)<br>
`/watchme <player name>[,<player2 name] ... playerN name]]` invite player(s) to observe caller.<br>
`/smn` reject an invitation<br>
`/smy` accept an invitation<br>

## Settings

All settings can be set in minetest.conf or accessed via mod with the global field of same name.

- **spectator_mode.command_accept** (smy)<br>
 After an invite has successfully been sent, the watcher may accept it with this command.
- **spectator_mode.command_deny** (smn)<br>
 After an invite has successfully been sent, the watcher may decline it with this command.
- **spectator_mode.command_detach** (unwatch)<br>
To stop observing another player, issue this command.
- **spectator_mode.extra_observe_privs** ()<br>
Additional privs granted to observers. e.g. noclip,never_hungry
- **spectator_mode.extra_observe_privs_moderator** (<spectator_mode.extra_observe_privs>)<br>
Additional privs granted to observers that used '/watch' command. e.g. jail,kick,teleport<br>
If left empty, will use spectator_mode.extra_observe_privs
- **spectator_mode.command_invite** (watchme)<br>
To invite another player to observe player that issued this command.
- **spectator_mode.command_attach** (watch)<br>
To start observing another player, issue this command.
- **spectator_mode.invitation_timeout** (60)<br>
Invitations invalidate after this many seconds if they haven't been accepted or denied.
- *spectator_mode.keep_all_observers_alive*** (false)<br>
Not only moderators are kept oxygenated, but all observers when this is set to true.<br>
For auto-feeding the spectator_mode.keep_alive() function needs to be overriden by another mod.
- **spectator_mode.priv_invite** (interact)<br>
The priv needed to send observation invites.
- **spectator_mode.priv_watch** (watch)<br>
The priv needed to silently observe any player that isn't currently watching another one.

## Privelages

Both privelages are registered if no other mod has already done so.

## Compatibility

Before sending invites, beerchat's player meta entry is checked to make sure muted players can't invite.<br>
Other mods can override `spectator_mode.is_permited_to_invite(name_target, name_watcher)` to add own
conditions of when who can invite whom.

Moderators are kept breathing when observing via '/watch' command. Other mods can override this to
add more functionality: `spectator_mode.keep_alive(name_watcher)`.

`spectator_mode.on_respawnplayer(watcher)` can be overriden to adjust what happens when an attached player
dies and respawns. Without change, the observer is detached for a split second then re-atached.

While attaching a player, his hud flags are mostly turned off. Other mods can override the behaviour
with their own implementation of<br>
`function spectator_mode.turn_off_hud_hook(player, flags, new_hud_flags)`
- **player** The PlayerObjectRef of player that is to be attached.
- **flags** The player's HUD-flags prior to attaching.
- **new_hud_flags** The table that can be manipulated and will be set as new flags.

## Copyright

Original mod DWTFYW Copyright (C) 2015 Jean-Patrick Guerrero <jeanpatrick.guerrero@gmail.com>
Since 20220217 MIT and CC-BY-SA-3.0[see LICENSE](LICENSE)
The MIT applies to all code in this project that is not otherwise protected. [see LICENSE](LICENSE)
The CC-BY-SA-3.0 license applies to textures and any other content in this project which is not source code.

