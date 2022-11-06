local L = LibStub("AceLocale-3.0"):GetLocale("CheeseSLSLootTracker", true)
local AceGUI = LibStub("AceGUI-3.0")

local function round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

function CheeseSLSLootTracker:createLootTrackFrame()
	-- no current loot? don't create frame
	if not CheeseSLSLootTracker.db.profile.loothistory then return end
	if #CheeseSLSLootTracker.db.profile.loothistory == 0 then return end
	-- calculate size and percentages

	local absolutsizes = {
		icon = 30,
		item = 100,
		player = 70,
		btnalert = 50,
		btnignore = 50,
		btnstartbid = 50
	}
	local windowwidth = absolutsizes["icon"] + absolutsizes["item"] + absolutsizes["player"]
	if (CheeseSLSClient) then	windowwidth = windowwidth + absolutsizes["btnalert"] + absolutsizes["btnignore"] end
	if (CheeseSLS) then	windowwidth = windowwidth + absolutsizes["btnstartbid"] end
	local relativewidth = {
		icon = round(absolutsizes["icon"]/windowwidth,2),
		item = round(absolutsizes["item"]/windowwidth,2),
		player = round(absolutsizes["player"]/windowwidth,2),
		btnalert = round(absolutsizes["btnalert"]/windowwidth,2),
		btnignore = round(absolutsizes["btnignore"]/windowwidth,2),
		btnstartbid = round(absolutsizes["btnstartbid"]/windowwidth,2),
	}

	local windowheight = min( 700,  75 + 25 * #CheeseSLSLootTracker.db.profile.loothistory )

	local f = AceGUI:Create("Window")
	f:SetTitle("SLS Loot History")
	f:SetStatusText("")
	f:SetLayout("Flow")
	f:SetWidth(windowwidth)
	f:SetHeight(windowheight)
--	f:SetPoint('TOPLEFT',UIParent,'TOPLEFT',30,30)

	f:SetCallback("OnClose",function(widget) AceGUI:Release(widget) end)

	-- close on escape
	local frameName = "CheeseSLSLootTracker.lootTrackFrameFrame"
	_G[frameName] = f.frame
	tinsert(UISpecialFrames, frameName)

	local scrollcontainer = AceGUI:Create("SimpleGroup")
	scrollcontainer:SetFullWidth(true)
	scrollcontainer:SetFullHeight(true)
	scrollcontainer:SetLayout("Fill")
	f:AddChild(scrollcontainer)

	local s = AceGUI:Create("ScrollFrame")
	s:SetLayout("Flow")
	scrollcontainer:AddChild(s)

	if not CheeseSLSLootTracker.lootTrackFrameButtons then CheeseSLSLootTracker.lootTrackFrameButtons = {} end
	if not CheeseSLSLootTracker.db.profile.alreadyStarted then CheeseSLSLootTracker.db.profile.alreadyStarted = {} end

	if CheeseSLSClient then
			if not CheeseSLSClient.db.profile.alertlist then CheeseSLSClient.db.profile.alertlist = {} end
			if not CheeseSLSClient.db.profile.ignorelist then CheeseSLSClient.db.profile.ignorelist = {} end
	end

	for historyid,loot in pairs(CheeseSLSLootTracker.db.profile.loothistory) do

		local itemLink = loot["itemLink"]
		local itemId = tonumber(loot["itemId"])
		local _, _, _, _, _, _, _, _, _, itemTexture, _ = GetItemInfo(itemId)

		-- TODO: See if we get issues that icons are not available. That would be caching issues,
		-- but we are starting GetItemInfo early this time, on addon load or on receive over comms.
		-- So I assume this shouldn't happen. If it does:
		-- * introduce a store variable for the icon,
		-- * turn on RegisterEvent("GET_ITEM_INFO_RECEIVED"),
		-- * update icon when texture is in

		local lbIcon = AceGUI:Create("Icon")
		lbIcon:SetRelativeWidth(relativewidth["icon"])
		lbIcon:SetImage(itemTexture)
		lbIcon:SetImageSize(35,35)
		lbIcon:SetCallback("OnEnter", function(widget)
			GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
			GameTooltip:SetHyperlink(itemLink)
			GameTooltip:Show()
		end)
		lbIcon:SetCallback("OnLeave", function(widget)
			GameTooltip:Hide()
		end)
		s:AddChild(lbIcon)

		local lbItem = AceGUI:Create("InteractiveLabel")
		lbItem:SetText(itemLink)
		lbItem:SetRelativeWidth(relativewidth["item"])
		s:AddChild(lbItem)

		local lbPlayer = AceGUI:Create("InteractiveLabel")
		lbPlayer:SetText(loot["playerName"])
		lbPlayer:SetRelativeWidth(relativewidth["player"])
		s:AddChild(lbPlayer)

		if (CheeseSLSClient) then
			local btnAlert = AceGUI:Create("Button")
			CheeseSLSLootTracker.lootTrackFrameButtons["btnAlert" .. historyid] = btnAlert
			btnAlert:SetRelativeWidth(relativewidth["btnalert"])
			if CheeseSLSClient.db.profile.alertlist[itemId] then
				btnAlert:SetText("Disable Alert")
			else
				btnAlert:SetText("Enable Alert")
			end
			btnAlert:SetCallback("OnClick", function()
				CheeseSLSClient.db.profile.alertlist[itemId] = not CheeseSLSClient.db.profile.alertlist[itemId]

				if CheeseSLSClient.db.profile.alertlist[itemId] then
					CheeseSLSLootTracker.lootTrackFrameButtons["btnAlert" .. historyid]:SetText("Disable Alert")
					-- you just enabled Alarm, so don't ignore
					CheeseSLSClient.db.profile.ignorelist[itemId] = false
					CheeseSLSLootTracker.lootTrackFrameButtons["btnIgnore" .. historyid]:SetText("Enable Ignore")
				else
					CheeseSLSLootTracker.lootTrackFrameButtons["btnAlert" .. historyid]:SetText("Enable Alert")
					-- you just disabled Alarm, don't care what happened to ignore
				end
			end)
			s:AddChild(btnAlert)

			local btnIgnore = AceGUI:Create("Button")
			CheeseSLSLootTracker.lootTrackFrameButtons["btnAlert" .. historyid] = btnIgnore
			if CheeseSLSClient.db.profile.ignorelist[itemId] then
				btnIgnore:SetText("Disable Ignore")
			else
				btnIgnore:SetText("Enable Ignore")
			end
			btnIgnore:SetRelativeWidth(relativewidth["btnignore"])
			btnIgnore:SetCallback("OnClick", function()
				CheeseSLSClient.db.profile.ignorelist[itemId] = not CheeseSLSClient.db.profile.ignorelist[itemId]

				if CheeseSLSClient.db.profile.ignorelist[itemId] then
					CheeseSLSLootTracker.lootTrackFrameButtons["btnIgnore" .. historyid]:SetText("Disable Ignore")
					-- you just enabled Ignore, so don't alert
					CheeseSLSClient.db.profile.alertlist[itemId] = false
					CheeseSLSLootTracker.lootTrackFrameButtons["btnAlert" .. historyid]:SetText("Enable Alert")
				else
					CheeseSLSLootTracker.lootTrackFrameButtons["btnIgnore" .. historyid]:SetText("Enable Ignore")
					-- you just disabled Ignore, don't care what happened to alarm
				end
			end)
			s:AddChild(btnIgnore)
		end

		if (CheeseSLS) then
			local btnStart = AceGUI:Create("Button")
			CheeseSLSLootTracker.lootTrackFrameButtons["btnStart" .. historyid] = btnStart
			btnStart:SetText("Start Bids")
			btnStart:SetRelativeWidth(relativewidth["btnstartbid"])
			btnStart:SetCallback("OnClick", function()
				CheeseSLS:StartBidding(itemLink)
				CheeseSLSLootTracker.db.profile.alreadyStarted[historyid] = time()
				CheeseSLSLootTracker.lootTrackFrameButtons["btnStart" .. historyid]:SetDisable(true)
			end)
			-- don't enable if already used
			if CheeseSLSLootTracker.db.profile.alreadyStarted[historyid] then
				btnStart:SetDisable(true)
			end
			s:AddChild(btnStart)
		end

	end --for

	return f
end
