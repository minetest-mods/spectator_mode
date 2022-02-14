-- NOTE: in the output texts, the names are always in double quotes because some players have
--	names that can be confusing without the quotes.
-- IDEA: technically it would be possible to chain observe. Would have to climb the parent tree
--	making sure there is nothing circular happening. Including checking all the children.
--	A lot can go wrong with that, so it has been left out for now.
--	Another complication to this is that there are many combinations of client<->server
--	software versions to consider.
-- IDEA: might be nice to have a /send_home (<player>|all) command for invitie to detach
--	invited guests again.
--	Currently player can force detachment by logging off.
spectator_mode = {
	version = 20220214,
	command_accept = minetest.settings:get('spectator_mode.command_accept') or 'smy',
	command_deny = minetest.settings:get('spectator_mode.command_deny') or 'smn',
	command_detach = minetest.settings:get('spectator_mode.command_detach') or 'unwatch',
	command_invite = minetest.settings:get('spectator_mode.command_invite') or 'watchme',
	command_attach = minetest.settings:get('spectator_mode.command_attach') or 'watch',
	invitation_timeout = tonumber(minetest.settings:get(
		'spectator_mode.invitation_timeout') or 1 * 60),

	keep_all_observers_alive = minetest.settings:get_bool(
		'spectator_mode.keep_all_observers_alive', false),

	priv_invite = minetest.settings:get('spectator_mode.priv_invite') or 'interact',
	priv_watch = minetest.settings:get('spectator_mode.priv_watch') or 'watch',
}
local sm = spectator_mode
do
	local temp = minetest.settings:get('spectator_mode.extra_observe_privs') or ''
	sm.extra_observe_privs, sm.extra_observe_privs_moderator = {}, nil
	for _, priv in ipairs(temp:split(',')) do
		sm.extra_observe_privs[priv] = true
	end
	temp = minetest.settings:get('spectator_mode.extra_observe_privs_moderator')
	if (not temp) or ('' == temp) then
		sm.extra_observe_privs_moderator = sm.extra_observe_privs
	else
		sm.extra_observe_privs_moderator = {}
		for _, priv in ipairs(temp:split(',')) do
			sm.extra_observe_privs_moderator[priv] = true
		end
	end
end
-- pull some global references to local space
local after = minetest.after
local chat = minetest.chat_send_player
local core_log = minetest.log
local deserialize = minetest.deserialize
local serialize = minetest.serialize
local get_player_privs = minetest.get_player_privs
local set_player_privs = minetest.set_player_privs
local get_player_by_name = minetest.get_player_by_name
local vector_new = vector.new
local vector_round = vector.round

-- cache of saved states indexed by player name
-- original_state['watcher'] = state
local original_state = {}
-- hash-table of pending invites
-- invites['invited_player'] = 'inviting_player'
local invites = {}
-- hash-table for accepted invites.
-- Used to determine whether watched gets notifiction when watcher detaches
-- invited['invited_player'] = 'inviting_player'
local invited = {}


-- register privs after all mods have loaded as user may want to reuse other privs
minetest.register_on_mods_loaded(function()
	if not minetest.registered_privileges[sm.priv_watch] then
		minetest.register_privilege(sm.priv_watch, {
			description = 'Player can watch other players.',
			give_to_singleplayer = false,
			give_to_admin = true,
		})
	end

	if not minetest.registered_privileges[sm.priv_invite] then
		minetest.register_privilege(sm.priv_invite, {
			description = 'Player can invite other players to watch them.',
			give_to_singleplayer = false,
			give_to_admin = true,
		})
	end
end)


-- TODO: consider making this public
local function original_state_get(player)
	if not player or not player:is_player() then return end

	-- check cache
	local state = original_state[player:get_player_name()]
	if state then return state end

	-- fallback to player's meta
	return deserialize(player:get_meta():get_string('spectator_mode:state'))
end -- original_state_get


local function original_state_set(player, state)
	if not player or not player:is_player() then return end

	-- save to cache
	original_state[player:get_player_name()] = state

	-- backup to player's meta
	player:get_meta():set_string('spectator_mode:state', serialize(state))
end -- original_state_set


local function original_state_delete(player)
	if not player or not player:is_player() then return end
	-- remove from cache
	original_state[player:get_player_name()] = nil
	-- remove backup
	player:get_meta():set_string('spectator_mode:state', '')
end -- original_state_delete


-- keep moderators alive when they used '/watch' command
-- overridable as servers may want to change this
function spectator_mode.keep_alive(name_watcher)
	local watcher = get_player_by_name(name_watcher)
	if not watcher then return end -- logged off

	-- still attached?
	if not original_state[name_watcher] then return end

	-- has enough air? (avoid showing bubbles when not needed)
	if 8 > watcher:get_breath() then
		watcher:set_breath(9)
	end
	after(5, sm.keep_alive, name_watcher)
end -- keep_alive


-- can be overriden to manipulate new_hud_flags
-- flags are the current hud_flags of player
-- luacheck: no unused args
function spectator_mode.turn_off_hud_hook(player, flags, new_hud_flags)
	new_hud_flags.breathbar = flags.breathbar
	new_hud_flags.healthbar = flags.healthbar
end -- turn_off_hud_hook
-- luacheck: unused args


-- this doesn't hide /postool hud, hunger bar and similar
local function turn_off_hud_flags(player)
	local flags = player:hud_get_flags()
	local new_hud_flags = {}
	for flag in pairs(flags) do
		new_hud_flags[flag] = false
	end
	sm.turn_off_hud_hook(player, flags, new_hud_flags)
	player:hud_set_flags(new_hud_flags)
end -- turn_off_hud_flags


-- called by the detach command '/unwatch'
-- called on logout if player is attached at that time
-- called before attaching to another player
local function detach(name_watcher)
	-- nothing to do
	if not player_api.player_attached[name_watcher] then return end

	local watcher = get_player_by_name(name_watcher)
	if not watcher then return end -- shouldn't ever happen

	watcher:set_detach()
	player_api.player_attached[name_watcher] = false
	watcher:set_eye_offset()

	local state = original_state_get(watcher)
	-- nothing else to do
	if not state then return end

	-- NOTE: older versions of MT/MC may not have this
	watcher:set_nametag_attributes({
		color = state.nametag.color,
		bgcolor = state.nametag.bgcolor
	})
	watcher:hud_set_flags(state.hud_flags)
	watcher:set_properties({
		visual_size = state.visual_size,
		makes_footstep_sound = state.makes_footstep_sound,
		collisionbox = state.collisionbox,
	})

	-- restore privs
	local privs = get_player_privs(name_watcher)
	privs.interact = state.priv_interact
	local privs_extra = invited[name_watcher] and sm.extra_observe_privs
		or sm.extra_observe_privs_moderator

	for key, _ in pairs(privs_extra) do
		privs[key] = state.privs_extra[key]
	end
	set_player_privs(name_watcher, privs)

	-- set_pos seems to be very unreliable
	-- this workaround helps though
	after(0.1, function()
		watcher:set_pos(state.pos)
		-- delete state only after actually moved.
		-- this helps re-attach after log-off/server crash
		original_state_delete(watcher)
	end)

	-- if watcher was invited, notify invitee that watcher has detached
	if invited[name_watcher] then
		invited[name_watcher] = nil
		chat(state.target, '"' .. name_watcher
			.. '" has stopped looking over your shoulder.')

	end
	core_log('action', '[spectator_mode] "' .. name_watcher
		.. '" detached from "' .. state.target .. '"')

end -- detach


-- both players are online and all checks have been done when this
-- method is called
local function attach(name_watcher, name_target)

	-- detach from cart, horse, bike etc.
	detach(name_watcher)

	local watcher = get_player_by_name(name_watcher)
	local privs_watcher = get_player_privs(name_watcher)
	-- back up some attributes
	local properties = watcher:get_properties()
	local state = {
		collisionbox = properties.collisionbox,
		hud_flags = watcher:hud_get_flags(),
		makes_footstep_sound = properties.makes_footstep_sound,
		nametag = watcher:get_nametag_attributes(),
		pos = watcher:get_pos(),
		priv_interact = privs_watcher.interact,
		privs_extra = {},
		target = name_target,
		visual_size = properties.visual_size,
	}
	local privs_extra = invites[name_watcher] and sm.extra_observe_privs
		or sm.extra_observe_privs_moderator

	for key, _ in pairs(privs_extra) do
		state.privs_extra[key] = privs_watcher[key]
		privs_watcher[key] = true
	end
	original_state_set(watcher, state)

	-- set some attributes
	turn_off_hud_flags(watcher)
	watcher:set_properties({
		visual_size = { x = 0, y = 0 },
		makes_footstep_sound = false,
		collisionbox = { 0 }, -- TODO: is this the proper/best way?
	})
	watcher:set_nametag_attributes({ color = { a = 0 }, bgcolor = { a = 0 } })
	local eye_pos = vector_new(0, -5, -20)
	watcher:set_eye_offset(eye_pos)
	-- make sure watcher can't interact
	privs_watcher.interact = nil
	set_player_privs(name_watcher, privs_watcher)
	-- and attach
	player_api.player_attached[name_watcher] = true
	local target = get_player_by_name(name_target)
	watcher:set_attach(target, '', eye_pos)
	core_log('action', '[spectator_mode] "' .. name_watcher
		.. '" attached to "' .. name_target .. '"')

	if sm.keep_all_observers_alive or (not invites[name_watcher]) then
		-- server keeps all observers alive
		-- or moderator used '/watch' to sneak up without invite
		after(3, sm.keep_alive, name_watcher)
	end
end -- attach


-- called by '/watch' command
local function watch(name_watcher, name_target)
	if original_state[name_watcher] then
		return true, 'You are currently watching "'
			.. original_state[name_watcher].target
			.. '". Say /' .. sm.command_detach .. ' first.'

	end
	if name_watcher == name_target then
		return true, 'You may not watch yourself.'
	end

	local target = get_player_by_name(name_target)
	if not target then
		return true, 'Invalid target name "' .. name_target .. '"'
	end

	-- avoid infinite loops
	-- TODO: should we just watch the watched one then? Griefers can be a nuisance both ways.
	if original_state[name_target] then return true, '"' .. name_target .. '" is watching "'
		.. original_state[name_target].target .. '". You may not watch a watcher.' end

	attach(name_watcher, name_target)
	return true, 'Watching "' .. name_target .. '" at '
		.. minetest.pos_to_string(vector_round(target:get_pos()))

end -- watch


local function invite_timed_out(name_watcher)
	-- did the watcher already accept/decline?
	if not invites[name_watcher] then return end

	chat(invites[name_watcher], 'Invitation to "' .. name_watcher .. '" timed-out.')
	chat(name_watcher, 'Invitation from "' .. invites[name_watcher] .. '" timed-out.')
	invites[name_watcher] = nil
end -- invite_timed_out


-- called by '/watchme' command
local function watchme(name_target, param)
	if original_state[name_target] then
		return true, 'You are watching "' .. original_state[name_target].target
			.. '", no chain watching is allowed.'
	end

	if '' == param then
		return true, 'Please provide at least one player name.'
	end

	local messages = {}
	local count_invites = 0
	local invitation_timeout_string = tostring(sm.invitation_timeout)
	local invitation_postfix = '" has invited you to observe them. '
			.. 'Accept with /' .. 	sm.command_accept
			.. ', deny with /' .. sm.command_deny .. '.\n'
			.. 'The invite expires in ' .. invitation_timeout_string .. ' seconds.'

	-- checks whether watcher may be invited by target and returns error message if not
	-- if permitted, invites watcher and returns success message
	local function invite(name_watcher)
		if name_watcher == name_target then
			return 'You may not watch yourself.'
		end

		if original_state[name_watcher] then
			return '"' .. name_watcher .. '" is busy watching another player.'
		end

		if invites[name_watcher] then
			return '"' .. name_watcher .. '" has a pending invite, try again later.'
		end

		if not get_player_by_name(name_watcher) then
			return '"' .. name_watcher .. '" is not online.'
		end

		if not sm.is_permited_to_invite(name_target, name_watcher) then
			return 'You may not invite "' .. name_watcher .. '".'
		end

		count_invites = count_invites + 1
		invites[name_watcher] = name_target
		after(sm.invitation_timeout, invite_timed_out, name_watcher)
		-- notify invited
		chat(name_watcher, '"' .. name_target .. invitation_postfix)

		-- notify invitee
		return 'You have invited "' .. name_watcher .. '".'
	end -- invite()

	for name_watcher in string.gmatch(param, '[^%s,]+') do
		table.insert(messages, invite(name_watcher))
	end
	-- notify invitee
	local text = table.concat(messages, '\n')
	if 0 < count_invites then
		text = text .. '\nThe invitations expire in '
			.. invitation_timeout_string .. ' seconds.'
	end
	return true, text
end -- watchme


-- this function only checks privs etc. Mechanics are already checked in watchme()
-- other mods can override and extend these checks
function spectator_mode.is_permited_to_invite(name_target, name_watcher)
	if get_player_privs(name_target)[sm.priv_watch] then
		return true
	end

	if not get_player_privs(name_target)[sm.priv_invite] then
		return false
	end

	-- check for beerchat mute/ignore
	local meta = get_player_by_name(name_watcher):get_meta()
	if 'true' == meta:get_string('beerchat:muted:' .. name_target) then
		return false
	end

	return true
end -- is_permited_to_invite


-- called by the accept command '/smy'
local function accept_invite(name_watcher)
	local name_target = invites[name_watcher]
	if not name_target then
		return true, 'There is no invite for you. Maybe it timed-out.'
	end

	attach(name_watcher, name_target)
	invites[name_watcher] = nil
	invited[name_watcher] = name_target
	chat(name_target, '"' .. name_watcher .. '" is now attached to you.')
	return true, 'OK, you have been attached to "' .. name_target .. '". To disable type /'
		.. sm.command_detach

end -- accept_invite


-- called by the deny command '/smn'
local function decline_invite(name_watcher)
	if not invites[name_watcher] then
		return true, 'There is no invite for you. Maybe it timed-out.'
	end

	chat(invites[name_watcher], '"' .. name_watcher .. '" declined the invite.')
	invites[name_watcher] = nil
	return true, 'OK, declined invite.'
end -- decline_invite


local function on_joinplayer(watcher)
	local state = original_state_get(watcher)
	if not state then return end

	-- attempt to move to original state after log-off
	-- during attach or server crash
	local name_watcher = watcher:get_player_name()
	original_state[name_watcher] = state
	player_api.player_attached[name_watcher] = true
	detach(name_watcher)
end -- on_joinplayer


local function on_leaveplayer(watcher)
	local name_watcher = watcher:get_player_name()
	if invites[name_watcher] then
		-- invitation exists for leaving player
		chat(invites[name_watcher], 'Invitation to "' .. name_watcher
			.. '" invalidated because of logout.')

		invites[name_watcher] = nil
	end
	-- detach before leaving
	detach(name_watcher)
	-- detach any that are watching this user
	local attached = {}
	for name, state in pairs(original_state) do
		if name_watcher == state.target then
			table.insert(attached, name)
		end
	end
	-- we use separate loop to avoid editing a
	-- hash while it's being looped
	for _, name in ipairs(attached) do
		detach(name)
	end
end -- on_leaveplayer


-- different servers may want different behaviour, they can
-- override this function
function spectator_mode.on_respawnplayer(watcher)
--	* Called when player is to be respawned
--	* Called _before_ repositioning of player occurs
--	* return true in func to disable regular player placement
	local state = original_state_get(watcher)
	if not state then return end

	local name_target = state.target
	local name_watcher = watcher:get_player_name()
	player_api.player_attached[name_watcher] = true
	if invited[name_watcher] then
		detach(name_watcher)
		invited[name_watcher] = name_target
	else
		detach(name_watcher)
	end
	after(.4, attach, name_watcher, name_target)
	return true
end -- on_respawnplayer


minetest.register_chatcommand(sm.command_attach, {
	params = '<target name>',
	description = 'Watch a given player',
	privs = { [sm.priv_watch] = true },
	func = watch,
})


minetest.register_chatcommand(sm.command_detach, {
	description = 'Unwatch a player',
	privs = { },
	func = detach,
})


minetest.register_chatcommand(sm.command_invite, {
	description = 'Invite player(s) to watch you',
	params = '<player name>[,<player2 name>[ <playerN name>]' .. ']',
	privs = { [sm.priv_invite] = true },
	func = watchme,
})


minetest.register_chatcommand(sm.command_accept, {
	description = 'Accept an invitation to watch another player',
	params = '',
	privs = { },
	func = accept_invite,
})


minetest.register_chatcommand(sm.command_deny, {
	description = 'Deny an invitation to watch another player',
	params = '',
	privs = { },
	func = decline_invite,
})


minetest.register_on_joinplayer(on_joinplayer)
minetest.register_on_leaveplayer(on_leaveplayer)
minetest.register_on_respawnplayer(spectator_mode.on_respawnplayer)

