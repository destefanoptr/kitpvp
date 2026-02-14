-- KitPvP with 6 random TP points
local tp_points = {
	{x = 1000, y = 100, z = 1000},
	{x = 2000, y = 100, z = 2000},
	{x = 3000, y = 100, z = 3000},
	{x = 4000, y = 100, z = 4000},
	{x = 5000, y = 100, z = 5000},
	{x = 6000, y = 100, z = 6000},
}


local function random_tp()
	math.randomseed(os.time() + (minetest.get_us_time and minetest.get_us_time() or 0))
	local idx = math.random(1, #tp_points)
	return tp_points[idx]
end

minetest.register_chatcommand("kitpvp", {
	func = function(name, param)
		-- clear inventory before showing formspec
		local player = minetest.get_player_by_name(name)
		if player then
			local inv = player:get_inventory()
			if inv then
				local function clear_inventory(inv)
					if not inv then return end
					local function fill_empty(listname, size)
						if inv:get_list(listname) then
							local t = {}
							for i = 1, size do t[i] = ItemStack("") end
							inv:set_list(listname, t)
						end
					end
					fill_empty("craft", 9)
					fill_empty("craftpreview", 1)
					fill_empty("main", 32)
					fill_empty("hotbar", 8)
					fill_empty("armor", 4)
				end
				clear_inventory(inv)
			end
		end

		minetest.show_formspec(name, "kitpvp:form",
			"size[8,9]" ..
			"label[0,0;Kit Selection]" ..
			"button[1,1;6,1;kit1;Pawn Kit]" ..
			"button[1,2;6,1;kit2;Crusher Kit]" ..
			"button[1,3;6,1;kit3;Spearman Kit]" ..
			"button[1,4;6,1;kit4;Archer Kit]" ..
			"button[1,5;6,1;kit_warrior;Heavy Kit]" ..
			"button[1,6;6,1;kit6;Barbarian]" ..
			"button[1,7;6,1;kit_crossbow_man;Crossbow Man]" ..
			"button_exit[1,8;6,1;exit;Exit]"
		)
	end
})

-- safe_enchant
local function safe_enchant(stack, enchant_name, level)
	if not stack or stack:is_empty() then return stack end

	local name = stack.get_name and stack:get_name() or nil
	if not name or name == "" then return stack end

	if mcl_enchanting and mcl_enchanting.enchant then
		local ok, err = pcall(function() mcl_enchanting.enchant(stack, enchant_name, level) end)
		if ok then return stack end
		minetest.log("error", "mcl_enchanting.enchant failed: " .. tostring(err))
	end

	if mcl_enchanting and mcl_enchanting.set_enchanted_itemstring then
		local ench_table = { { name = enchant_name, level = level } }
		local ok, itemstr = pcall(function() return mcl_enchanting.set_enchanted_itemstring(name, ench_table) end)
		if ok and itemstr and type(itemstr) == "string" then
			local new_stack = ItemStack(itemstr)
			if not new_stack:is_empty() then return new_stack end
		else
			minetest.log("error", "mcl_enchanting.set_enchanted_itemstring failed or returned nil")
		end
	end

	return stack
end

local function add_if_valid(inv, listname, item)
	if not item then return end
	local stack = nil
	if type(item) == "string" then
		if item == "" then return end
		stack = ItemStack(item)
	elseif type(item) == "table" and item.name then
		stack = ItemStack(item.name .. (item.count and (" "..item.count) or ""))
	else
		return
	end
	if not stack or stack:is_empty() then return end
	inv:add_item(listname, stack)
end

local function give_armor(inv, armor_items, protection_level, curse_level)
	local curse = "curse_of_vanishing"
	local prot = "protection"
	-- ensure armor list exists and has 4 slots
	if inv:get_list("armor") == nil then
		inv:set_list("armor", { ItemStack(""), ItemStack(""), ItemStack(""), ItemStack("") })
	end

	-- chest -> armor slot 2
	local chest_name = armor_items[2]
	if chest_name and chest_name ~= "" then
		local chest_stack = ItemStack(chest_name)
		if not chest_stack or chest_stack:is_empty() then
			minetest.log("warning", "give_armor: invalid chest item '" .. tostring(chest_name) .. "'")
		else
			if protection_level and protection_level > 0 then
				chest_stack = safe_enchant(chest_stack, prot, protection_level)
			end
			chest_stack = safe_enchant(chest_stack, curse, curse_level)
			inv:set_stack("armor", 2, chest_stack)
		end
	end

	-- leggings -> armor slot 3
	local legs_name = armor_items[3]
	if legs_name and legs_name ~= "" then
		local legs_stack = ItemStack(legs_name)
		if not legs_stack or legs_stack:is_empty() then
			minetest.log("warning", "give_armor: invalid leggings item '" .. tostring(legs_name) .. "'")
		else
			if protection_level and protection_level > 0 then
				legs_stack = safe_enchant(legs_stack, prot, protection_level)
			end
			legs_stack = safe_enchant(legs_stack, curse, curse_level)
			inv:set_stack("armor", 3, legs_stack)
		end
	end

	-- boots -> main inventory
	local boots_name = armor_items[4]
	if boots_name and boots_name ~= "" then
		local boots_stack = ItemStack(boots_name)
		if not boots_stack or boots_stack:is_empty() then
			minetest.log("warning", "give_armor: invalid boots item '" .. tostring(boots_name) .. "'")
		else
			if protection_level and protection_level > 0 then
				boots_stack = safe_enchant(boots_stack, prot, protection_level)
			end
			boots_stack = safe_enchant(boots_stack, curse, curse_level)
			inv:add_item("main", boots_stack)
		end
	end

	-- helmet -> armor slot 4 (last armor slot)
	local helmet_name = armor_items[1]
	if helmet_name and helmet_name ~= "" then
		local helmet_stack = ItemStack(helmet_name)
		if not helmet_stack or helmet_stack:is_empty() then
			minetest.log("warning", "give_armor: invalid helmet item '" .. tostring(helmet_name) .. "'")
		else
			if protection_level and protection_level > 0 then
				helmet_stack = safe_enchant(helmet_stack, prot, protection_level)
			end
			helmet_stack = safe_enchant(helmet_stack, curse, curse_level)
			inv:set_stack("armor", 4, helmet_stack)
		end
	end
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "kitpvp:form" then return end
	local player_name = player:get_player_name()
	local inv = player:get_inventory()
	if not inv then return end

	-- close the formspec immediately
	minetest.close_formspec(player_name, "kitpvp:form")

	local tp = random_tp()

	if fields.kit1 then
		give_armor(inv, {
			"mcl_armor:helmet_diamond",
			"mcl_armor:chestplate_diamond",
			"mcl_armor:leggings_diamond",
			"mcl_armor:boots_diamond"
		}, 0, 1)

		local sword = ItemStack("mcl_tools:sword_diamond")
		sword = safe_enchant(sword, "sharpness", 4) -- Sharpness IV
		sword = safe_enchant(sword, "curse_of_vanishing", 1)
		inv:add_item("main", sword)

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Pawn Kit!")

	elseif fields.kit2 then
		give_armor(inv, {
			"mcl_armor:helmet_netherite",
			"mcl_armor:chestplate_netherite",
			"mcl_armor:leggings_iron",
			"mcl_armor:boots_netherite"
		}, 0, 1)

		local sword = ItemStack("mcl_tools:sword_iron")
		local mace = ItemStack("mcl_tools:mace")
		sword = safe_enchant(sword, "curse_of_vanishing", 1)
		sword = safe_enchant(sword, "sharpness", 3)
		mace = safe_enchant(mace, "curse_of_vanishing", 1)
		inv:add_item("main", sword)
		inv:add_item("main", mace)

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Crusher Kit!")

	elseif fields.kit3 then
		local armor_names = {
			"mcl_armor:helmet_iron",
			"mcl_armor:chestplate_iron",
			"mcl_armor:leggings_diamond",
			"mcl_armor:boots_diamond"
		}
		if inv:get_list("armor") == nil then
			inv:set_list("armor", { ItemStack(""), ItemStack(""), ItemStack(""), ItemStack("") })
		end
		for _, aname in ipairs(armor_names) do
			local stack = ItemStack(aname)
			if stack and not stack:is_empty() then
				stack = safe_enchant(stack, "protection", 2) -- Protection II
				stack = safe_enchant(stack, "curse_of_vanishing", 1) -- Curse I
				if aname:find("helmet") then
					inv:set_stack("armor", 4, stack)
				elseif aname:find("chestplate") then
					inv:set_stack("armor", 2, stack)
				elseif aname:find("leggings") then
					inv:set_stack("armor", 3, stack)
				elseif aname:find("boots") then
					inv:add_item("main", stack)
				end
			else
				minetest.log("warning", "kit3: invalid armor item '" .. tostring(aname) .. "'")
			end
		end

		local sword = ItemStack("mcl_tools:sword_diamond")
		local trident = ItemStack("mcl_tridents:trident")
		if sword and not sword:is_empty() then
			sword = safe_enchant(sword, "curse_of_vanishing", 1)
			sword = safe_enchant(sword, "sharpness", 1)
			inv:add_item("main", sword)
		else
			minetest.log("warning", "kit3: invalid sword item")
		end
		if trident and not trident:is_empty() then
			trident = safe_enchant(trident, "curse_of_vanishing", 1)
			trident = safe_enchant(trident, "loyalty", 3)
			trident = safe_enchant(trident, "impaling", 2)
			inv:add_item("main", trident)
		else
			minetest.log("warning", "kit3: invalid trident item")
		end

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Spearman Kit!")

	elseif fields.kit4 then
		give_armor(inv, {
			"mcl_armor:helmet_iron",
			"mcl_armor:chestplate_diamond",
			"mcl_armor:leggings_diamond",
			"mcl_armor:boots_diamond"
		}, 1, 1)

		local sword = ItemStack("mcl_tools:sword_iron")
		if sword and not sword:is_empty() then
			sword = safe_enchant(sword, "sharpness", 2) -- Sharpness II
			sword = safe_enchant(sword, "curse_of_vanishing", 1)
			inv:add_item("main", sword)
		else
			minetest.log("warning", "kit4: invalid sword item")
		end

		local bow = ItemStack("mcl_bows:bow")
		if bow and not bow:is_empty() then
			bow = safe_enchant(bow, "curse_of_vanishing", 1)
			bow = safe_enchant(bow, "power", 2)
			inv:add_item("main", bow)
		else
			minetest.log("warning", "kit4: invalid bow item")
		end

		inv:add_item("main", ItemStack("mcl_bows:arrow 20"))

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Archer Kit!")

	elseif fields.kit_warrior then
		local armor_names = {
			"mcl_armor:helmet_diamond",
			"mcl_armor:chestplate_diamond",
			"mcl_armor:leggings_diamond",
			"mcl_armor:boots_diamond"
		}
		if inv:get_list("armor") == nil then
			inv:set_list("armor", { ItemStack(""), ItemStack(""), ItemStack(""), ItemStack("") })
		end
		for _, aname in ipairs(armor_names) do
			local stack = ItemStack(aname)
			if stack and not stack:is_empty() then
				stack = safe_enchant(stack, "protection", 2) -- Protection II
				stack = safe_enchant(stack, "curse_of_vanishing", 1) -- Curse of Vanishing I
				if aname:find("helmet") then
					inv:set_stack("armor", 4, stack)
				elseif aname:find("chestplate") then
					inv:set_stack("armor", 2, stack)
				elseif aname:find("leggings") then
					inv:set_stack("armor", 3, stack)
				elseif aname:find("boots") then
					inv:add_item("main", stack)
				end
			else
				minetest.log("warning", "kit_warrior: invalid armor item '" .. tostring(aname) .. "'")
			end
		end

		local sword = ItemStack("mcl_tools:sword_diamond")
		if sword and not sword:is_empty() then
			sword = safe_enchant(sword, "sharpness", 2) -- Sharpness II
			sword = safe_enchant(sword, "curse_of_vanishing", 1) -- Curse of Vanishing I
			inv:add_item("main", sword)
		else
			minetest.log("warning", "kit_warrior: invalid sword item")
		end

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Heavy Kit!")

	elseif fields.kit6 then
		if inv:get_list("armor") == nil then
			inv:set_list("armor", { ItemStack(""), ItemStack(""), ItemStack(""), ItemStack("") })
		end

		give_armor(inv, {
			"mcl_armor:helmet_diamond",
			"mcl_armor:chestplate_iron",
			"mcl_armor:leggings_diamond",
			"mcl_armor:boots_diamond"
		}, 1, 1)

		local axe = ItemStack("mcl_tools:axe_diamond")
		if axe and not axe:is_empty() then
			axe = safe_enchant(axe, "sharpness", 2)
			axe = safe_enchant(axe, "curse_of_vanishing", 1)
			inv:add_item("main", axe)
		else
			minetest.log("warning", "kit6: invalid axe item")
		end

		player:set_pos(tp)
		minetest.chat_send_player(player_name, "You have selected the Barbarian Kit!")
	
	
	elseif fields.kit_crossbow_man then
	give_armor(inv, {
		"mcl_armor:helmet_diamond",
		"mcl_armor:chestplate_diamond",
		"mcl_armor:leggings_iron",
		"mcl_armor:boots_iron"
	}, 2, 1) -- Protection II for diamond, Protection I for iron

	-- Add a diamond sword
	local sword = ItemStack("mcl_tools:sword_diamond")
	sword = safe_enchant(sword, "sharpness", 2) -- Sharpness II
	sword = safe_enchant(sword, "curse_of_vanishing", 1)
	inv:add_item("main", sword)

	-- Add a crossbow with Piercing II and Quick Charge I
	local crossbow = ItemStack("mcl_bows:crossbow")
	crossbow = safe_enchant(crossbow, "piercing", 2)
	crossbow = safe_enchant(crossbow, "quick_charge", 1)
	inv:add_item("main", crossbow)

	player:set_pos(tp)
	minetest.chat_send_player(player_name, "You have selected the Crossbow Man Kit!")
	inv:add_item("main", ItemStack("mcl_bows:arrow 20"))
	
	end


	if fields.exit then
		minetest.chat_send_player(player_name, "Exiting kit selection.")
	end
end)
