local original_state = {}

minetest.register_privilege("watch", {
	description = "Player can watch other players",
	give_to_singleplayer = false,
	give_to_admin = true,
})

local function turn_off_hud_flags(player)
	local flags = player:hud_get_flags()
	local new_hud_flags = {}

	for flag in pairs(flags) do
		new_hud_flags[flag] = false
	end

	player:hud_set_flags(new_hud_flags)
end

local function detach(name)
	-- nothing to do
	if not player_api.player_attached[name] then return end

	local watcher = minetest.get_player_by_name(name)
	if not watcher then return end -- shouldn't ever happen

	watcher:set_detach()
	player_api.player_attached[name] = false
	watcher:set_eye_offset(vector.new(), vector.new())

	local saved_state = original_state[name]
	-- nothing else to do
	if not saved_state then return end

	watcher:set_nametag_attributes({ color = saved_state.nametag.color, bgcolor = saved_state.nametag.bgcolor })
	watcher:hud_set_flags(saved_state.hud_flags)
	watcher:set_properties({
		visual_size = saved_state.visual_size,
		makes_footstep_sound = true,
		collisionbox = saved_state.collisionbox,
	})

	local privs = minetest.get_player_privs(name)
	if not privs.interact and privs.watch then
		privs.interact = true
		minetest.set_player_privs(name, privs)
	end

	local pos = saved_state.pos
	if pos then
		-- set_pos seems to be very unreliable
		-- this workaround helps though
		minetest.after(0.1, function() watcher:set_pos(pos) end)
	end
	original_state[name] = nil
end

minetest.register_chatcommand("watch", {
	params = "<to_name>",
	description = "Watch a given player",
	privs = {watch = true},
	func = function(name_watcher, name_target)
		if name_watcher == name_target then return true, "You may not watch yourself." end

		local target = minetest.get_player_by_name(name_target)

		if not target then return true, 'Invalid target name "' .. name_target .. '"' end

		-- avoid infinite loops
		if original_state[name_target] then return true, '"' .. name_target .. '" is watching "'
			.. original_state[name_target].target .. '". You may not watch a watcher.' end

		local watcher = minetest.get_player_by_name(name_watcher)
		if player_api.player_attached[name_watcher] == true then
			detach(name_watcher)
		end

		-- back up some attributes
		local properties = watcher:get_properties()
		original_state[name_watcher] = {
			collisionbox = table.copy(properties.collisionbox),
			hud_flags = table.copy(watcher:hud_get_flags()),
			nametag = table.copy(watcher:get_nametag_attributes()),
			pos = vector.new(watcher:get_pos()),
			target = name_target,
			visual_size = table.copy(properties.visual_size),
		}

		-- set some attributes
		turn_off_hud_flags(watcher)
		watcher:set_properties({
			visual_size = { x = 0, y = 0 },
			makes_footstep_sound = false,
			collisionbox = { 0 },
		})
		watcher:set_nametag_attributes({ color = { a = 0 }, bgcolor = { a = 0 } })
		watcher:set_eye_offset(vector.new(0, -5, -20), vector.new())
		-- make sure watcher can't interact
		local privs_watcher = minetest.get_player_privs(name_watcher)
		privs_watcher.interact = nil
		minetest.set_player_privs(name_watcher, privs_watcher)
		-- and attach
		player_api.player_attached[name_watcher] = true
		watcher:set_attach(target, "", vector.new(0, -5, -20), vector.new())

		return true, 'Watching "' .. name_target .. '" at '
			.. minetest.pos_to_string(vector.round(target:get_pos()))

	end
})

minetest.register_chatcommand("unwatch", {
	description = "Unwatch a player",
	privs = {watch=true},
	--luacheck: no unused args
	func = function(name, param)
		detach(name)
	end
})

minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	detach(name)
end)
