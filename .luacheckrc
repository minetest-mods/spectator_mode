-- Exclude regression tests / unit tests
exclude_files = {
	"**/spec/**",
}

globals = {
	player_api = { fields = { "player_attached" } },
	"spectator_mode",
}

read_globals = {
	-- Stdlib
	string = { fields = { "split" } },
	table = { fields = { "copy", "insert" } },

	-- Minetest
	"minetest",
	vector = { fields = { "copy", "new", "round" } },
}
