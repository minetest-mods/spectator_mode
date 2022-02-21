-- emulating the only part of [beerchat] that this mod uses
-- https://github.com/minetest-beerchat/beerchat/blob/69400d640c5f6972ab3c69b955b012aecba53ad5/common.lua#L56

mineunit:set_modpath("beerchat", "../beerchat")

_G.beerchat = { has_player_muted_player = function(name, other_name)
	local player = minetest.get_player_by_name(name)
	-- check jic method is used incorrectly
	if not player then
		return true
	end

	local key = "beerchat:muted:" .. other_name
	local meta = player:get_meta()
	return "true" == meta:get_string(key)
end }

