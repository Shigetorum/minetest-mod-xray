
xray = {}

-- View range
xray.vrange = 5

-- Default opacity
xray.opacity = 150

-- Table: orig_type_name = xray_type_name
xray.nodes = {}

-- Register nodes
xray.nodes["default:stone"] = "xray:stone"
minetest.register_node("xray:stone", {
	description = "X-Ray Stone",
	drawtype = "glasslike",
	use_texture_alpha = true,
	tiles = { "default_stone.png^[opacity:" .. xray.opacity },
	groups = { cracky = 3, stone = 1 },
	drop = 'default:cobble',
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	legacy_mineral = true,
})

xray.nodes["default:stonebrick"] = "xray:stonebrick"
minetest.register_node("xray:stonebrick", {
	description = "X-Ray Stone Brick",
	drawtype = "glasslike",
	use_texture_alpha = true,
	tiles = { "default_stone_brick.png^[opacity:" .. xray.opacity },
	groups = { cracky = 2, stone = 1 },
	drop = 'default:stonebrick',
	sounds = default.node_sound_stone_defaults(),
	paramtype = "light",
	paramtype2 = "facedir",
	place_param2 = 0,
	is_ground_content = false,
})

-- ##################################################################

-- Move range for restore
xray.mrange = xray.vrange + 2

-- Table: player_name = xray_enabled
xray.enable_map = {}

-- Logger
xray.log_enabled = false
xray.log = function(fmt, ...)
	if not xray.log_enabled then
		return
	end
	minetest.log("action", "[xray] "..string.format(fmt, unpack(arg)))
end

-- Used to produce table keys and for logging
xray.v_to_string = function(pos)
	return "["..pos.x..", "..pos.y..", "..pos.z.."]"
end

xray.find_type_around = function(center_pos, radius, type_name)
	return minetest.find_nodes_in_area(vector.subtract(center_pos, radius), vector.add(center_pos, radius), type_name)
end

-- Collect xray node positions into pos_map
xray.collect_xray_nodes = function(center_pos, pos_map)
	for orig_type_name, xray_type_name in pairs(xray.nodes) do
		for _, pos in ipairs(xray.find_type_around(center_pos, xray.mrange, xray_type_name)) do
			local pos_str = xray.v_to_string(pos)
			xray.log("[collect_xray_nodes] add to pos_map: %s = %s", pos_str, orig_type_name)
			pos_map[pos_str] = { pos, orig_type_name }
		end
	end
end

-- Remove node positions within view range from pos_map
-- Swap nodes from orig_type_name into xray_type_name
xray.handle_view_range = function(start_pos, pos_map)
	for orig_type_name, xray_type_name in pairs(xray.nodes) do
		for _, pos in ipairs(xray.find_type_around(start_pos, xray.vrange, xray_type_name)) do
			local pos_str = xray.v_to_string(pos)
			xray.log("[handle_view_range] remove from pos_map: %s", pos_str)
			pos_map[pos_str] = nil
		end
		for _, pos in ipairs(xray.find_type_around(start_pos, xray.vrange, orig_type_name)) do
			local pos_str = xray.v_to_string(pos)
			xray.log("[handle_view_range] swap_node: %s = %s -> %s", pos_str, orig_type_name, xray_type_name)
			minetest.swap_node(pos, { name = xray_type_name })
		end
	end
end

-- Swap nodes back to orig_type_name which are still left in pos_map
xray.restore = function(pos_map)
	for pos_str, value in pairs(pos_map) do
		local pos = value[1]
		local type_name = value[2]
		xray.log("[restore] swap_node: %s = %s", pos_str, type_name)
		minetest.swap_node(pos, { name = type_name })
	end
end

-- Register chat command
minetest.register_chatcommand("xray", {
	description = "Put on X-Ray glasses.",
	privs = { shout = true },
	func = function(name)
		if xray.enable_map[name] then
			xray.enable_map[name] = false
			minetest.chat_send_player(name, "X-Ray disabled.")
		else
			xray.enable_map[name] = true
			minetest.chat_send_player(name, "X-Ray enabled.")
		end
	end,
})

-- Register globalstep
minetest.register_globalstep(function(dtime)
	local pos_map = {}
	for _, player in ipairs(minetest.get_connected_players()) do
		local player_pos = player:getpos()
		xray.collect_xray_nodes(player_pos, pos_map)
	end
	for _, player in ipairs(minetest.get_connected_players()) do
		local player_pos = player:getpos()
		if xray.enable_map[player:get_player_name()] then
			xray.handle_view_range(player_pos, pos_map)
		end
	end
	xray.restore(pos_map)
end)
