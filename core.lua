local L = LibStub("AceLocale-3.0"):GetLocale("CheeseSLSLootTracker", true)

CheeseSLSLootTracker.commPrefix = "CheeseSLS-1.0-"
CheeseSLSLootTracker.commVersion = 20221103

CheeseSLSLootTracker.commPrefixGSDKP = "GSDKPCSLS-1"

local defaults = {
	profile = {
		enabled = true,
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
		enabled = {
			order = 10,
			name = L["Enabled"],
			desc = L["Enabled"],
			type = "toggle",
			set = function(info,val)
				CheeseSLSLootTracker.db.profile.enabled = val
			end,
			get = function(info) return CheeseSLSLootTracker.db.profile.enabled end,
		},
		newline19 = { name="", type="description", order=19 },

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
	self.db = LibStub("AceDB-3.0"):New("CheeseSLSLootTrackerDB", defaults)

	LibStub("AceConfig-3.0"):RegisterOptionsTable("CheeseSLSLootTracker", self.optionsTable)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("CheeseSLSLootTracker", "CheeseSLSLootTracker")

	-- prepare list

	if self.db.profile.loothistory == nil then
		self.db.profile.loothistory = {}
	end

	-- trigger GetItemInfo for all items in database
	-- if you had disconnect / relog, cache needs to be rebuild to avoid having to handle GET_ITEM_INFO_RECEIVED stuff at Boss announcements
	-- so better to load it here. But only once per itemid.
	local itemIdList = {}
	for _, hst in pairs(self.db.profile.loothistory) do
		itemIdList[tonumber(hst["itemId"])] = tonumber(hst["itemId"])
	end
	for itemid,id2 in pairs(itemIdList) do
		GetItemInfo(itemid)
	end

	-- clean up old "rolled for" entries
	-- won't show button for anything older than 2 hours anyway
	if self.db.profile.alreadyStarted then
		local twohoursago = time() - 2*60*60
		for key,val in pairs(self.db.profile.alreadyStarted) do
			if val < twohoursago then
				self.db.profile.alreadyStarted[key] = nil
			end
		end
	end

	-- session tables for later
	self.commUUIDseen = {}
	self.winnerLabels = {}

	self:Print("CheeseSLSLootTracker loaded.")
end

function CheeseSLSLootTracker:OnEnable()
	-- Called when the addon is enabled
	self:RegisterChatCommand("cslsloot", "ChatCommand")
	self:RegisterChatCommand("slsloot", "ChatCommand");

	self:RegisterComm(self.commPrefix, "OnCommReceived")
	self:RegisterComm(self.commPrefixGSDKP, "OnCommReceivedGSDKP")

	self:RegisterEvent("CHAT_MSG_LOOT")

	-- self:RegisterEvent("LOOT_OPENED")
	-- self:RegisterEvent("LOOT_CLOSED") -- from wowpedia: Note that this will fire before the last CHAT_MSG_LOOT event for that loot.

	-- self:RegisterEvent("START_LOOT_ROLL")
	-- self:RegisterEvent("LOOT_ROLLS_COMPLETE") -- so most likely this could as well be before last CHAT_MSG_LOOT

	-- use only TRADE for now, to be ignored. I don't care which kind of Loot it actually was
	self:RegisterEvent("TRADE_SHOW")
	self:RegisterEvent("TRADE_CLOSED") -- so most likely this could as well be before last CHAT_MSG_LOOT
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

		self:createLootTrackFrame()

	elseif strlt(inc) == "debug" then
		self.db.profile.debugging = not self.db.profile.debugging
		if self.db.profile.debugging then
			self:Print("CheeseSLSLootTracker DEBUGGING " .. L["is enabled."])
		else
			self:Print("CheeseSLSLootTracker DEBUGGING " .. L["is disabled."])
		end

	elseif strlt(inc:sub(0,5)) == "debug" then
		local itemLink = inc:sub(6)
		local _, itemId, _, _, _, _, _, _, _, _, _, _, _, _ = strsplit(":", itemLink)
		local id = tostring(time()) .. "/" .. tostring(itemId) .. "/" .. UnitName("player")
		self.db.profile.loothistory[id] = {
			itemId = itemId,
			itemLink = itemLink,
			queueTime = time(),
			playerName = UnitName("player")
		}

	else

		if (strlt(inc) == "enable") or (strlt(inc) == "enabled") or (strlt(inc) == "on") then
			self.db.profile.enabled = true
		end

		if (strlt(inc) == "disable") or (strlt(inc) == "disabled") or (strlt(inc) == "off") then
			self.db.profile.enabled = false
		end

		if self.db.profile.enabled then
			self:Print("CheeseSLSLootTracker " .. L["is enabled."])
		else
			self:Print("CheeseSLSLootTracker " .. L["is disabled."])
		end

	end

end

-- /script CheeseSLSLootTracker:CacheTradeableInventoryPosition()
-- /dump CheeseSLSLootTracker.inventory

function CheeseSLSLootTracker:CacheTradeableInventoryPosition()
	self.inventory = {}

	local tip = CreateFrame("GameTooltip","Tooltip",nil,"GameTooltipTemplate")

	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(bag) do
			local icon, itemCount, _locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID = GetContainerItemInfo(bag, slot)
			if itemID then
				tip:SetOwner(UIParent, "ANCHOR_NONE")
				tip:SetBagItem(bag, slot)
				tip:Show()
				for i = 1,tip:NumLines() do
					if (string.find(_G["TooltipTextLeft"..i]:GetText(), ITEM_BIND_ON_EQUIP)) then
						-- is BoE
						self.inventory[tonumber(itemID)] = { bag = bag, slot = slot }
					elseif (string.find(_G["TooltipTextLeft"..i]:GetText(), string.format(BIND_TRADE_TIME_REMAINING, ".*"))) then
						-- is tradeable (within timer)
						self.inventory[tonumber(itemID)] = { bag = bag, slot = slot }
					end
				end
				tip:Hide()
			end
		end
	end

end

function CheeseSLSLootTracker:TRADE_SHOW()
	-- to ignore trade windows, which also give the EXACT SAME CHAT_MSG_LOOT. WTF Blizzard.
	self.tradeWindow = true

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

	for historyid,loot in pairs(self.db.profile.loothistory) do
		-- check if still tradeable anyway
		if tonumber(loot["queueTime"]) >= twohoursago then
			if loot["winner"] == tradePartner then
				loots[historyid] = loot
			end
		end
	end

	self.lastloots = loots

	if loots then
		self:CacheTradeableInventoryPosition()

		for history,loot in pairs(loots) do
			local itemLink = loot["itemLink"]
			local _, itemId, _, _, _, _, _, _, _, _, _, _, _, _ = strsplit(":", itemLink)

			if self.inventory[tonumber(itemId)] then
				local inv = self.inventory[tonumber(itemId)]
				self:Debug("Trading " .. itemLink .. " (" .. tostring(itemId) .. ") from inventory " .. tostring(inv["bag"]) .. "/" .. tostring(inv["slot"]) .. " to " .. loot["winner"])
				ClearCursor()
				PickupContainerItem(inv["bag"], inv["slot"])
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
	self:ScheduleTimer(function() CheeseSLSLootTracker.tradeWindow = false end, 1)
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
	if (self.db.profile.debugging) then
		self:Print("CheeseSLSLootTracker DEBUG: " .. t)
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
