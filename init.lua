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

		local pos = original_pos[watcher]
		if pos then
			-- set_pos seems to be very unreliable
			-- this workaround helps though
			minetest.after(0.1, function()
				watcher:set_pos(pos)
			end)
			original_pos[watcher] = nil
		end
	end
end

minetest.register_chatcommand("watch", {
	params = "<to_name>",
	description = "Watch a given player",
	privs = {watch = true},
	func = function(name, param)
		local watcher = minetest.get_player_by_name(name)
		local target = minetest.get_player_by_name(param)
		local privs = minetest.get_player_privs(name)

		if target and watcher ~= target then
			if player_api.player_attached[name] == true then
				unwatching(param)
			else
				original_pos[watcher] = watcher:get_pos()
			end

			player_api.player_attached[name] = true
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
			minetest.set_player_privs(name, privs)

			return true, "Watching '" .. param .. "' at "..
				minetest.pos_to_string(vector.round(target:get_pos()))
		end

		return false, "Invalid parameter ('" .. param .. "')."
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
