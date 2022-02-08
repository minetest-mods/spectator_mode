local original_pos = {}

minetest.register_privilege("watch", {
	description = "Player can watch other players",
	give_to_singleplayer = false,
	give_to_admin = true,
})

local function toggle_hud_flags(player, bool)
	local flags = player:hud_get_flags()
	local new_hud_flags = {}

	for flag in pairs(flags) do
		new_hud_flags[flag] = bool
	end

	player:hud_set_flags(new_hud_flags)
end

local function unwatching(name)
	local watcher = minetest.get_player_by_name(name)
	local privs = minetest.get_player_privs(name)

	if watcher and default.player_attached[name] == true then
		watcher:set_detach()
		player_api.player_attached[name] = false
		watcher:set_eye_offset(vector.new(), vector.new())
		watcher:set_nametag_attributes({color = {a = 255, r = 255, g = 255, b = 255}})

		toggle_hud_flags(watcher, true)

		watcher:set_properties({
			visual_size = {x = 1, y = 1},
			makes_footstep_sound = true,
			collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3}
		})

		if not privs.interact and privs.watch == true then
			privs.interact = true
			minetest.set_player_privs(name, privs)
		end

		local pos = original_pos[name]
		if pos then
			-- set_pos seems to be very unreliable
			-- this workaround helps though
			minetest.after(0.1, function()
				watcher:set_pos(pos)
			end)
			original_pos[name] = nil
		end
	end
end

minetest.register_chatcommand("watch", {
	params = "<to_name>",
	description = "Watch a given player",
	privs = {watch = true},
	func = function(name_watcher, name_target)
		if name_watcher == name_target then return true, "You may not watch yourself" end

		local target = minetest.get_player_by_name(name_target)

		if not target then return true, "Invalid target name" end

		-- avoid infinite loops
		if original_pos[name_target] then return true, name_target .. " is already watching some player." end

		local watcher = minetest.get_player_by_name(name_watcher)
		local privs_watcher = minetest.get_player_privs(name_watcher)

		if player_api.player_attached[name_watcher] == true then
			unwatching(name_watcher)
		end
		original_pos[name_watcher] = watcher:get_pos()

		player_api.player_attached[name_watcher] = true
		watcher:set_attach(target, "", vector.new(0, -5, -20), vector.new())
		watcher:set_eye_offset(vector.new(0, -5, -20), vector.new())
		watcher:set_nametag_attributes({color = {a = 0}})

		toggle_hud_flags(watcher, true)

		watcher:set_properties({
			visual_size = {x = 0, y = 0},
			makes_footstep_sound = false,
			collisionbox = {0}
		})

		privs.interact = nil
		minetest.set_player_privs(name_watcher, privs)

		return true, 'Watching "' .. name_target .. '" at '
			.. minetest.pos_to_string(vector.round(target:get_pos()))

	end
})

minetest.register_chatcommand("unwatch", {
	description = "Unwatch a player",
	privs = {watch=true},
	func = function(name, param)
		unwatching(name)
	end
})

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	unwatching(name)
end)
