local L = LibStub("AceLocale-3.0"):GetLocale("CheeseSLSLootTracker", true)
local AceGUI = LibStub("AceGUI-3.0")
local deformat = LibStub("LibDeformat-3.0")

-- get information from CheeseSLSLootTracker

function CheeseSLSLootTracker:OnCommReceived(prefix, message, distribution, sender)
	-- addon disabled? don't do anything
	if not CheeseSLSLootTracker.db.profile.enabled then
	  return
	end

	-- playerName may contain "-REALM"
	sender = strsplit("-", sender)

	local success, d = CheeseSLSLootTracker:Deserialize(message);

	-- every thing else get handled if (if not disabled)
	if not success then
		CheeseSLSLootTracker:Debug("ERROR: " .. distribution .. " message from " .. sender .. ": cannot be deserialized")
		return
	end

	-- ignore commands we don't handle here
	if d["command"] == "BIDDING_START" then return end
	if d["command"] == "BIDDING_STOP" then return end
	if d["command"] == "GOT_ROLL" then return end
	if d["command"] == "GOT_FIX" then return end
	if d["command"] == "GOT_FULL" then return end
	
	if CheeseSLSLootTracker.commUUIDseen[d["uuid"]] then
		CheeseSLSLootTracker:Debug("received comm " .. d["uuid"] .. ": already seen, ignoring " .. d["command"] .. " from " .. sender)
		return
	else
		CheeseSLSLootTracker:Debug("received comm " .. d["uuid"] .. ": " .. d["command"] .. " from " .. sender)
	end

	CheeseSLSLootTracker.commUUIDseen[d["uuid"]] = d["uuid"]

	if d["command"] == "LOOT_QUEUED" then

		local _, itemId, _, _, _, _, _, _, _, _, _, _, _, _ = strsplit(":", d["itemLink"])

		local id = tostring(d["queueTime"]) .. "/" .. tostring(itemId) .. "/" .. tostring(d["playerName"])
		CheeseSLSLootTracker.db.profile.loothistory[id] = {
			uuid = d["uuid"],
			itemId = itemId,
			itemLink = d["itemLink"],
			queueTime = d["queueTime"],
			playerName = d["playerName"]
		}

		-- call asynchronous getItemInfo so it's cached later on
		GetItemInfo(itemId)

		CheeseSLSLootTracker:Debug("incoming LOOT_QUEUED: " .. d["itemLink"] .. " from " .. d["playerName"])

	end

end


-- send out "new" loot to other CheeseSLSLootTracker

function CheeseSLSLootTracker:sendLootQueued(itemLink, playerName, itemCount, queueTime, uuid)
	local queueT = queueTime or time()
	local uu = uuid or CheeseSLSLootTracker:UUID()
	local commmsg = {
		command = "LOOT_QUEUED",
		version = CheeseSLSLootTracker.commVersion,
		uuid = uu,
		itemLink = itemLink,
		queueTime = queueT,
		playerName= playerName,
		itemCount = itemCount 
	}
	CheeseSLSLootTracker:SendCommMessage(CheeseSLSLootTracker.commPrefix, CheeseSLSLootTracker:Serialize(commmsg), "RAID", nil, "BULK")
end

-- to ignore trade windows, which also give the EXACT SAME CHAT_MSG_LOOT. WTF Blizzard.
function CheeseSLSLootTracker:TRADE_SHOW()
	CheeseSLSLootTracker.tradeWindow = true
end
function CheeseSLSLootTracker:TRADE_CLOSED()
	-- give CHAT_MSG_LOOT about 1 second to catch up before assuming it's not a trade anymore
	CheeseSLSLootTracker:ScheduleTimer(function() CheeseSLSLootTracker.tradeWindow = false end, 1)
end


function CheeseSLSLootTracker:CHAT_MSG_LOOT(event, text, sender)
	-- ignore trade window loot
	if CheeseSLSLootTracker.tradeWindow then return end

	-- validation code from MizusRaidTracker, under GPL 3.0, Author Mîzukichan@EU-Antonidas

	-- patterns LOOT_ITEM / LOOT_ITEM_SELF are also valid for LOOT_ITEM_MULTIPLE / LOOT_ITEM_SELF_MULTIPLE - but not the other way around - try these first
	-- first try: somebody else received multiple loot (most parameters)
	local playerName, itemLink, itemCount = deformat(text, LOOT_ITEM_MULTIPLE)

	-- next try: somebody else received single loot
	if (playerName == nil) then
		itemCount = 1
		playerName, itemLink = deformat(text, LOOT_ITEM)
	end

	-- if player == nil, then next try: player received multiple loot
	if (playerName == nil) then
		playerName = UnitName("player")
		itemLink, itemCount = deformat(text, LOOT_ITEM_SELF_MULTIPLE)
	end

	-- if itemLink == nil, then last try: player received single loot
	if (itemLink == nil) then
		itemCount = 1
		itemLink = deformat(text, LOOT_ITEM_SELF)
	end

	-- if itemLink == nil, then there was neither a LOOT_ITEM, nor a LOOT_ITEM_SELF message
	if (itemLink == nil) then
		-- No valid loot event received.
		return
	end

	local d, itemId, enchantId, jewelId1, jewelId2, jewelId3, jewelId4, suffixId, uniqueId, linkLevel, specializationID, reforgeId, unknown1, unknown2 = strsplit(":", itemLink)

    -- check for disenchant mats
	local i = tonumber(itemId)
	if i == 20725 or i == 14344 -- Nexus Crystal / Large Briliant Shard
	or i == 22450 or i == 22449 -- Void Crystal / Large Prismatic Shard
	or i == 34057 or i == 34052 -- Abyss Crystal / Dream Shard
	then
		-- ignore
		return
	end

	-- colors:
	-- if d == "\124cffff8000\124Hitem" then CheeseSLSLootTracker:Print("LEGENDARY") end -- LEGENDARY
	-- if d == "\124cffa335ee\124Hitem" then CheeseSLSLootTracker:Print("Epic") end -- Epic
	-- if d == "\124cff0070dd\124Hitem" then CheeseSLSLootTracker:Print("Rare") end -- Rare
	-- if d == "\124cff1eff00\124Hitem" then CheeseSLSLootTracker:Print("Uncommon") end -- Uncommon
	-- if d == "\124cffffffff\124Hitem" then CheeseSLSLootTracker:Print("Common") end -- Common
	-- if d == "\124cff9d9d9d\124Hitem" then CheeseSLSLootTracker:Print("Trash") end -- Greys

--	if (d == "\124cffff8000\124Hitem") or (d == "\124cffa335ee\124Hitem") then
		local queueT = time()
		local uuid = CheeseSLSLootTracker:UUID()

--		local _, itemId, _, _, _, _, _, _, _, _, _, _, _, _ = strsplit(":", itemLink)
--		local id = tostring(queueT) .. "/" .. tostring(itemId) .. "/" .. tostring(playerName)

--		CheeseSLSLootTracker.db.profile.loothistory[id] = {
--			uuid = uuid,
--			itemId = itemId,
--			itemLink = itemLink,
--			queueTime = queueT,
--			playerName = playerName,
--		}
	
		CheeseSLSLootTracker:sendLootQueued(itemLink, playerName, itemCount, queueT, uuid)
--	end

end
