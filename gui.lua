local L = LibStub("AceLocale-3.0"):GetLocale("CheeseSLSLootTracker", true)
local AceGUI = LibStub("AceGUI-3.0")

local function roundFloored(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult) / mult
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

function CheeseSLSLootTracker:createLootTrackFrame()
	-- no current loot? don't create frame
	if not CheeseSLSLootTracker.db.profile.loothistory then
		CheeseSLSLootTracker:Print(L["No loot history to show"] .. " (nil)")
		return
	end

	local twohoursago = time() - 2*60*60

	-- delete old entries
	-- and prepapre to sort loot history while we're at it
	local keyset={}
	for historyid,loot in pairs(CheeseSLSLootTracker.db.profile.loothistory) do
		if CheeseSLSLootTracker.db.profile.deletetwohour and tonumber(loot["queueTime"]) < twohoursago then
			-- remove loot history if requested
			CheeseSLSLootTracker.db.profile.loothistory[historyid] = nil
		else
			-- insert to keyset for sorting
			tinsert(keyset, historyid)
		end
	end

	-- if there is no loot left to show after possible deletion, stop
	if CheeseSLSLootTracker:htlen(CheeseSLSLootTracker.db.profile.loothistory) == 0 then
		CheeseSLSLootTracker:Print(L["No loot history to show"] .. " (#0)")
		return
	end


	-- id = tostring(deserialized["queueTime"]) .. "/" .. tostring(itemId) .. "/" .. tostring(deserialized["playerName"])
	table.sort(keyset, function(a,b)
		local aTime, _, _ = strsplit("/", a)
		local bTime, _, _ = strsplit("/", b)
		return (tonumber(aTime) < tonumber(bTime))
	end)
	-- keyset is now sorted in DESCENDING TIME

	-- calculate size and percentages
	local absolutsizes = {
		timestamp = 40,
		icon = 25,
		item = 150,
		player = 75,
		clientnotifications = 90,
		btnstartbid = 60,
		winner = 75,
	}
	local windowwidth = absolutsizes["timestamp"] + absolutsizes["icon"] + absolutsizes["item"] + absolutsizes["player"] + absolutsizes["winner"]
	if (CheeseSLSClient) then windowwidth = windowwidth + absolutsizes["clientnotifications"] end
	if (CheeseSLS) then	windowwidth = windowwidth + absolutsizes["btnstartbid"] end
	local relativewidth = {
		timestamp = roundFloored(absolutsizes["timestamp"]/windowwidth,2),
		icon = roundFloored(absolutsizes["icon"]/windowwidth,2),
		item = roundFloored(absolutsizes["item"]/windowwidth,2),
		player = roundFloored(absolutsizes["player"]/windowwidth,2),
		clientnotifications = roundFloored(absolutsizes["clientnotifications"]/windowwidth,2),
		btnstartbid = roundFloored(absolutsizes["btnstartbid"]/windowwidth,2),
		winner = roundFloored(absolutsizes["winner"]/windowwidth,2),
	}

	local windowheight = min( 700,  75 + 25 * CheeseSLSLootTracker:htlen(CheeseSLSLootTracker.db.profile.loothistory) )

	local f = AceGUI:Create("Window")
	CheeseSLSLootTracker.lootTrackFrame = f
	f:SetTitle(L["SLS Loot History"])
	f:SetStatusText("")
	f:SetLayout("Flow")
	f:SetWidth(windowwidth)
	f:SetHeight(windowheight)
--	f:SetPoint('TOPLEFT',UIParent,'TOPLEFT',30,30)

	f:SetCallback("OnClose",function(widget) AceGUI:Release(widget) end)

	-- close on escape
	local frameName = "CheeseSLSLootTrackerLootTrackFrame"
	_G[frameName] = f.frame
	tinsert(UISpecialFrames, frameName)

	-- headers

	local hdrTimestamp = AceGUI:Create("InteractiveLabel")
	hdrTimestamp:SetText("Drop")
	hdrTimestamp:SetColor(204,0,204)
	hdrTimestamp:SetRelativeWidth(relativewidth["timestamp"])
	f:AddChild(hdrTimestamp)

	local hdrItem = AceGUI:Create("InteractiveLabel")
	hdrItem:SetText("Item")
	hdrItem:SetColor(204,0,204)
	hdrItem:SetRelativeWidth(relativewidth["icon"] + relativewidth["item"])
	f:AddChild(hdrItem)

	local hdrCarrier = AceGUI:Create("InteractiveLabel")
	hdrCarrier:SetText("Carrier")
	hdrCarrier:SetColor(204,0,204)
	hdrCarrier:SetRelativeWidth(relativewidth["player"])
	f:AddChild(hdrCarrier)

	if (CheeseSLSClient) then
		local hdrNotifications = AceGUI:Create("InteractiveLabel")
		hdrNotifications:SetText("Client Notifications")
		hdrNotifications:SetColor(204,0,204)
		hdrNotifications:SetRelativeWidth(relativewidth["clientnotifications"])
		f:AddChild(hdrNotifications)
	end

	if (CheeseSLS) then
		local hdrBids = AceGUI:Create("InteractiveLabel")
		hdrBids:SetText("Bids")
		hdrBids:SetColor(204,0,204)
		hdrBids:SetRelativeWidth(relativewidth["btnstartbid"])
		f:AddChild(hdrBids)
	end

	local hdrWinner = AceGUI:Create("InteractiveLabel")
	hdrWinner:SetText("Winner")
	hdrWinner:SetColor(204,0,204)
	hdrWinner:SetRelativeWidth(relativewidth["winner"])
	f:AddChild(hdrWinner)


	-- content

	local scrollcontainer = AceGUI:Create("SimpleGroup")
	scrollcontainer:SetFullWidth(true)
	scrollcontainer:SetFullHeight(true)
	scrollcontainer:SetLayout("Fill")
	f:AddChild(scrollcontainer)

	local s = AceGUI:Create("ScrollFrame")
	s:SetLayout("Flow")
	scrollcontainer:AddChild(s)

	if not CheeseSLSLootTracker.lootTrackFrameButtons then CheeseSLSLootTracker.lootTrackFrameButtons = {} end
	if not CheeseSLSLootTracker.lootTrackDropdowns then CheeseSLSLootTracker.lootTrackDropdowns = {} end
	if not CheeseSLSLootTracker.db.profile.alreadyStarted then CheeseSLSLootTracker.db.profile.alreadyStarted = {} end

	if CheeseSLSClient then
		if not CheeseSLSClient.db.profile.notificationHandling then CheeseSLSClient.db.profile.notificationHandling = {} end
	end

	-- for presenting number at the end, if there are hidden entries
	local counthidden = 0

	-- options for client notification handling
	local clientHandlerList = {ALERT = L["Alert"], X = "-", IGNORE = L["Ignore"]}
	local clientHandlerSort = {"ALERT","X","IGNORE"}
	s:SetUserData("clientHandlerList", clientHandlerList)
	s:SetUserData("clientHandlerSort", clientHandlerSort)


	-- keyset is now sorted in DESCENDING TIME
	for i = 1, #keyset do
		local historyid = keyset[i]
		local loot = CheeseSLSLootTracker.db.profile.loothistory[ historyid ]
		local lootItemId = tonumber(loot["itemId"])

		-- set ignorance for CheeseSLSClient, if installed
		local itemIgnorance = CheeseSLSLootTracker:determineItemIgnorance(lootItemId)
		if CheeseSLSClient and itemIgnorance then
			-- only if not defined already
			if CheeseSLSClient.db.profile.notificationHandling[lootItemId] == nil then
				CheeseSLSClient.db.profile.notificationHandling[lootItemId] = "IGNORE"
			end
		end

		if CheeseSLSLootTracker.db.profile.limittwohour and tonumber(loot["queueTime"]) < twohoursago then
			counthidden = counthidden + 1
		else
			-- show list entry
			local itemLink = loot["itemLink"]
			local itemId = tonumber(loot["itemId"])
			local _, _, _, _, _, _, _, _, _, itemTexture, _ = GetItemInfo(itemId)
			local timestamp = date("%H:%M", loot["queueTime"])

			local lbTime = AceGUI:Create("InteractiveLabel")
			lbTime:SetText(timestamp)
			lbTime:SetRelativeWidth(relativewidth["timestamp"])
			s:AddChild(lbTime)

			-- TODO: See if we get issues that icons are not available. That would be caching issues,
			-- but we are starting GetItemInfo early this time, on addon load or on receive over comms.
			-- So I assume this shouldn't happen. If it does:
			-- * introduce a store variable for the icon,
			-- * turn on RegisterEvent("GET_ITEM_INFO_RECEIVED"),
			-- * update icon when texture is in

			local lbIcon = AceGUI:Create("Icon")
			lbIcon:SetUserData("itemLink", itemLink)
			lbIcon:SetRelativeWidth(relativewidth["icon"])
			lbIcon:SetImage(itemTexture)
			lbIcon:SetImageSize(15,15)
			lbIcon:SetCallback("OnEnter", function(widget)
				GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
				GameTooltip:SetHyperlink(widget:GetUserData("itemLink"))
				GameTooltip:Show()
			end)
			lbIcon:SetCallback("OnLeave", function(widget)
				GameTooltip:Hide()
			end)
			s:AddChild(lbIcon)

			local lbItem = AceGUI:Create("InteractiveLabel")
			lbItem:SetUserData("itemLink", itemLink)
			lbItem:SetText(itemLink)
			lbItem:SetRelativeWidth(relativewidth["item"])
			lbItem:SetCallback("OnEnter", function(widget)
				GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
				GameTooltip:SetHyperlink(widget:GetUserData("itemLink"))
				GameTooltip:Show()
			end)
			lbItem:SetCallback("OnLeave", function(widget)
				GameTooltip:Hide()
			end)
			s:AddChild(lbItem)

			local lbPlayer = AceGUI:Create("InteractiveLabel")
			lbPlayer:SetText(loot["playerName"])
			lbPlayer:SetRelativeWidth(relativewidth["player"])
			s:AddChild(lbPlayer)

			if (CheeseSLSClient) then
				local handler = CheeseSLSClient.db.profile.notificationHandling[lootItemId] or "X"

				local ddnClient = AceGUI:Create("Dropdown")
				CheeseSLSLootTracker.lootTrackDropdowns[historyid] = ddnClient

				ddnClient:SetUserData("lootItemId", lootItemId)
				ddnClient:SetList(s:GetUserData("clientHandlerList"), s:GetUserData("clientHandlerSort"))
				ddnClient:SetValue(handler)
				ddnClient:SetText(s:GetUserData("clientHandlerList")[handler])
				ddnClient:SetMultiselect(false)
				ddnClient:SetRelativeWidth(relativewidth["clientnotifications"])
				ddnClient:SetCallback("OnValueChanged", function(widget, event, key)
					CheeseSLSClient.db.profile.notificationHandling[widget:GetUserData("lootItemId")] = key

					local newtext = widget.parent:GetUserData("clientHandlerList")[key]
					ddnClient:SetText(newtext)

					-- do this for all entries with this itemId
					for hId,ddn in pairs(CheeseSLSLootTracker.lootTrackDropdowns) do
						if ddn:GetUserData("lootItemId") == widget:GetUserData("lootItemId") then
							ddn:SetValue(key)
							ddn:SetText(newtext)
						end
					end
				end)
				s:AddChild(ddnClient)

			end

			if (CheeseSLS) then
				local btnStart = AceGUI:Create("Button")
				btnStart.historyid = historyid
				btnStart.itemLink = itemLink
				btnStart.holdingPlayer = loot["playerName"]
				btnStart.history = historyid
				CheeseSLSLootTracker.lootTrackFrameButtons["btnStart" .. historyid] = btnStart
				btnStart:SetText(L["SLS bid"])
				btnStart:SetRelativeWidth(relativewidth["btnstartbid"])
				btnStart:SetCallback("OnClick", function(widget)
					if CheeseSLS:StartBidding(widget.itemLink, widget.holdingPlayer, widget.historyid) then
						CheeseSLSLootTracker.db.profile.alreadyStarted[widget.historyid] = time()
						CheeseSLSLootTracker.lootTrackFrameButtons["btnStart" .. widget.historyid]:SetDisabled(true)
					end
				end)
				-- don't enable if already used
				if CheeseSLSLootTracker.db.profile.alreadyStarted[historyid] then
					btnStart:SetDisabled(true)
				end
				s:AddChild(btnStart)
			end

			local lbWinner = AceGUI:Create("InteractiveLabel")
			local winningPlayer = loot["winner"] or "-"
			lbWinner:SetText(winningPlayer)
			lbWinner:SetRelativeWidth(relativewidth["player"])
			s:AddChild(lbWinner)
			-- for updating from comms:
			CheeseSLSLootTracker.winnerLabels[historyid] = lbWinner


		end -- "if,then,else" used instead of a simple "continue" that's missing in lua
	end --for

	if counthidden > 0 then
		local lbBlankspace = AceGUI:Create("InteractiveLabel")
		lbBlankspace:SetText()
		lbBlankspace:SetRelativeWidth(0.10)
		s:AddChild(lbBlankspace)

		local lbCntHidden = AceGUI:Create("InteractiveLabel")
		lbCntHidden:SetText(L["hidden entries"](counthidden))
		lbCntHidden:SetRelativeWidth(0.25)
		s:AddChild(lbCntHidden)

		local btnLimitConfig = AceGUI:Create("Button")
		btnLimitConfig:SetText(L["Disable limiting to 2 hours"])
		btnLimitConfig:SetRelativeWidth(0.65)
		btnLimitConfig:SetCallback("OnClick", function(widget)
			CheeseSLSLootTracker.db.profile.limittwohour = false
			-- open a new window, which will include all entries then
			CheeseSLSLootTracker.lootTrackFrame:Hide()
			CheeseSLSLootTracker:createLootTrackFrame()
		end)
		s:AddChild(btnLimitConfig)
	end

	return f
end
