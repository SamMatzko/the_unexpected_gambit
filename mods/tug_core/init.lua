local minetest, math, vector = minetest, math, vector
local modname = minetest.get_current_modname()
local prefix = modname .. ":"
local storage = minetest.get_mod_storage()

local loaded_gamestate = minetest.deserialize(storage:get_string("gamestate"))
tug_gamestate.g = loaded_gamestate

if loaded_gamestate == nil then
    tug_gamestate.g = {
        players = {"", ""},
        current_player = nil,
        current_selected = nil,
        current_board = nil,
		moves_until_unexpected = -1,
    }
end

tug_core = {
    engine_moves_true = 3,
    hud_refs = {},
}

-- metadata
function save_metadata()
    storage:set_string("gamestate", minetest.serialize(tug_gamestate.g))
end

minetest.settings:set("time_speed", 0)
minetest.settings:set("viewing_range", 50)

-- fix
ground_level = 8

minetest.register_alias("mapgen_stone", prefix .. "ground")
minetest.register_alias("mapgen_grass", prefix .. "ground")
minetest.register_alias("mapgen_water_source", prefix .. "ground")
minetest.register_alias("mapgen_river_water_source", prefix .. "ground")

local colors = {
    sky = "#8e8e8e", -- sky
    ground = "#8e8e8e", -- ground
    frame = "#baca44", -- frame
    light_square = "#EEEED2", -- light square
    dark_square = "#769656",  -- dark square
    light_pieces = "#ffffff", -- light pieces
    dark_pieces = "#2E2E2E", -- dark pieces
}

local entity_lookup = {
    ["R"] = "rook",
    ["N"] = "knight",
    ["B"] = "bishop",
    ["Q"] = "queen",
    ["K"] = "king",
    ["P"] = "pawn",
}

minetest.register_node(prefix .. "ground", {
	tiles = {"tug_blank.png^[colorize:" .. colors.ground},
	pointable = false,
    is_ground_content = false,
})

minetest.register_node(prefix .. "frame", {
	tiles = {"tug_frame.png"},
	pointable = false,
    is_ground_content = false,
    paramtype2 = "facedir",
})

minetest.register_node(prefix .. "frame_corner", {
	tiles = {"tug_frame_corner.png"},
	pointable = false,
    is_ground_content = false,
    paramtype2 = "facedir",
})

minetest.register_node(prefix .. "dark", {
	tiles = {"tug_blank.png^[colorize:" .. colors.dark_square},
    is_ground_content = false,
})

minetest.register_node(prefix .. "light", {
	tiles = {"tug_blank.png^[colorize:" .. colors.light_square},
    is_ground_content = false,
})

minetest.register_node(prefix .. "barrier", {
    drawtype = "airlike",
    paramtype = "light",
    pointable = false,
    sunlight_propagates = true,
})

-- hack to get higher hand range, set on joinplayer
local function set_player_hand(player)
    player:get_inventory():set_stack("main", 1, {name = prefix .. "hand"})
end

minetest.register_craftitem(prefix .. "hand", {
    range = 20,
    on_drop = function(itemstack, dropper, pos)
        itemstack:clear()
        set_player_hand(dropper)
    end,
})

local top_circle_def = {
    hud_elem_type = "image",
    position = {x = 1, y = 0},
    alignment = {x = -1, y = 1},
    scale = {x = 0.25, y = 0.25},
    offset = {x = -50, y = 50},
    z_index = 0,
}

local bottom_circle_def = {
    hud_elem_type = "image",
    position = {x = 1, y = 1},
    alignment = {x = -1, y = -1},
    scale = {x = 0.25, y = 0.25},
    offset = {x = -50, y = -50},
    z_index = 0,
}

local function get_player_id(player)
    for i, _player in pairs(tug_gamestate.g.players) do
        if _player.name == player:get_player_name() then
            return i
        end
    end
end

local function add_color_hud(player)
    local name = player:get_player_name()
    tug_core.hud_refs.name = {}

    local top_color = "white"
    local bottom_color = "black"

    if tug_gamestate.g.players[get_player_id(player)].color == 1 then
        _temp = top_color
        top_color = bottom_color
        bottom_color = _temp
    end

    local top_circle = top_circle_def
    top_circle.text = "tug_" .. top_color .. "_circle.png"
    tug_core.hud_refs.name.top_circle = player:hud_add(top_circle)

    local bottom_circle = bottom_circle_def
    bottom_circle.text = "tug_" .. bottom_color .. "_circle.png"
    tug_core.hud_refs.name.bottom_circle = player:hud_add(bottom_circle)

    local marking_circle = top_circle_def
    if tug_gamestate.g.players[tug_gamestate.g.current_player].name == name then
        marking_circle = bottom_circle_def
    end
    marking_circle.text = "tug_marking_circle.png"
    marking_circle.z_index = 1

    tug_core.hud_refs.name.marking_circle = player:hud_add(marking_circle)
end

minetest.register_on_generated(function(minp, maxp, blockseed)
    for x = -1, 8 do
        for z = -1, 8 do
            local node = "light"
            if (x + z) % 2 == 0 then
                node = "dark"
            end

            local param2 = 0
            if x == -1 or x == 8 or z == -1 or z == 8 then
                node = "frame"
                if z == 8 then
                    param2 = 2
                elseif x == 8 then
                    param2 = 3
                elseif x == - 1 then
                    param2 = 1
                end
                if (x == -1 and (z == -1 or z == 8)) or (x == 8 and (z == -1 or z == 8)) then
                    node = "frame_corner"
                    if z == 8 and x == -1 then
                        param2 = 2
                    elseif z == 8 and x == 8 then
                        param2 = 3
                    elseif z == -1 and x == 8 then
                        param2 = 4
                    end
                end
            end

            minetest.set_node({x = x, y = ground_level, z = z}, {name = prefix .. node, param2 = param2})
        end
    end

    local cube_radius = 15
    for x = -cube_radius, cube_radius do
        for y = -cube_radius, cube_radius do
            for z = -cube_radius, cube_radius do
                if (math.abs(x) == cube_radius or math.abs(y) == cube_radius or math.abs(z) == cube_radius) and ground_level + y > ground_level then
                    minetest.set_node({x = x + 5, y = ground_level + y, z = z + 5}, {name = prefix .. "barrier"})
                end
            end
        end
    end

end)

for _, piece in pairs(entity_lookup) do
    minetest.chat_send_all(piece)
    minetest.register_entity(prefix .. piece, {
        initial_properties = {
            visual = "mesh",
            mesh = "tug_core_" .. piece .. ".obj",
            physical = true,
            pointable = false,
            collide_with_objects = false,
            textures = {"tug_blank.png^[colorize:" .. colors.light_pieces},
            visual_size = vector.new(2, 2, 2),
            static_save = false,
            use_texture_alpha = true,
        },
        on_step = function(self, dtime, moveresult)
        end,
    })
end

local selected_textures = {}

for n = 1, 6 do
    table.insert(selected_textures, "tug_blank.png^[colorize:#ff000080")
end

minetest.register_entity(prefix .. "selected", {
    initial_properties = {
        visual = "cube",
        physical = true,
        pointable = false,
        collide_with_objects = false,
        textures = selected_textures,
        visual_size = vector.new(1, 1, 1),
        static_save = false,
        use_texture_alpha = true,
    },
    on_step = function(self, dtime, moveresult)
    end,
})

minetest.register_on_newplayer(function(player)
    local name = player:get_player_name()
    player:set_pos(vector.new(0, ground_level + 1, 0))
    local basic_privs = minetest.get_player_privs(name)
    basic_privs.fly = true
    minetest.set_player_privs(name, basic_privs)
end)

local make_move = 0
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    
    player:hud_set_hotbar_itemcount(1)
    player:get_inventory():set_size("main", 1)
    set_player_hand(player)
    player:set_inventory_formspec(
		"formspec_version[4]" ..
		"size[10, 10]" ..
		"label[0.5,0.5; ]"
	)

    player:set_physics_override({speed = 1.5})

    local clr1 = colors.sky
	player:set_sky({
        clouds = false,
        type = "regular",
		sky_color = {
			day_sky = clr1,
			day_horizon = clr1,
			dawn_sky = clr1,
			dawn_horizon = clr1,
			night_sky = clr1,
			night_horizon = clr1,
		},
    })
    player:set_sun({
        visible = false,
        sunrise_visible = false,
    })
    player:hud_set_flags({
        hotbar = false,
		healthbar = false,
		crosshair = true,
		wielditem = false,
		breathbar = false,
		minimap = false,
		minimap_radar = false,
	})

    local found = false
    for i, p in ipairs(tug_gamestate.g.players) do
        if p.name == name then
            if i == tug_gamestate.g.current_player then
                minetest.chat_send_player(p.name, "Your turn.")
            else
                minetest.chat_send_player(p.name, tug_gamestate.g.players[tug_gamestate.g.current_player].name .. "'s turn.")
                -- engine moves
                if tug_gamestate.g.players[tug_gamestate.g.current_player].name == "" then
                    make_move = tug_core.engine_moves_true
                end
            end
            add_color_hud(player)
            found = true
        end
    end

    if not found then
        minetest.chat_send_player(name, "Use /start to start a game.")
    end

    minetest.after(0, function()
        update_game_board()
    end)
end)

function split(s, delimiter)
    local result = {}
    for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

local function switch_player()
    tug_gamestate.g.current_player = 3 - tug_gamestate.g.current_player
    minetest.chat_send_player(tug_gamestate.g.players[tug_gamestate.g.current_player].name, "Your turn.")
    minetest.chat_send_player(tug_gamestate.g.players[3 - tug_gamestate.g.current_player].name, tug_gamestate.g.players[tug_gamestate.g.current_player].name .. "'s turn.")
end

local function made_move()
    switch_player()
	decrease_moves_until_unexpected()
    save_metadata()
    update_game_board()
    -- play sound
end

minetest.register_globalstep(function(dtime)
    if make_move == 0 then
        return
    end
    make_move = make_move - 1
    if make_move == 1 then
        make_move = 0
        tug_gamestate.g.current_board = tug_chess_engine.engine_next_board(tug_gamestate.g.current_board, tug_gamestate.g.players[2].color)
        
        made_move()
    end
end)

function generate_moves_until_unexpected()
	tug_gamestate.g.moves_until_unexpected = math.random(4, 10)
end

function decrease_moves_until_unexpected()
	if tug_gamestate.g.moves_until_unexpected > -1 then
		tug_gamestate.g.moves_until_unexpected = tug_gamestate.g.moves_until_unexpected - 1
		if tug_gamestate.g.moves_until_unexpected == 0 then
			generate_moves_until_unexpected()
			local behavior_pick = math.random(1, 100)
			for _, behavior in pairs(tug_unexpected.unexpected_behaviors) do
				if behavior.pick_min <= behavior_pick and behavior_pick <= behavior.pick_max then
					minetest.debug(behavior.name)
					behavior.func()
					break
				end
			end
		end
	end
end

function start_game(name, param, unexpected)
	tug_gamestate.g.players[1] = {name = name, color = 1}
	local t = split(param, " ")
	local player2 = t[#t]

	if player2 ~= "" then
		tug_gamestate.g.players[2] = {name = player2, color = 2}
	else
		tug_gamestate.g.players[2] = {name = "", color = 2}
	end

	math.randomseed(os.time())
	tug_gamestate.g.current_player = 1
	if math.random(0, 1) == 1 then
		tug_gamestate.g.players[1].color = 2
		tug_gamestate.g.players[2].color = 1
		tug_gamestate.g.current_player = 2
		minetest.chat_send_player(name, "You play with the black pieces.")
		minetest.chat_send_player(player2, "You play with the white pieces.")
	else
		minetest.chat_send_player(name, "You play with the white pieces.")
		minetest.chat_send_player(player2, "You play with the black pieces.")
	end

	minetest.chat_send_player(tug_gamestate.g.players[tug_gamestate.g.current_player].name, "Your turn.")
	minetest.chat_send_player(tug_gamestate.g.players[3 - tug_gamestate.g.current_player].name, tug_gamestate.g.players[tug_gamestate.g.current_player].name .. "'s turn.")

	tug_gamestate.g.current_board = tug_chess_logic.get_default_board()
	update_game_board()

	if unexpected then
		minetest.debug("Unexpected")
		generate_moves_until_unexpected()
	else
		minetest.debug("Normal")
		tug_gamestate.g.moves_until_unexpected = -1
	end

	if tug_gamestate.g.players[tug_gamestate.g.current_player].name == "" then
		make_move = tug_core.engine_moves_true
	end

	add_color_hud(minetest.get_player_by_name(name))
	if player2 ~= "" then
		add_color_hud(minetest.get_player_by_name(player2))
	end

	save_metadata()
end

minetest.register_chatcommand("start", {
	params = "[Player2]",
	description = "The game as it was intendet. Default is singleplayer against engine. Use Player2 to play against another player.",
	privs = {},
	func = function(name, param)
		start_game(name, param, true)
	end,

})

minetest.register_chatcommand("start_normal", {
    params = "[Player2]",
    description = "The normal game of chess. Default is singleplayer against engine. Use Player2 to play against another player.",
    privs = {},
    func = function(name, param)
		start_game(name, param, false)
	end,
})

minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
    if node.name == prefix .. "light" or node.name == prefix .. "dark" then
        local x = pos.x
        local y = pos.y
        local z = pos.z
        
        -- is current player the puncher
        if tug_gamestate.g.current_board ~= nil and puncher:get_player_name() == tug_gamestate.g.players[tug_gamestate.g.current_player].name then
            if tug_gamestate.g.current_selected == nil then
                -- check if piece is on square
                if tug_gamestate.g.current_board[z + 1][x + 1].name ~= "" then
                    -- punched piece (if white or not)
                    local is_white = tug_gamestate.g.current_board[z + 1][x + 1].name == string.upper(tug_gamestate.g.current_board[z + 1][x + 1].name)
                    -- check wether player color matches punched piece color
                    if (tug_gamestate.g.players[tug_gamestate.g.current_player].color == 1 and is_white) or (tug_gamestate.g.players[tug_gamestate.g.current_player].color == 2 and not is_white) then
                        tug_gamestate.g.current_selected = {x = x, z = z}
                        local objs = minetest.get_objects_in_area(vector.new(x - 0.5, y + 0.5, z - 0.5), vector.new(x + 0.5, y + 1.5, z + 0.5))
                        objs[1]:set_properties({ textures = {objs[1]:get_properties().textures[1] .. "C8"}})
                        local moves = tug_chess_logic.get_moves(z + 1, x + 1)
                        for _, move in pairs(moves) do
                            minetest.add_entity(vector.new(move.x - 1, y + 0.05, move.z - 1), prefix .. "selected")
                        end
                        tug_gamestate.g.current_selected.moves = moves
                    end
                end
            else
                if (x ~= tug_gamestate.g.current_selected.x) or (z ~= tug_gamestate.g.current_selected.z) then
                    local selected_move = nil
                    for _, m in pairs(tug_gamestate.g.current_selected.moves) do
                        if (m.x == x + 1) and (m.z == z + 1) then
                            selected_move = m
                            break
                        end
                    end
                    if selected_move then
                        tug_gamestate.g.current_board = tug_chess_logic.apply_move({x = tug_gamestate.g.current_selected.x + 1, z = tug_gamestate.g.current_selected.z + 1}, selected_move, tug_gamestate.g.current_board)
                        
                        made_move()
						
                        if tug_gamestate.g.players[tug_gamestate.g.current_player].name == "" then
                            make_move = tug_core.engine_moves_true
                        end
                    end
                end
                update_game_board()
                tug_gamestate.g.current_selected = nil
            end
        end
    end
end)

function update_game_board()
    if tug_gamestate.g.current_board == nil then
        return
    end

    for y = 0, 7 do
        for x = 0, 7 do
            local objs = minetest.get_objects_in_area(vector.new(x - 0.5, ground_level - 0.5, y - 0.5), vector.new(x + 0.5, ground_level + 0.5, y + 0.5))
            if #objs > 0 then
                for _, obj in pairs(objs) do
                    obj:remove()
                end
            end
            local piece = tug_gamestate.g.current_board[y + 1][x + 1]
            if piece.name ~= "" then
                local ent = minetest.add_entity(vector.new(x, ground_level + 0.5, y), prefix .. entity_lookup[string.upper(piece.name)])
                if piece.name == string.upper(piece.name) then
                    ent:set_properties({ textures = {"tug_blank.png^[colorize:" .. colors.light_pieces} })
                    ent:set_yaw(0.5 * math.pi)
                else
                    ent:set_properties({ textures = {"tug_blank.png^[colorize:" .. colors.dark_pieces} })
					ent:set_yaw(-0.5 * math.pi)
                end
            end
        end
    end
end
