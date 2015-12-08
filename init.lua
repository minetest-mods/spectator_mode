local original_pos = {}

minetest.register_privilege("watch", "Player can watch other players")

minetest.register_chatcommand("watch", {
	params = "<to_name>",
	description = "watch a given player",
	privs = {watch=true},
	func = function(name, param)
		local watcher, watched = nil, nil
		watcher = minetest.get_player_by_name(name)
		watched = param:match("^([^ ]+)$")
		local watched_player_name = minetest.get_player_by_name(watched)
		original_pos[watcher] = watcher:getpos()

		if name ~= watched and watched and watched_player_name and watcher and
				default.player_attached[name] == false then

			default.player_attached[name] = true
			watcher:set_attach(watched_player_name, "", {x=0, y=10, z=-20}, {x=0, y=0, z=0})
			watcher:set_eye_offset({x=0, y=10, z=-20},{x=0, y=0, z=0})
			watcher:set_nametag_attributes({color = {a=0}})

			watcher:hud_set_flags({
				hotbar = false, healthbar = false,
				crosshair = false, wielditem = false
			})

			watcher:set_properties({
				visual_size = {x=0, y=0},
				makes_footstep_sound = false,
				collisionbox = {0, 0, 0, 0, 0, 0}
			})

			return true, "Watching '"..watched.."' at "..minetest.pos_to_string(vector.round(watched_player_name:getpos())).."..."
		end

		return false, "Invalid parameters ('"..param.."') or you're already watching a player."
	end
})

minetest.register_chatcommand("unwatch", {
	description = "unwatch a player",
	privs = {watch=true},
	func = function(name, param)
		local watcher = nil
		watcher = minetest.get_player_by_name(name)

		if watcher and default.player_attached[name] == true then
			watcher:set_detach()
			default.player_attached[name] = false
			watcher:set_eye_offset({x=0, y=0, z=0},{x=0, y=0, z=0})
			watcher:set_nametag_attributes({color = {a=255, r=255, g=255, b=255}})

			watcher:hud_set_flags({
				hotbar = true, healthbar = true,
				crosshair = true, wielditem = true
			})

			watcher:set_properties({
				visual_size = {x=1, y=1},
				makes_footstep_sound = true,
				collisionbox = {-0.3, -1, -0.3, 0.3, 1, 0.3}
			})

			minetest.after(0.1, function()
				watcher:setpos(original_pos[watcher])
			end)

			minetest.after(0.2, function()
				original_pos[watcher] = {}
			end)

		end

		return false, "You're not watching a player currently."
	end
})

