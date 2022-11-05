local L = LibStub("AceLocale-3.0"):GetLocale("CheeseSLSLootTracker", true)

CheeseSLSLootTracker.commPrefix = "CheeseSLS-1.0-"
CheeseSLSLootTracker.commVersion = 20221103

local defaults = {
	profile = {
		enabled = true,
		debugging = false,
	}
}

CheeseSLSLootTracker.optionsTable = {
	type = "group",
	args = {
		enabled = {
			name = "Enabled",
			desc = "Enabled",
			type = "toggle",
			set = function(info,val)
				CheeseSLSLootTracker.db.profile.enabled = val
			end,
			get = function(info) return CheeseSLSLootTracker.db.profile.enabled end,
		},
		debugging = {
			name = "Debug",
			desc = "Debug",
			type = "toggle",
			set = function(info,val)
				CheeseSLSLootTracker.db.profile.debugging = val
			end,
			get = function(info) return CheeseSLSLootTracker.db.profile.debugging end,
		},
	} -- args
}

function CheeseSLSLootTracker:OnInitialize()
	-- Code that you want to run when the addon is first loaded goes here.
	self.db = LibStub("AceDB-3.0"):New("CheeseSLSLootTrackerDB", defaults)

	LibStub("AceConfig-3.0"):RegisterOptionsTable("CheeseSLSLootTracker", self.optionsTable)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("CheeseSLSLootTracker", "CheeseSLSLootTracker")

	self:RegisterChatCommand("cslsclient", "ChatCommand")
	self:RegisterChatCommand("slsclient", "ChatCommand");

	self:RegisterComm(CheeseSLSLootTracker.commPrefix, "OnCommReceived")

	self:RegisterEvent("CHAT_MSG_LOOT")

	-- self:RegisterEvent("LOOT_OPENED")
	-- self:RegisterEvent("LOOT_CLOSED") -- from wowpedia: Note that this will fire before the last CHAT_MSG_LOOT event for that loot.

	-- self:RegisterEvent("START_LOOT_ROLL")
	-- self:RegisterEvent("LOOT_ROLLS_COMPLETE") -- so most likely this could as well be before last CHAT_MSG_LOOT

	-- use only TRADE for now, to be ignored. I don't care which kind of Loot it actually was
	self:RegisterEvent("TRADE_SHOW")
	self:RegisterEvent("TRADE_CLOSED") -- so most likely this could as well be before last CHAT_MSG_LOOT

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
	if strlt(inc) == "debug" then
		CheeseSLSLootTracker.db.profile.debugging = not CheeseSLSLootTracker.db.profile.debugging
		if CheeseSLSLootTracker.db.profile.debugging then
			CheeseSLSLootTracker:Print("CheeseSLSLootTracker DEBUGGING " .. L["is enabled."])
		else
			CheeseSLSLootTracker:Print("CheeseSLSLootTracker DEBUGGING " .. L["is disabled."])
		end

	else

		if strlt(inc) == "" then
			CheeseSLSLootTracker.db.profile.enabled = not CheeseSLSLootTracker.db.profile.enabled
		end

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


function CheeseSLSLootTracker:Debug(t)
	if (CheeseSLSLootTracker.db.profile.debugging) then
		CheeseSLSLootTracker:Print("CheeseSLSLootTracker DEBUG: " .. t)
	end
end

