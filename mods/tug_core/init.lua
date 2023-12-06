local minetest, math, vector = minetest, math, vector
local modname = minetest.get_current_modname()
local prefix = modname .. ":"

minetest.settings:set("time_speed", 0)
minetest.settings:set("viewing_range", 50)

-- fix
ground_level = 8

minetest.register_alias("mapgen_stone", prefix .. "ground")
minetest.register_alias("mapgen_grass", prefix .. "ground")
minetest.register_alias("mapgen_water_source", prefix .. "ground")
minetest.register_alias("mapgen_river_water_source", prefix .. "ground")

local colors = {
    sky = "#ffffff", -- sky
    ground = "#ffffff", -- ground
    frame = "#baca44", -- frame
    light_square = "#EEEED2", -- light square
    dark_square = "#769656",  -- dark square
    light_pieces = "#ffffff", -- light pieces
    dark_pieces = "#2E2E2E", -- dark pieces
}

minetest.register_node(prefix .. "ground", {
	tiles = {"tug_blank.png^[colorize:" .. colors.ground},
	--pointable = false,
    is_ground_content = false,
})

minetest.register_node(prefix .. "frame", {
	tiles = {"tug_blank.png^[colorize:" .. colors.frame},
	--pointable = false,
    is_ground_content = false,
})

minetest.register_node(prefix .. "dark", {
	tiles = {"tug_blank.png^[colorize:" .. colors.dark_square},
	--pointable = false,
    is_ground_content = false,
})

minetest.register_node(prefix .. "light", {
	tiles = {"tug_blank.png^[colorize:" .. colors.light_square},
	--pointable = false,
    is_ground_content = false,
})

minetest.register_on_generated(function(minp, maxp, blockseed)
    for x = -1, 8 do
        for y = -1, 8 do
            node = "dark"
            if (x + y) % 2 == 0 then
                node = "light"
            end

            if x == -1 or x == 8 or y == -1 or y == 8 then
                node = "frame"
            end

            minetest.set_node({x = x, y = ground_level, z = y}, {name = prefix .. node})
        end
    end
end)

for _, piece in pairs(tug_chess_logic.pieces) do
    minetest.chat_send_all(piece)
    minetest.register_entity(prefix .. piece, {
        initial_properties = {
            visual = "mesh",
            mesh = "tug_core_" .. piece .. ".obj",
            physical = true,
            pointable = true,
            collide_with_objects = false,
            textures = {"tug_blank.png^[colorize:" .. colors.light_pieces},
            visual_size = vector.new(2, 2, 2),
        },
        on_step = function(self, dtime, moveresult)
        end,
    })
end

minetest.register_on_joinplayer(function(player)
    player:set_pos(vector.new(0, ground_level + 1, 0))

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
end)

minetest.register_chatcommand("start", {
    params = "[player2]",
    description = "default is singleplayer against engine, use player2 to play against an other player",
    privs = {},
    func = function(name, param)
        minetest.chat_send_all(name)
        update_game_board(tug_chess_logic.get_default_board())
    end,
})

local entity_lookup = {
    ["R"] = "rook",
    ["N"] = "knight",
    ["B"] = "bishop",
    ["Q"] = "queen",
    ["K"] = "king",
    ["P"] = "pawn",
}

function update_game_board(board)
    for x = 0, 7 do
        for y = 0, 7 do
            local piece = board[x + 1][y + 1]
            if piece ~= nil then
                local objs = minetest.get_objects_in_area(vector.new(x - 0.5, ground_level - 0.5, y - 0.5), vector.new(x + 0.5, ground_level + 0.5, y + 0.5))
                if #objs > 0 then
                    for _, obj in pairs(objs) do
                        obj:remove()
                    end
                end
                local ent = minetest.add_entity(vector.new(x, ground_level + 0.5, y), prefix .. entity_lookup[string.upper(piece.name)])
				if piece.name == string.upper(piece.name) then
                    ent:set_properties({ textures = {"tug_blank.png^[colorize:" .. colors.light_pieces} })
                else
                    ent:set_properties({ textures = {"tug_blank.png^[colorize:" .. colors.dark_pieces} })
					ent:set_yaw(math.pi)
                end
            end
        end
    end
end
