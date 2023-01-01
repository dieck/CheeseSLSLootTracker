local L = LibStub("AceLocale-3.0"):GetLocale("CheeseSLSLootTracker", true)
local AceGUI = LibStub("AceGUI-3.0")
local deformat = LibStub("LibDeformat-3.0")

-- get information from CheeseSLSLootTracker


function CheeseSLSLootTracker:addLoot(itemLink, playerName, queueTime, uuid, winner)

	local _, itemId, _, _, _, _, _, _, _, _, _, _, _, _ = strsplit(":", itemLink)

	-- item ignorance assessment will call to GetItemInfo(). If we don't get data just get, will be retried when showing the GUI
	local itemIgnorance = CheeseSLSLootTracker:determineItemIgnorance(itemId)
	if itemIgnorance then
		if CheeseSLSClient.db.profile.notificationHandling[tonumber(itemId)] == nil then
			CheeseSLSClient.db.profile.notificationHandling[tonumber(itemId)] = "IGNORE"
		end
	end

	-- avoid doublettes within +-5sec. Yes, this might be a problem if dual items drop, but could only be T tokens anyway.
	local isKnown = false
	for key,val in pairs(CheeseSLSLootTracker.db.profile.loothistory) do
		if tonumber(val["itemId"]) == tonumber(itemId) and tostring(val["playerName"]) == tostring(playerName) then
			if tonumber(val["queueTime"]) <= tonumber(queueTime)+5 and tonumber(val["queueTime"]) >= tonumber(queueTime)-5 then
				CheeseSLSLootTracker:Debug("Asked to queue loot but found this item already as " .. val["uuid"])

				-- if times to not match exactly, re-book item later (so all will match everywhere)
				if tonumber(val["queueTime"]) ~= tonumber(queueTime) then isKnown = key end
			end
		end
	end

	local id = tostring(queueTime) .. "/" .. tostring(itemId) .. "/" .. tostring(playerName)
	CheeseSLSLootTracker.db.profile.loothistory[id] = {
		uuid = uuid,
		itemId = itemId,
		itemLink = itemLink,
		queueTime = queueTime,
		playerName = playerName,
		winner = winner
	}

	-- remove loot if it was previously known (overwritten with new id, so all are the same around synced addons)
	if isKnown then
		CheeseSLSLootTracker.db.profile.loothistory[isKnown] = nil
	end

	CheeseSLSLootTracker:Debug("incoming LOOT_QUEUED: " .. tostring(itemLink) .. " from " .. tostring(playerName))

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

	if d["command"] == "LOOT_QUEUED" then
		-- avoid doublettes (was a debug problem, sending to RAID and GUILD, but let's leave it in)
		if CheeseSLSLootTracker.commUUIDseen[d["uuid"]] then
			CheeseSLSLootTracker:Debug("received comm " .. d["uuid"] .. ": already seen, ignoring " .. d["command"] .. " from " .. sender)
			return
		else
			CheeseSLSLootTracker:Debug("received comm " .. d["uuid"] .. ": " .. d["command"] .. " from " .. sender)
		end

		CheeseSLSLootTracker.commUUIDseen[d["uuid"]] = d["uuid"]

		CheeseSLSLootTracker:addLoot(d["itemLink"], d["playerName"], d["queueTime"], d["uuid"])
	end

	if d["command"] == "WINNING_NOTIFICATION" then
		if CheeseSLSLootTracker.db.profile.loothistory[d["lootTrackerId"]] then
			CheeseSLSLootTracker.db.profile.loothistory[d["lootTrackerId"]]["winner"] = d["winner"]
		end
		-- update label if available
		if CheeseSLSLootTracker.winnerLabels[d["lootTrackerId"]] then CheeseSLSLootTracker.winnerLabels[d["lootTrackerId"]]:SetText(d["winner"]) end
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

	CheeseSLSLootTracker:receiveLoot(itemLink, playerName, itemCount)

end

function CheeseSLSLootTracker:receiveLoot(itemLink, playerName, itmCount)
	local itemCount = itmCount or 1
	local d, itemId, enchantId, jewelId1, jewelId2, jewelId3, jewelId4, suffixId, uniqueId, linkLevel, specializationID, reforgeId, unknown1, unknown2 = strsplit(":", itemLink)

	-- colors:
	-- if d == "\124cffff8000\124Hitem" then CheeseSLSLootTracker:Print("LEGENDARY") end -- LEGENDARY
	-- if d == "\124cffa335ee\124Hitem" then CheeseSLSLootTracker:Print("Epic") end -- Epic
	-- if d == "\124cff0070dd\124Hitem" then CheeseSLSLootTracker:Print("Rare") end -- Rare
	-- if d == "\124cff1eff00\124Hitem" then CheeseSLSLootTracker:Print("Uncommon") end -- Uncommon
	-- if d == "\124cffffffff\124Hitem" then CheeseSLSLootTracker:Print("Common") end -- Common
	-- if d == "\124cff9d9d9d\124Hitem" then CheeseSLSLootTracker:Print("Trash") end -- Greys

	if (CheeseSLSLootTracker.db.profile.debugging and CheeseSLSLootTracker.db.profile.debuggingTrash) or (d == "\124cffff8000\124Hitem") or (d == "\124cffa335ee\124Hitem") then
		local queueT = time()
		local uuid = CheeseSLSLootTracker:UUID()

		CheeseSLSLootTracker:addLoot(itemLink, playerName, queueT, uuid)

		CheeseSLSLootTracker:sendLootQueued(itemLink, playerName, itemCount, queueT, uuid)
	end

end
