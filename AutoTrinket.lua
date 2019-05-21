Trinkets = {}
Enabled = true

local SWITCH_COOLDOWN = 31
local MAX_COOLDOWN_GAP = 2

local function print(text)
    DEFAULT_CHAT_FRAME:AddMessage(text)
end

local function TableFind(table, text)
    for _, value in ipairs(table) do
        if value == text then
            return true
        end
    end
    return false
end

local function GetTrinkets() 
	local playerName = UnitName"player"
	local trinkets = Trinkets[playerName]
	if not Trinkets[playerName] then 
		trinkets = {}
		Trinkets[playerName] = trinkets
	end 
	return trinkets
end 

function AutoTrinket_OnLoad()
	SLASH_AutoTrinket1 = "/at"
    SlashCmdList["AutoTrinket"] = AutoTrinket_Main

	print("|cFFFF962F AutoTrinket |rLoaded, write |cFF00FF00/at|r for options")

	-- this:RegisterEvent("PLAYER_TARGET_CHANGED")
	this:RegisterEvent("PLAYER_LEAVE_COMBAT")
end 

function AutoTrinket_OnEvent(event, arg1)
	if not Enabled then return end 

	if event == "PLAYER_LEAVE_COMBAT" then
		-- print("|cFFFF962F AutoTrinket |rOut of combat")
		AutoTrinket_Switch()
	end
end

function AutoTrinket_OnUpdate()
end

local function GetCooldown(start, duration, enabled) 
	local cd = 0
	if enabled == 1 and start > 0 then 
		local now = GetTime()
		local elapsed = now - start 
		cd = duration - elapsed
	end 
	return cd
end 

local function GetCooldowns(trinkets)
	local result = {}

	-- search equipped trinkets
	for slot = 13, 14 do 
		local start, duration, enabled = GetInventoryItemCooldown("player", slot)
		local link = GetInventoryItemLink("player", slot)
		if TableFind(trinkets, link) then 
			local cd = GetCooldown(start, duration, enabled)
			result[link] = {
				link = link,
				cd = cd,
				loc = "equ",
				hascd = enabled
			}
		end 
	end

	-- search bags
	for bag = 0,4 do
	  	for slot = 1, GetContainerNumSlots(bag) do
			local link = GetContainerItemLink(bag, slot)
			if link and TableFind(trinkets, link) then
				local start, duration, enabled = GetContainerItemCooldown(bag, slot)
				local cd = GetCooldown(start, duration, enabled)
				result[link] = {
					link = link,
					cd = cd,
					loc = "bag",
					hascd = enabled,
					bag = bag,
					slot = slot
				}
			end
		end
	end

	return result 
end

local function SortTrinketCooldown(trinkets, cooldowns) 
	local sorted = {}
    for _, link in ipairs(trinkets) do
        table.insert(sorted, cooldowns[link])
	end
	return sorted
end 

local function SwitchTrinkets(invSlot, equipped, replacement, bag, slot, simunate) 
	print("|cFFFF962F AutoTrinket |rReplacing equipped " .. equipped .. " with " .. replacement .. " in bag " .. bag .. " slot " .. slot)
	if not simunate then 
		PickupContainerItem(bag, slot)
		PickupInventoryItem(invSlot)
		PickupContainerItem(bag, slot)
	end 
	return equipped, replacement
end 

local function GetReplacementTrinket(cooldowns, sorted, invSlot, simunate)
	local equipped = GetInventoryItemLink("player", invSlot)
	if not equipped then return end 

	local meta = cooldowns[equipped]
	if meta and (meta.hascd == 0 or meta.cd > SWITCH_COOLDOWN) then 
		for _, smeta in ipairs(sorted) do
			if smeta.loc == "bag" and smeta.cd < SWITCH_COOLDOWN then
				return SwitchTrinkets(invSlot, equipped, smeta.link, smeta.bag, smeta.slot, simunate)
			end 
		end
		-- didn't find a trinket with CD less than the 30 seconds switch cooldown, look for a trinket with a smaller c/d
		for _, smeta in ipairs(sorted) do
			if smeta.loc == "bag" and smeta.cd < meta.cd - MAX_COOLDOWN_GAP then
				return SwitchTrinkets(invSlot, equipped, smeta.link, smeta.bag, smeta.slot, simunate)
			end 
		end
	end  
end

local function PrintSorted(sorted) 
	for _, obj in ipairs(sorted) do
		if obj.cd > 0 then 
			print("|cFFFF962F AutoTrinket |r  " .. obj.loc .. " " .. obj.link .. " " .. obj.cd .. " sec")
		else 
			print("|cFFFF962F AutoTrinket |r  " .. obj.loc .. " " .. obj.link .. " ready (has cd " .. obj.hascd .. ")")
		end 
	end
end 

function AutoTrinket_Switch(simunate) 
	local trinkets = GetTrinkets()
	if table.getn(trinkets) == 0 then return end 

	if CursorHasItem() then -- makes sure user isn't holding something in his cursor
		print("|cFFFF962F AutoTrinket |cFFFF0000Cursor has an item, aborting!")
		return 
	end 
	CloseMerchant() -- makes sure no vendor window is open

	local cooldowns = GetCooldowns(trinkets)
	local sorted = SortTrinketCooldown(trinkets, cooldowns)
	GetReplacementTrinket(cooldowns, sorted, 13, simunate)

	cooldowns = GetCooldowns(trinkets)
	sorted = SortTrinketCooldown(trinkets, cooldowns)
	GetReplacementTrinket(cooldowns, sorted, 14, simunate)

end

function AutoTrinket_Main(msg) 
	local _, _, cmd, arg1 = string.find(string.upper(msg), "([%w]+)%s*(.*)$");
    -- print("|cFFFF962F RaidLogger |rcmd " .. cmd .. " / arg1 " .. arg1)
    if not cmd then
        -- RaidLogger_UpdateRaid()
    elseif  "H" == cmd or "HELP" == cmd then
        print("|cFFFF962F AutoTrinket |rCommands: ")
        print("|cFFFF962F AutoTrinket |r  |cFF00FF00/at|r - help")
        print("|cFFFF962F AutoTrinket |r  |cFF00FF00/at add|r - add currently equipped trinkets to stack")
	elseif  "C" == cmd or "CLEAR" == cmd then
		local playerName = UnitName"player"
		Trinkets[playerName] = {}
		print("|cFFFF962F AutoTrinket |rCleared trinkets.");
	elseif  "SIM" == cmd then
		AutoTrinket_Switch(true)
	elseif  "D" == cmd or "DISABLE" == cmd then
		if Enabled then 
			Enabled = false 
			print("|cFFFF962F AutoTrinket |rDisabled.");
		else 
			print("|cFFFF962F AutoTrinket |rAlready disabled!");
		end 
	elseif  "E" == cmd or "ENABLE" == cmd then
		if Enabled then 
			print("|cFFFF962F AutoTrinket |rAlready enabled!");
		else 
			Enabled = true
			print("|cFFFF962F AutoTrinket |rEnabled.");
		end 
	elseif  "P" == cmd or "PRINT" == cmd then
		local trinkets = GetTrinkets()
		local cooldowns = GetCooldowns(trinkets)
		local sorted = SortTrinketCooldown(trinkets, cooldowns)
		PrintSorted(sorted)	
	elseif  "A" == cmd or "ADD" == cmd then
		local link = GetInventoryItemLink("player", 13)
		local trinkets = GetTrinkets()
		if not TableFind(trinkets, link) then 
			table.insert(trinkets, link)
			print("|cFFFF962F AutoTrinket |rAdding " .. link);
		else 
			print("|cFFFF962F AutoTrinket |rAlready has " .. link);
		end 
		link = GetInventoryItemLink("player", 14)
		if not TableFind(trinkets, link) then 
			table.insert(trinkets, link)
			print("|cFFFF962F AutoTrinket |rAdding " .. link);
		else 
			print("|cFFFF962F AutoTrinket |rAlready has " .. link);
		end 
	end
end 