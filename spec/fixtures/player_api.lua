-- emulating the only part of [player_api] that this mod uses

mineunit:set_modpath("player_api", "../player_api")

_G.player_api = { player_attached = {} }

