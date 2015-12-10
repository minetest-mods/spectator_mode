local original_pos = {}

minetest.register_privilege("watch", "Player can watch other players")

minetest.register_chatcommand("watch", {
	params = "<to_name>",
	description = "watch a given player",
	privs = {watch=true},
	func = function(name, param)
		local watcher, target = nil, nil
		watcher = minetest.get_player_by_name(name)
		target = minetest.get_player_by_name(param:match("^([^ ]+)$"))
		original_pos[watcher] = watcher:getpos()
		local privs = minetest.get_player_privs(name)

		if target and watcher ~= target and default.player_attached[name] == false then
			default.player_attached[name] = true
			watcher:set_attach(target, "", {x=0, y=5, z=-20}, {x=0, y=0, z=0})
			watcher:set_eye_offset({x=0, y=5, z=-20},{x=0, y=0, z=0})
			watcher:set_nametag_attributes({color = {a=0}})

			watcher:hud_set_flags({
				hotbar = false,
				healthbar = false,
				crosshair = false,
				wielditem = false
			})

			watcher:set_properties({
				visual_size = {x=0, y=0},
				makes_footstep_sound = false,
				collisionbox = {0, 0, 0, 0, 0, 0}
			})

			privs.interact = nil
			minetest.set_player_privs(name, privs)

			return true, "Watching '"..param.."' at "..minetest.pos_to_string(vector.round(target:getpos()))
		end

		return false, "Invalid parameters ('"..param.."') or you're already watching a player."
	end
})

local function unwatching(name)
	local watcher = nil
	watcher = minetest.get_player_by_name(name)
	local privs = minetest.get_player_privs(name)

	if watcher and default.player_attached[name] == true then
		watcher:set_detach()
		default.player_attached[name] = false
		watcher:set_eye_offset({x=0, y=0, z=0},{x=0, y=0, z=0})
		watcher:set_nametag_attributes({color = {a=255, r=255, g=255, b=255}})

		watcher:hud_set_flags({
			hotbar = true,
			healthbar = true,
			crosshair = true,
			wielditem = true
		})

		watcher:set_properties({
			visual_size = {x=1, y=1},
			makes_footstep_sound = true,
			collisionbox = {-0.3, -1, -0.3, 0.3, 1, 0.3}
		})

		if not privs.interact and privs.watch == true then
			privs.interact = true
			minetest.set_player_privs(name, privs)
		end

		if original_pos[watcher] then
			watcher:setpos(original_pos[watcher])
		end

		original_pos[watcher] = {}
	end
end

minetest.register_chatcommand("unwatch", {
	description = "unwatch a player",
	privs = {watch=true},
	func = function(name, param)	
		unwatching(name)
	end
})

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	unwatching(name)
end)

