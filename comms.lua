local L = LibStub("AceLocale-3.0"):GetLocale("CheeseSLSLootTracker", true)
local AceGUI = LibStub("AceGUI-3.0")
local deformat = LibStub("LibDeformat-3.0")

-- get information from CheeseSLSLootTracker


-- will return TRUE for items to be ignored, nil or false for no action
function CheeseSLSLootTracker:determineItemIgnorance(itemId)

	-- call asynchronous getItemInfo so it's cached later on
	-- if we got the data already in cache, even better. But we'll revisit this on showing the GUI

	local itemType, itemSubType, _, _, _, _, itemClassID, itemSubclassID = select(6, GetItemInfo(itemId))

	-- if GetItemInfo ddid not return anything now, we'll not wait for it
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
		DEATHKNIGHT = { 1, 2, 3, 4, 5, 6, 10 },
		DRUID = { 1, 2, 5, 6, 8 },
		HUNTER = { 1, 2, 3, 5 },
		MAGE = { 1, 5 },
		PALADIN = { 1, 2, 3, 4, 5, 6, 7 },
		PRIEST = { 1, 5 },
		ROGUE = { 1, 2, 5 },
		SHAMAN = { 1, 2, 3, 5, 6, 9 },
		WARLOCK = { 1, 5 },
		WARRIOR = { 1, 2, 3, 4, 5, 6 },
	}

	-- Weapon
	if tonumber(itemClassID) == 2 then
		for _,i in pairs(useableWeapons[englishClass]) do
			if tonumber(itemSubclassID) == i then
				-- class can use this, so don't ignore
				return false
			end
		end
		-- no proficiency found for this weapon, so assume it cannot be used
		return true
	end

	-- Armor
	if tonumber(itemClassID) == 4 then
		for _,i in pairs(useableArmor[englishClass]) do
			if tonumber(itemSubclassID) == i then
				-- class can use this, so don't ignore
				return false
			end
		end
		-- no proficiency found for this armor, so assume it cannot be used
		return true
	end
	
	-- not a weapon or armor, so let's not ignore this
	return false

end

function CheeseSLSLootTracker:addLoot(itemLink, playerName, queueTime, uuid)

	local _, itemId, _, _, _, _, _, _, _, _, _, _, _, _ = strsplit(":", itemLink)

	-- item ignorance assessment will call to GetItemInfo(). If we don't get data just get, will be retried when showing the GUI
	local itemIgnorance = CheeseSLSLootTracker:determineItemIgnorance(itemId)
	if itemIgnorance then
		CheeseSLSClient.db.profile.ignorelist[itemId] = time()
	end

	-- avoid doublettes within +-5sec. Yes, this might be a problem if dual items drop, but could only be T tokens anyway.
	local isKnown = false
	for key,val in pairs(CheeseSLSLootTracker.db.profile.loothistory) do
		if tonumber(val["itemId"]) == tonumber(itemId) and tostring(val["playerName"]) == tostring(playerName) then
			if tonumber(val["queueTime"]) <= tonumber(queueTime)+5 and tonumber(val["queueTime"]) >= tonumber(queueTime)-5 then
				CheeseSLSLootTracker:Debug("Asked to queue loot but found this item already as " .. val["uuid"])
				isKnown = true
			end
		end
	end

	if not isKnown then
		local id = tostring(queueTime) .. "/" .. tostring(itemId) .. "/" .. tostring(playerName)
		CheeseSLSLootTracker.db.profile.loothistory[id] = {
			uuid = uuid,
			itemId = itemId,
			itemLink = itemLink,
			queueTime = queueTime,
			playerName = playerName
		}
		CheeseSLSLootTracker:Debug("incoming LOOT_QUEUED: " .. tostring(itemLink) .. " from " .. tostring(playerName))
	end

end


function CheeseSLSLootTracker:OnCommReceived(prefix, message, distribution, sender)
	-- addon disabled? don't do anything
	if not CheeseSLSLootTracker.db.profile.enabled then
		return
	end

	-- playerName may contain "-REALM"
	sender = strsplit("-", sender)

	local success, d = CheeseSLSLootTracker:Deserialize(message)

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

	-- avoid doublettes (was a debug problem, sending to RAID and GUILD, but let's leave it in)
	if CheeseSLSLootTracker.commUUIDseen[d["uuid"]] then
		CheeseSLSLootTracker:Debug("received comm " .. d["uuid"] .. ": already seen, ignoring " .. d["command"] .. " from " .. sender)
		return
	else
		CheeseSLSLootTracker:Debug("received comm " .. d["uuid"] .. ": " .. d["command"] .. " from " .. sender)
	end

	CheeseSLSLootTracker.commUUIDseen[d["uuid"]] = d["uuid"]

	if d["command"] == "LOOT_QUEUED" then
		CheeseSLSLootTracker:addLoot(d["itemLink"], d["playerName"], d["queueTime"], d["uuid"])
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

	if (CheeseSLSLootTracker.db.profile.debuggingTrash) or (d == "\124cffff8000\124Hitem") or (d == "\124cffa335ee\124Hitem") then
		local queueT = time()
		local uuid = CheeseSLSLootTracker:UUID()

		CheeseSLSLootTracker:addLoot(itemLink, playerName, queueT, uuid)

		CheeseSLSLootTracker:sendLootQueued(itemLink, playerName, itemCount, queueT, uuid)
	end

end
