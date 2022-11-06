local L = LibStub("AceLocale-3.0"):GetLocale("CheeseSLSLootTracker", true)

CheeseSLSLootTracker.commPrefix = "CheeseSLS-1.0-"
CheeseSLSLootTracker.commVersion = 20221103

local defaults = {
	profile = {
		enabled = true,
		debugging = false,
		limittwohour = true,
		deletetwohour = false,
	}
}

CheeseSLSLootTracker.optionsTable = {
	type = "group",
	args = {
		enabled = {
			order = 10,
			name = "Enabled",
			desc = "Enabled",
			type = "toggle",
			set = function(info,val)
				CheeseSLSLootTracker.db.profile.enabled = val
			end,
			get = function(info) return CheeseSLSLootTracker.db.profile.enabled end,
		},
		debugging = {
			order = 20,
			name = "Debug",
			desc = "Debug",
			type = "toggle",
			set = function(info,val)
				CheeseSLSLootTracker.db.profile.debugging = val
			end,
			get = function(info) return CheeseSLSLootTracker.db.profile.debugging end,
		},
		newline29 = { name="", type="description", order=29 },

		limit2hours = {
			order = 30,
			name = "2 hr view limit",
			desc = "Limit shown loot to two hours (tradeable time window)",
			type = "toggle",
			set = function(info,val)
				CheeseSLSLootTracker.db.profile.limittwohour = val
			end,
			get = function(info) return CheeseSLSLootTracker.db.profile.limittwohour end,
		},
		delete2hours = {
			order = 35,
			name = "2 hr deletion",
			desc = "Delete loot older than two hours (tradeable time window) from tracker",
			type = "toggle",
			set = function(info,val)
				CheeseSLSLootTracker.db.profile.deletetwohour = val
			end,
			get = function(info) return CheeseSLSLootTracker.db.profile.deletetwohour end,
		},
		newline39 = { name="", type="description", order=39 },

		newline39 = { name="", type="description", order=39 },


		numberloot = {
			order = 40,
			name = "# loot items",
			desc = "Number of loot items stored in DB",
			type = "input",
			set = function(info,val) end,
			get = function(info) return tostring(CheeseSLSLootTracker:htlen(CheeseSLSLootTracker.db.profile.loothistory)) end,
		},
		clearloot = {
			order = 50,
			name = "Clear loot table",
			desc = "Numer of loot items stored in DB",
			type = "execute",
			confirm = true,
			func = function(info) CheeseSLSLootTracker.db.profile.loothistory = {} end,
		},

	} -- args
}

function CheeseSLSLootTracker:OnInitialize()
	-- Code that you want to run when the addon is first loaded goes here.
	self.db = LibStub("AceDB-3.0"):New("CheeseSLSLootTrackerDB", defaults)

	LibStub("AceConfig-3.0"):RegisterOptionsTable("CheeseSLSLootTracker", self.optionsTable)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("CheeseSLSLootTracker", "CheeseSLSLootTracker")

	self:RegisterChatCommand("cslsloot", "ChatCommand")
	self:RegisterChatCommand("slsloot", "ChatCommand");

	self:RegisterComm(CheeseSLSLootTracker.commPrefix, "OnCommReceived")

	self:RegisterEvent("CHAT_MSG_LOOT")

	-- self:RegisterEvent("LOOT_OPENED")
	-- self:RegisterEvent("LOOT_CLOSED") -- from wowpedia: Note that this will fire before the last CHAT_MSG_LOOT event for that loot.

	-- self:RegisterEvent("START_LOOT_ROLL")
	-- self:RegisterEvent("LOOT_ROLLS_COMPLETE") -- so most likely this could as well be before last CHAT_MSG_LOOT

	-- use only TRADE for now, to be ignored. I don't care which kind of Loot it actually was
	self:RegisterEvent("TRADE_SHOW")
	self:RegisterEvent("TRADE_CLOSED") -- so most likely this could as well be before last CHAT_MSG_LOOT

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

	CheeseSLSLootTracker:Print("CheeseSLSLootTracker loaded.")
end

function CheeseSLSLootTracker:OnEnable()
	-- Called when the addon is enabled
end

function CheeseSLSLootTracker:OnDisable()
	-- Called when the addon is disabled
end

local function strlt(s)
	return strlower(strtrim(s))
end

function CheeseSLSLootTracker:ChatCommand(inc)

	if strlt(inc) == "" then

		CheeseSLSLootTracker.lootTrackFrame = CheeseSLSLootTracker:createLootTrackFrame()
		if CheeseSLSLootTracker.lootTrackFrame then
			CheeseSLSLootTracker.lootTrackFrame:Show() 
		end

	elseif strlt(inc) == "debug" then
		CheeseSLSLootTracker.db.profile.debugging = not CheeseSLSLootTracker.db.profile.debugging
		if CheeseSLSLootTracker.db.profile.debugging then
			CheeseSLSLootTracker:Print("CheeseSLSLootTracker DEBUGGING " .. L["is enabled."])
		else
			CheeseSLSLootTracker:Print("CheeseSLSLootTracker DEBUGGING " .. L["is disabled."])
		end

	elseif strlt(inc:sub(0,5)) == "debug" then
		itemLink = inc:sub(6)
		local _, itemId, _, _, _, _, _, _, _, _, _, _, _, _ = strsplit(":", itemLink)
		local id = tostring(time()) .. "/" .. tostring(itemId) .. "/" .. UnitName("player")
		CheeseSLSLootTracker.db.profile.loothistory[id] = {
			itemId = itemId,
			itemLink = itemLink,
			queueTime = time(),
			playerName = UnitName("player")
		}

	else

		if (strlt(inc) == "enable") or (strlt(inc) == "enabled") or (strlt(inc) == "on") then
			CheeseSLSLootTracker.db.profile.enabled = true
		end

		if (strlt(inc) == "disable") or (strlt(inc) == "disabled") or (strlt(inc) == "off") then
			CheeseSLSLootTracker.db.profile.enabled = false
		end

		if CheeseSLSLootTracker.db.profile.enabled then
			CheeseSLSLootTracker:Print("CheeseSLSLootTracker " .. L["is enabled."])
		else
			CheeseSLSLootTracker:Print("CheeseSLSLootTracker " .. L["is disabled."])
		end

	end

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


function CheeseSLSLootTracker:Debug(t)
	if (CheeseSLSLootTracker.db.profile.debugging) then
		CheeseSLSLootTracker:Print("CheeseSLSLootTracker DEBUG: " .. t)
	end
end

