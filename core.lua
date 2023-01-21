local L = LibStub("AceLocale-3.0"):GetLocale("CheeseSLSLootTracker", true)

CheeseSLSLootTracker.commPrefix = "CheeseSLS-1.0-"
CheeseSLSLootTracker.commVersion = 20221103

CheeseSLSLootTracker.commPrefixGSDKP = "GSDKPCSLS-1"

local defaults = {
	profile = {
		debugging = false,
		debuggingTrash = false,
		limittwohour = true,
		deletetwohour = true,
		autoignoreunwearable = true,
	}
}

CheeseSLSLootTracker.optionsTable = {
	type = "group",
	args = {
		debugging = {
			order = 20,
			name = L["Debug"],
			desc = L["Debug"],
			type = "toggle",
			set = function(info,val)
				CheeseSLSLootTracker.db.profile.debugging = val
			end,
			get = function(info) return CheeseSLSLootTracker.db.profile.debugging end,
		},
		debuggingTrash = {
			order = 25,
			name = L["Track Trash"],
			desc = L["Track Trash items for debugging"],
			type = "toggle",
			set = function(info,val)
				CheeseSLSLootTracker.db.profile.debuggingTrash = val
			end,
			get = function(info) return CheeseSLSLootTracker.db.profile.debuggingTrash end,
		},
		newline29 = { name="", type="description", order=29 },

		limit2hours = {
			order = 30,
			name = L["2 hr view limit"],
			desc = L["Limit shown loot to two hours (tradeable time window)"],
			type = "toggle",
			set = function(info,val)
				CheeseSLSLootTracker.db.profile.limittwohour = val
			end,
			get = function(info) return CheeseSLSLootTracker.db.profile.limittwohour end,
		},
		delete2hours = {
			order = 35,
			name = L["2 hr deletion"],
			desc = L["Delete loot older than two hours (tradeable time window) from tracker"],
			type = "toggle",
			set = function(info,val)
				CheeseSLSLootTracker.db.profile.deletetwohour = val
			end,
			get = function(info) return CheeseSLSLootTracker.db.profile.deletetwohour end,
		},
		newline39 = { name="", type="description", order=39 },

		autoignore = {
			order = 40,
			name = L["Auto Ignore"],
			desc = L["Automatically ignore unwearable items (e.g. plate for cloth classes or wands for meelees)"],
			type = "toggle",
			set = function(info,val)
				CheeseSLSLootTracker.db.profile.autoignoreunwearable = val
			end,
			get = function(info) return CheeseSLSLootTracker.db.profile.autoignoreunwearable end,
		},
		newline49 = { name="", type="description", order=49 },

		numberloot = {
			order = 100,
			name = L["# loot items"],
			desc = L["Number of loot items stored in DB"],
			type = "input",
			set = function(info,val) end,
			get = function(info) return tostring(CheeseSLSLootTracker:htlen(CheeseSLSLootTracker.db.profile.loothistory)) end,
		},
		clearloot = {
			order = 105,
			name = L["Clear loot table"],
			desc = L["Clear loot table"],
			type = "execute",
			confirm = true,
			func = function(info) CheeseSLSLootTracker.db.profile.loothistory = {} end,
		},
		sendall = {
			order = 110,
			name = L["Send loot table"],
			desc = L["Send loot table to all other players"],
			type = "execute",
			confirm = true,
			func = function(info)
				for k,v in pairs(CheeseSLSLootTracker.db.profile.loothistory) do
					CheeseSLSLootTracker:sendLootQueued(v["itemLink"], v["playerName"], 1, v["queueTime"], v["uuid"])
				end
			end,
		},
		newline119 = { name="", type="description", order=119 },

	} -- args
}

function CheeseSLSLootTracker:OnInitialize()
	-- Code that you want to run when the addon is first loaded goes here.
	CheeseSLSLootTracker.db = LibStub("AceDB-3.0"):New("CheeseSLSLootTrackerDB", defaults)

	LibStub("AceConfig-3.0"):RegisterOptionsTable("CheeseSLSLootTracker", CheeseSLSLootTracker.optionsTable)
	CheeseSLSLootTracker.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("CheeseSLSLootTracker", "CheeseSLSLootTracker")

	-- prepare list

	if CheeseSLSLootTracker.db.profile.loothistory == nil then
		CheeseSLSLootTracker.db.profile.loothistory = {}
	end

	-- trigger GetItemInfo for all items in database
	-- if you had disconnect / relog, cache needs to be rebuild to avoid having to handle GET_ITEM_INFO_RECEIVED stuff at Boss announcements
	-- so better to load it here. But only once per itemid.
	local itemIdList = {}
	for _, hst in pairs(CheeseSLSLootTracker.db.profile.loothistory) do
		itemIdList[tonumber(hst["itemId"])] = tonumber(hst["itemId"])
	end
	for itemid,id2 in pairs(itemIdList) do
		GetItemInfo(itemid)
	end

	if not CheeseSLSLootTracker.db.profile.alreadyStarted then CheeseSLSLootTracker.db.profile.alreadyStarted = {} end

	-- clean up old "rolled for" entries
	-- won't show button for anything older than 2 hours anyway
	if CheeseSLSLootTracker.db.profile.alreadyStarted then
		local twohoursago = time() - 2*60*60
		for key,val in pairs(CheeseSLSLootTracker.db.profile.alreadyStarted) do
			if val < twohoursago then
				CheeseSLSLootTracker.db.profile.alreadyStarted[key] = nil
			end
		end
	end

	-- session tables for later
	CheeseSLSLootTracker.commUUIDseen = {}
	CheeseSLSLootTracker.winnerLabels = {}
	CheeseSLSLootTracker.bookedButtons = {}
	CheeseSLSLootTracker.lootTrackFrameButtons = {}

	CheeseSLSLootTracker.GetItemInfoQueue = {}

	CheeseSLSLootTracker:Print("CheeseSLSLootTracker loaded.")
end

function CheeseSLSLootTracker:OnEnable()
	-- Called when the addon is enabled
	CheeseSLSLootTracker:RegisterChatCommand("cslsloot", "ChatCommand")
	CheeseSLSLootTracker:RegisterChatCommand("slsloot", "ChatCommand");

	CheeseSLSLootTracker:RegisterComm(CheeseSLSLootTracker.commPrefix, "OnCommReceived")
	CheeseSLSLootTracker:RegisterComm(CheeseSLSLootTracker.commPrefixGSDKP, "OnCommReceivedGSDKP")

	CheeseSLSLootTracker:RegisterEvent("CHAT_MSG_LOOT")

	-- CheeseSLSLootTracker:RegisterEvent("LOOT_OPENED")
	-- CheeseSLSLootTracker:RegisterEvent("LOOT_CLOSED") -- from wowpedia: Note that this will fire before the last CHAT_MSG_LOOT event for that loot.

	-- CheeseSLSLootTracker:RegisterEvent("START_LOOT_ROLL")
	-- CheeseSLSLootTracker:RegisterEvent("LOOT_ROLLS_COMPLETE") -- so most likely this could as well be before last CHAT_MSG_LOOT

	-- use only TRADE for now, to be ignored. I don't care which kind of Loot it actually was
	CheeseSLSLootTracker:RegisterEvent("TRADE_SHOW")
	CheeseSLSLootTracker:RegisterEvent("TRADE_CLOSED") -- so most likely this could as well be before last CHAT_MSG_LOOT

	CheeseSLSLootTracker:RegisterEvent("GET_ITEM_INFO_RECEIVED")
end

function CheeseSLSLootTracker:OnDisable()
	-- Called when the addon is disabled
end

local function strlt(s)
	return strlower(strtrim(s))
end

function CheeseSLSLootTracker:ChatCommand(inc)

	if strlt(inc) == "config" then
		LibStub("AceConfigDialog-3.0"):Open("CheeseSLSLootTracker")
		return nil

	elseif strlt(inc) == "" then

		CheeseSLSLootTracker:createLootTrackFrame()

	elseif strlt(inc) == "debug" then
		CheeseSLSLootTracker.db.profile.debugging = not CheeseSLSLootTracker.db.profile.debugging
		if CheeseSLSLootTracker.db.profile.debugging then
			CheeseSLSLootTracker:Print("CheeseSLSLootTracker DEBUGGING " .. L["is enabled."])
		else
			CheeseSLSLootTracker:Print("CheeseSLSLootTracker DEBUGGING " .. L["is disabled."])
		end

	elseif strlt(inc:sub(0,5)) == "debug" then
		local itemLink = inc:sub(6)
		local playerName = UnitName("player")
		CheeseSLSLootTracker:receiveLoot(itemLink, playerName)

	end

end


function CheeseSLSLootTracker:CacheTradeableInventoryPosition()
	CheeseSLSLootTracker.inventory = {}

	local tip = CreateFrame("GameTooltip","Tooltip",nil,"GameTooltipTemplate")

	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
		
			local item = C_Container.GetContainerItemInfo(bag, slot)
			if item then
				tip:SetOwner(UIParent, "ANCHOR_NONE")
				tip:SetBagItem(bag, slot)
				tip:Show()
	
--				data = C_TooltipInfo.GetBagItem(bag, slot)
				
				for i = 1,tip:NumLines() do
					if (string.find(_G["TooltipTextLeft"..i]:GetText(), ITEM_BIND_ON_EQUIP)) then
						-- is BoE
						CheeseSLSLootTracker.inventory[tonumber(item["itemID"])] = { bag = bag, slot = slot }
					elseif (string.find(_G["TooltipTextLeft"..i]:GetText(), string.format(BIND_TRADE_TIME_REMAINING, ".*"))) then
						-- is tradeable (within timer)
						CheeseSLSLootTracker.inventory[tonumber(item["itemID"])] = { bag = bag, slot = slot }
					end
				end
				tip:Hide()
			end
		end
	end

end

function CheeseSLSLootTracker:TRADE_SHOW()
	-- to ignore trade windows, which also give the EXACT SAME CHAT_MSG_LOOT. WTF Blizzard.
	CheeseSLSLootTracker.tradeWindow = true

    -- if we have a winner, put winnings in trade window
	local tradePartner = GetUnitName("NPC", true)

	-- no trade partner found? then I wouldn't put anything in
	if not tradePartner then return end

	-- tradePartner may contain "-REALM"
	tradePartner = strsplit("-", tradePartner)

	-- find items won by trade partner
	local loots = {}

	-- ignore items older than 2 hours. BoP is not tradeable anymore
	-- yes, this will exclude BoE, but they are mostly auctioned off with the other loot anyway
	-- and in doubt, you'd have to do it by hand - just as years before this change ;)
	local twohoursago = time() - 2*60*60

	for historyid,loot in pairs(CheeseSLSLootTracker.db.profile.loothistory) do
		-- check if still tradeable anyway
		if tonumber(loot["queueTime"]) >= twohoursago then
			if loot["winner"] == tradePartner then
				loots[historyid] = loot
			end
		end
	end

	CheeseSLSLootTracker.lastloots = loots

	if loots then
		CheeseSLSLootTracker:CacheTradeableInventoryPosition()

		for history,loot in pairs(loots) do
			local itemLink = loot["itemLink"]
			local _, itemId, _, _, _, _, _, _, _, _, _, _, _, _ = strsplit(":", itemLink)

			if CheeseSLSLootTracker.inventory[tonumber(itemId)] then
				local inv = CheeseSLSLootTracker.inventory[tonumber(itemId)]
				CheeseSLSLootTracker:Debug("Trading " .. itemLink .. " (" .. tostring(itemId) .. ") from inventory " .. tostring(inv["bag"]) .. "/" .. tostring(inv["slot"]) .. " to " .. loot["winner"])
				ClearCursor()
				C_Container.PickupContainerItem(inv["bag"], inv["slot"])
				local tradePos = TradeFrame_GetAvailableSlot()
				if tradePos ~= nil then
					ClickTradeButton(tradePos)
				end
			end
		end

	end

end

function CheeseSLSLootTracker:TRADE_CLOSED()
	-- give CHAT_MSG_LOOT about 1 second to catch up before assuming it's not a trade anymore
	CheeseSLSLootTracker:ScheduleTimer(function() CheeseSLSLootTracker.tradeWindow = false end, 1)
end


-- helper function: hash table length
function CheeseSLSLootTracker:htlen(ht)
	if ht == nil then return nil end
	local keyset={}
	for key,val in pairs(ht) do
		tinsert(keyset, key)
	end
	return #keyset
end

-- for debug outputs
local function tprint (tbl, indent)
  if not indent then indent = 0 end
  local toprint = string.rep(" ", indent) .. "{\r\n"
  indent = indent + 2
  for k, v in pairs(tbl) do
    toprint = toprint .. string.rep(" ", indent)
    if (type(k) == "number") then
      toprint = toprint .. "[" .. k .. "] = "
    elseif (type(k) == "string") then
      toprint = toprint  .. k ..  "= "
    end
    if (type(v) == "number") then
      toprint = toprint .. v .. ",\r\n"
    elseif (type(v) == "string") then
      toprint = toprint .. "\"" .. v .. "\",\r\n"
    elseif (type(v) == "table") then
      toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
    else
      toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
    end
  end
  toprint = toprint .. string.rep(" ", indent-2) .. "}"
  return toprint
end

function CheeseSLSLootTracker:Debug(t)
	if (CheeseSLSLootTracker.db.profile.debugging) then
		if type(t) == "table" then
			CheeseSLSLootTracker:Print("CheeseSLSLootTracker DEBUG: " .. tprint(t))
		else
			CheeseSLSLootTracker:Print("CheeseSLSLootTracker DEBUG: " .. t)
		end
	end
end


-- derived from https://github.com/anders/luabot-scripts/blob/master/etc/UUID.lua, under Eclipse Public License 1.0 (minor adjustments for WoW usage)
function CheeseSLSLootTracker:UUID()
	local chars = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"}
	local uuid = {[9]="-",[14]="-",[15]="4",[19]="-",[24]="-"}
	local r, index
	for i = 1,36 do
		if(uuid[i]==nil)then
			-- r = 0 | Math.random()*16;
			r = random (16)
			if(i == 20)then
				-- bits 1+2 of pos 20 are "10". bin1000 = dec8. 2-bits are 0-3
				index = random(0,3) + 8
			else
				index = r
			end
			uuid[i] = chars[index]
		end
	end
	return table.concat(uuid)
end


-- async handling of cached item infos
function CheeseSLSLootTracker:GET_ITEM_INFO_RECEIVED(event, itemId, success)
	if next(CheeseSLSLootTracker.GetItemInfoQueue) == nil then
		-- GetItemInfoQueue is empty, no need to listen anymore
		CheeseSLSLootTracker:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
		return
	end

	if (CheeseSLSLootTracker.GetItemInfoQueue[itemId]) then
		for _,q in pairs(CheeseSLSLootTracker.GetItemInfoQueue[itemId]) do
			if type(q["callback"]) == "function" then
				-- direct function reference, call it
				q["callback"](q["param1"], q["param2"], q["param3"])
			else
				-- string of function name, use from global namespace
				if _G[q["callback"]] then
					_G[q["callback"]](q["param1"], q["param2"], q["param3"])
				end
			end
		end
		CheeseSLSLootTracker.GetItemInfoQueue[itemId] = nil
	end

	-- is empty now?
	if next(CheeseSLSLootTracker.GetItemInfoQueue) == nil then
		-- GetItemInfoQueue is empty, no need to listen anymore
		CheeseSLSLootTracker:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
		return
	end
end


function CheeseSLSLootTracker:QueueGetItemInfo(itemId, callback, param1, param2, param3)
	if CheeseSLSLootTracker.GetItemInfoQueue[itemId] == nil then
		CheeseSLSLootTracker.GetItemInfoQueue[itemId] = {}
	end

	-- call GetItemInfo and see if it might be already cached - most likely we won't see a GET_ITEM_INFO_RECEIVED for that then
	local itemName, itemLink, _ = GetItemInfo(itemId)
	if itemLink == nil then

		-- need to wait for event
		CheeseSLSLootTracker:RegisterEvent("GET_ITEM_INFO_RECEIVED")

		local t = {
			callback = callback,
			param1 = param1,
			param2 = param2,
			param3 = param3,
		}
		tinsert(CheeseSLSLootTracker.GetItemInfoQueue[itemId], t)

	else
		-- item Link exists, GetItemInfo is already cached

		if type(callback) == "function" then
			-- direct function reference, call it
			callback(param1, param2, param3)
		else
			-- string of function name, use from global namespace
			if _G[callback] then
				_G[callback](param1, param2, param3)
			end
		end
	end
end


-- will return TRUE for items to be ignored, nil or false for no action
function CheeseSLSLootTracker:determineItemIgnorance(itemId)

	-- if we are not auto-ignoring, we will allow (= NOT ignore) all items
	if not CheeseSLSLootTracker.db.profile.autoignoreunwearable then return false end

	-- call asynchronous getItemInfo so it's cached later on
	-- if we got the data already in cache, even better. But we'll revisit this on showing the GUI

	local itemName, _, _, _, _, itemType, itemSubType, _, _, _, _, itemClassID, itemSubclassID, _, _, _, _ = GetItemInfo(itemId)

	-- if GetItemInfo did not return anything now, we'll not wait for it
	if not itemClassID then return nil end

	-- itemType and itemSubType: Be aware that the strings are localized on the clients.
	-- so we use IDs as per https://wowpedia.fandom.com/wiki/ItemType

	local localizedClass, englishClass, classIndex = UnitClass("player")

	-- Usable weapons
	-- from https://wowpedia.fandom.com/wiki/ItemType#2:_Weapon and https://wowwiki-archive.fandom.com/wiki/Class_proficiencies
	local useableWeapons = {
		DEATHKNIGHT = { 0,1, 7,8, 4,5, 6 },
		DRUID = { 4,5, 6, 10, 15, 13 },
		HUNTER = { 0,1, 7,8, 6, 10, 15, 13, 2, 18, 3 },
		MAGE = { 7, 10, 15, 19 },
		PALADIN = { 0,1, 7,8, 4,5, 6 },
		PRIEST = { 4, 10, 15, 19 },
		ROGUE = { 0, 7, 4, 15, 13, 2, 18, 3, 16 },
		SHAMAN = { 0,1, 4,5, 10, 15, 13 },
		WARLOCK = { 7, 10, 15, 19 },
		WARRIOR = { 0,1, 7,8, 4,5, 6, 10, 15, 13, 2, 18, 3, 16 },
	}

	-- Useable armor
	local useableArmor = {
		DEATHKNIGHT = { 0, 1, 2, 3, 4, 5, 6, 10 },
		DRUID = { 0, 1, 2, 5, 6, 8 },
		HUNTER = { 0, 1, 2, 3, 5 },
		MAGE = { 0, 1, 5 },
		PALADIN = { 0, 1, 2, 3, 4, 5, 6, 7 },
		PRIEST = { 0, 1, 5 },
		ROGUE = { 0, 1, 2, 5 },
		SHAMAN = { 0, 1, 2, 3, 5, 6, 9 },
		WARLOCK = { 0, 1, 5 },
		WARRIOR = { 0, 1, 2, 3, 4, 5, 6 },
	}

	-- Weapon
	if tonumber(itemClassID) == 2 then
		for _,i in pairs(useableWeapons[englishClass]) do
			if tonumber(itemSubclassID) == i then
				-- class can use this, so don't ignore
				CheeseSLSLootTracker:Debug("Accepting " .. itemName .. " (" .. itemClassID .. "/" .. itemSubclassID .. ") because it's a usable WEAPON for " .. englishClass)
				return false
			end
		end
		-- no proficiency found for this weapon, so assume it cannot be used
		CheeseSLSLootTracker:Debug("Ignoring " .. itemName .. " (" .. itemClassID .. "/" .. itemSubclassID .. ") because it's not listed as wearable WEAPON for " .. englishClass)
		return true
	end

	-- Armor
	if tonumber(itemClassID) == 4 then
		for _,i in pairs(useableArmor[englishClass]) do
			if tonumber(itemSubclassID) == i then
				-- class can use this, so don't ignore
				CheeseSLSLootTracker:Debug("Accepting " .. itemName .. " (" .. itemClassID .. "/" .. itemSubclassID .. ") because it's a usable ARMOR for " .. englishClass)
				return false
			end
		end
		-- no proficiency found for this armor, so assume it cannot be used
		CheeseSLSLootTracker:Debug("Ignoring " .. itemName .. " (" .. itemClassID .. "/" .. itemSubclassID .. ") because it's not listed as wearable ARMOR for " .. englishClass)
		return true
	end

	-- not a weapon or armor, so let's not ignore this
	CheeseSLSLootTracker:Debug("Accepting " .. itemName .. " (" .. itemClassID .. "/" .. itemSubclassID .. ") because it's neither WEAPON nor ARMOR")
	return false

end