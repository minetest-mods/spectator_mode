-- main unit testing file that mineunit picks up
-- https://github.com/S-S-X/mineunit

require("mineunit")

mineunit("core")
mineunit("player")
mineunit("server")
mineunit('common/after')

-- mimic player_api.player_attached
fixture('player_api')
-- add some not yet included functions
fixture('mineunit_extensions')
-- mimic beerchat.has_player_muted_player
fixture('beerchat')

local function pd1(m) print(dump(m)) end
local function pd(...) for _, m in ipairs({...}) do pd1(m) end end

-- override chat_send_player to inspect what was sent
local chatlog = {}
local core_chat_send_player = core.chat_send_player
function core.chat_send_player(to_name, message)
	table.insert(chatlog, { to = to_name, message = message })
	return core_chat_send_player(to_name, message)
end
local function reset_chatlog() chatlog = {} end

describe("Mod initialization", function()

	it("Wont crash", function()
		sourcefile("init")
	end)

end)

describe('Watching:', function()

	-- create some players
	local players = {
		SX = Player("SX", { interact = 1 }),
		boss = Player("boss", { interact = 1, watch = 1 }),
		dude1 = Player("dude1", { interact = 1, }),
		dude2 = Player("dude2", { interact = 1, }),
		dude3 = Player("dude3", { interact = false, }),
	}
	local start_positions = {}
	local boss = players.boss
	local dude1 = players.dude1
	local dude2 = players.dude2
	local dude3 = players.dude3

	setup(function()
		-- make sure the privs are registered
		mineunit:mods_loaded()
		-- log on all players and move them to unique positions
		local i, pos = 1
		for name, player in pairs(players) do
			mineunit:execute_on_joinplayer(player)
			pos = vector.new(10 * i, 20 * i, 30 * i)
			start_positions[name] = pos
			player:set_pos(pos)
			i = i + 1
		end
	end)

	teardown(function()
		mineunit:info('shutting down server')
		for _, player in pairs(players) do
			mineunit:execute_on_leaveplayer(player)
		end
		mineunit:execute_globalstep(100)
	end)

	it("boss attaches to dude1", function()
		reset_chatlog()
		boss:send_chat_message("/watch dude1")
		assert.equals(1, #chatlog, 'unexpected amount of messages, '
			.. 'was dude1 notified by accident')
		assert.equals('boss', chatlog[1].to)
		assert.equals(1, chatlog[1].message:find('^Watching "dude1" at %('))
		local pos = boss:get_pos()
		assert.equals(start_positions.dude1.x, pos.x)
		assert.equals(start_positions.dude1.y - 5, pos.y)
		assert.equals(start_positions.dude1.z - 20, pos.z)
	end)

	it('boss returns to start position and nobody is notified about it', function()
		-- let's make sure boss is still attached, jic we change previous test
		assert.is_false(vector.equals(start_positions.boss, boss:get_pos()),
			'boss is still at starting position: unit setup error')
		reset_chatlog()
		boss:send_chat_message('/unwatch')
		mineunit:execute_globalstep(1)
		assert.equals(0, #chatlog, 'there was an error message sent to ?')
		assert.is_true(vector.equals(start_positions.boss, boss:get_pos()),
			'boss did not move back to starting position')
	end)

	it('boss tries to unwatch when not watching', function()
		reset_chatlog()
		boss:send_chat_message('/unwatch')
		mineunit:execute_globalstep(1)
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.is_not_nil(chatlog[1].message:find('not observing'),
			'unexpected chat response')
	end)

	it('player receives message when issuing /unwatch while not attached', function()
		reset_chatlog()
		dude1:send_chat_message('/unwatch')
		mineunit:execute_globalstep(1)
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.is_not_nil(chatlog[1].message:find('not observing'),
			'unexpected chat response')
	end)

	it('invitations are sent and expire', function()
		reset_chatlog()
		-- we also test multiple invites with space separation
		dude2:send_chat_message('/watchme dude1 SX')
		assert.equals('dude1', chatlog[1].to, 'dude1 did not get invited')
		assert.equals('SX', chatlog[2].to, 'SX did not get invited')
		assert.equals('dude2', chatlog[3].to, 'dude2 did not get message')
		local message = chatlog[3].message
		assert.is_true(message:find('"dude1"') and message:find('"SX"') and true,
			'response message does not contain invities')
		assert.is_not_nil(message:find('60 seconds'),
			'response message does not contain expire info')
		reset_chatlog()
		mineunit:execute_globalstep(60)
		assert.equals(4, #chatlog, 'unexpected chatlog count')
		reset_chatlog()
		players.SX:send_chat_message('/smy')
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.equals('SX', chatlog[1].to, 'message was not sent to SX but ' .. chatlog[1].to)
		message = chatlog[1].message
		assert.is_not_nil(message:find('timed%-out%.$'),
			'time out message does not end with "timed-out."')
		local pos = players.SX:get_pos()
		assert.is_true(vector.equals(start_positions.SX, pos),
			'Invitation did not expire, SX was moved.')
	end)

	it('watching by normal player not possible', function()
		local pos = dude2:get_pos()
		reset_chatlog()
		dude2:send_chat_message('/watch dude1')
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.equals('dude2', chatlog[1].to, 'unexpected recipient.')
		assert.is_not_nil(chatlog[1].message:find('to run this command'),
			'unexpected error message')
		assert.is_true(vector.equals(pos, dude2:get_pos()))
	end)

	it('inviting is not possible when not having invite priv', function()
		local last_priv = spectator_mode.priv_invite
		-- set needed priv to avoid using dude3, this allows us to test
		-- minetest.conf settings
		spectator_mode.priv_invite = 'testPrivThatDoesNotExist'
		reset_chatlog()
		-- we also test comma list
		dude2:send_chat_message('/watchme dude1,SX')
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		local message = chatlog[1].message
		assert.is_not_nil(message:find('"dude1"'), 'did not parse player list correctly')
		assert.is_not_nil(message:find('"SX"'), 'did not parse player list correctly')
		assert.is_not_nil(message:find('^You may not invite'), 'did not revoke inivting')
		assert.is_nil(message:find('60 seconds'), 'time out message was wrongfully added')
		-- restore priv setting
		spectator_mode.priv_invite = last_priv
	end)

	it('player can not invite himself', function()
		reset_chatlog()
		dude1:send_chat_message('/watchme dude1')
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.equals('dude1', chatlog[1].to, 'unexpected recipient.')
		assert.is_not_nil(chatlog[1].message:find('may not watch yourself'),
			'unexpected chat response')
	end)

	it('moderator can not invite himself', function()
		reset_chatlog()
		boss:send_chat_message('/watchme boss')
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.equals('boss', chatlog[1].to, 'unexpected recipient.')
		assert.is_not_nil(chatlog[1].message:find('may not watch yourself'),
			'unexpected chat response')
	end)

	it('moderator can not attach to an observing player and gets name of observed player', function()
		dude1:send_chat_message('/watchme dude2')
		dude2:send_chat_message('/smy')
		mineunit:execute_globalstep(1)
		reset_chatlog()
		boss:send_chat_message('/watch dude2')
		mineunit:execute_globalstep(1)
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.equals('boss', chatlog[1].to, 'unexpected recipient.')
		assert.is_not_nil(chatlog[1].message:find('^"dude2" is watching "dude1"'),
			'unexpected chat response')
	end)
	it('player can not invite an observing player', function()
		reset_chatlog()
		players.SX:send_chat_message('/watchme dude2')
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.equals('SX', chatlog[1].to, 'unexpected recipient.')
		assert.is_not_nil(chatlog[1].message:find('^"dude2".*watching another player%.$'),
			'unexpected chat response')

	end)
	-- TODO: check if this can't be exploited to make circular attaching
	it('player can invite an observed player', function()
		reset_chatlog()
		players.SX:send_chat_message('/watchme dude1')
		assert.equals(2, #chatlog, 'unexpected chatlog count')
		assert.equals('dude1', chatlog[1].to, 'unexpected recipient.')
		assert.equals('SX', chatlog[2].to, 'unexpected recipient.')
		assert.is_not_nil(chatlog[1].message:find('^"SX".* seconds%.$'),
			'unexpected chat response')
	end)
	it('player can deny an invite', function()
		reset_chatlog()
		dude1:send_chat_message('/smn')
		assert.equals(2, #chatlog, 'unexpected chatlog count')
		assert.equals('SX', chatlog[1].to, 'unexpected recipient.')
		assert.equals('dude1', chatlog[2].to, 'unexpected recipient.')
	end)
	it('player can detach and returns to original position', function()
		reset_chatlog()
		dude2:send_chat_message('/unwatch')
		mineunit:execute_globalstep(1)
		assert.is_true(vector.equals(start_positions.dude2, dude2:get_pos()),
			'dude2 did not move back to starting position')
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.equals('dude1', chatlog[1].to, 'unexpected recipient.')
		assert.is_not_nil(chatlog[1].message:find('^"dude2" has stopped loo'),
			'unexpected chat response')
	end)
	it('can not invite a player with pending invitation', function()
		dude1:send_chat_message('/watchme dude2')
		reset_chatlog()
		players.SX:send_chat_message('/watchme dude2')
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.equals('SX', chatlog[1].to, 'unexpected recipient.')
		assert.is_not_nil(chatlog[1].message:find('^"dude2" has a pen'),
			'unexpected chat response')
	end)
	it('boss can attach to an unwatched player with pending invitation', function()
		reset_chatlog()
		boss:send_chat_message('/watch dude2')
		mineunit:execute_globalstep(1)
		assert.is_true(vector.equals(boss:get_pos(), vector.add(
			dude2:get_pos(), vector.new(0, -5, -20))), 'boss not with dude2')
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.equals('boss', chatlog[1].to, 'unexpected recipient.')
		assert.is_not_nil(chatlog[1].message:find('^Watching "dude2"'),
			'unexpected chat response')
	end)
	it('can accept invitation after a moderator also attached', function()
		reset_chatlog()
		dude2:send_chat_message('/smy')
		mineunit:execute_globalstep(1)
		assert.equals(2, #chatlog, 'unexpected chatlog count')
		assert.equals('dude1', chatlog[1].to, 'unexpected recipient.')
		assert.equals('dude2', chatlog[2].to, 'unexpected recipient.')
		assert.is_not_nil(chatlog[1].message:find('^"dude2" is now attached'),
			'unexpected chat response')
		assert.is_not_nil(chatlog[2].message:find('^OK, you have been atta'),
			'unexpected chat response')
	end)
	it('dude2 is detached when dude1 logs off', function()
		reset_chatlog()
		mineunit:execute_on_leaveplayer(dude1)
		mineunit:execute_globalstep(1)
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.equals('dude1', chatlog[1].to, 'unexpected recipient.')
		assert.is_not_nil(chatlog[1].message:find('^"dude2" has stopped loo'),
			'unexpected chat response')
	end)
	it('dude3 ignores dude1 and can not be invited by dude1', function()
		reset_chatlog()
		dude3:get_meta():set_string('beerchat:muted:dude1', 'true')
		dude1:send_chat_message('/watchme dude3')
		assert.equals(1, #chatlog, 'unexpected chatlog count')
		assert.equals('dude1', chatlog[1].to, 'unexpected recipient.')
		assert.equals(chatlog[1].message, 'You may not invite "dude3".')
	end)
	it('boss is detached when he logs on after logging off while attached', function()
		reset_chatlog()
		assert.is_true(vector.equals(boss:get_pos(), vector.add(
			dude2:get_pos(), vector.new(0, -5, -20))), 'boss not with dude2')
		mineunit:execute_on_leaveplayer(boss)
		mineunit:execute_globalstep(1)
		assert.equals(0, #chatlog, 'unexpected chatlog count')
		mineunit:execute_on_joinplayer(boss)
		mineunit:execute_globalstep(1)
		assert.is_false(vector.equals(boss:get_pos(),
			vector.add(dude2:get_pos(), vector.new(0, -5, -20))),
			'boss with dude2')
	end)
end)

