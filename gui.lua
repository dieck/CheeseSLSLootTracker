local L = LibStub("AceLocale-3.0"):GetLocale("CheeseSLSLootTracker", true)
local AceGUI = LibStub("AceGUI-3.0")

local function roundFloored(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult) / mult
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
		timestamp = 35,
		icon = 25,
		item = 150,
		player = 70,
		btnalert = 75,
		btnx = 45,
		btnignore = 75,
		btnstartbid = 90,
	}
	local windowwidth = absolutsizes["timestamp"] + absolutsizes["icon"] + absolutsizes["item"] + absolutsizes["player"]
	if (CheeseSLSClient) then	windowwidth = windowwidth + absolutsizes["btnalert"] + absolutsizes["btnx"] + absolutsizes["btnignore"] end
	if (CheeseSLS) then	windowwidth = windowwidth + absolutsizes["btnstartbid"] end
	local relativewidth = {
		timestamp = roundFloored(absolutsizes["timestamp"]/windowwidth,2),
		icon = roundFloored(absolutsizes["icon"]/windowwidth,2),
		item = roundFloored(absolutsizes["item"]/windowwidth,2),
		player = roundFloored(absolutsizes["player"]/windowwidth,2),
		btnalert = roundFloored(absolutsizes["btnalert"]/windowwidth,2),
		btnx = roundFloored(absolutsizes["btnx"]/windowwidth,2),
		btnignore = roundFloored(absolutsizes["btnignore"]/windowwidth,2),
		btnstartbid = roundFloored(absolutsizes["btnstartbid"]/windowwidth,2),
	}

	local windowheight = min( 700,  75 + 25 * CheeseSLSLootTracker:htlen(CheeseSLSLootTracker.db.profile.loothistory) )

	local f = AceGUI:Create("Window")
	f:SetTitle(L["SLS Loot History"])
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

	-- for presenting number at the end, if there are hidden entries
	local counthidden = 0

	-- keyset is now sorted in DESCENDING TIME
	for i = 1, #keyset do
		local historyid = keyset[i]
		local loot = CheeseSLSLootTracker.db.profile.loothistory[ historyid ]

		-- set ignorance for CheeseSLSClient, if installed
		local itemIgnorance = CheeseSLSLootTracker:determineItemIgnorance(tonumber(loot["itemId"]))
		if CheeseSLSClient and itemIgnorance then
			CheeseSLSClient.db.profile.ignorelist[tonumber(loot["itemId"])] = time()
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
			lbIcon:SetRelativeWidth(relativewidth["icon"])
			lbIcon:SetImage(itemTexture)
			lbIcon:SetImageSize(15,15)
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
			lbItem:SetCallback("OnEnter", function(widget)
				GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
				GameTooltip:SetHyperlink(itemLink)
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
				local btnAlert = AceGUI:Create("Button")
				btnAlert.historyid = historyid
				btnAlert.itemId = itemId
				CheeseSLSLootTracker.lootTrackFrameButtons["btnAlert" .. historyid] = btnAlert
				btnAlert:SetRelativeWidth(relativewidth["btnalert"])
				btnAlert:SetDisabled(CheeseSLSClient.db.profile.alertlist[itemId])
				btnAlert:SetText(L["Alert"])
				btnAlert:SetCallback("OnClick", function(widget)
					CheeseSLSClient.db.profile.alertlist[widget.itemId] = time()

					-- don't just go for one, go for ALL buttons with the same itemId
					for key,val in pairs(CheeseSLSLootTracker.lootTrackFrameButtons) do
						if key:sub(0,8) == "btnAlert" then
							local _,iid,_ = strsplit("/", key)
							if tonumber(iid) == tonumber(widget.itemId) then
								CheeseSLSLootTracker.lootTrackFrameButtons[key]:SetDisabled(true)
							end
						end
					end
				end)
				s:AddChild(btnAlert)

				local btnX = AceGUI:Create("Button")
				btnX.historyid = historyid
				btnX.itemId = itemId
				CheeseSLSLootTracker.lootTrackFrameButtons["btnX" .. historyid] = btnX
				btnX:SetRelativeWidth(relativewidth["btnx"])
				btnX:SetText("x")
				btnX:SetCallback("OnClick", function(widget)
					CheeseSLSClient.db.profile.alertlist[widget.itemId] = nil
					CheeseSLSClient.db.profile.ignorelist[widget.itemId] = nil
					-- don't just go for one, go for ALL buttons with the same itemId
					for key,val in pairs(CheeseSLSLootTracker.lootTrackFrameButtons) do
						if key:sub(0,8) == "btnAlert" then
							local _,iid,_ = strsplit("/", key)
							if tonumber(iid) == tonumber(widget.itemId) then
								CheeseSLSLootTracker.lootTrackFrameButtons[key]:SetDisabled(false)
							end
						end
						if key:sub(0,9) == "btnIgnore" then
							local _,iid,_ = strsplit("/", key)
							if tonumber(iid) == tonumber(widget.itemId) then
								CheeseSLSLootTracker.lootTrackFrameButtons[key]:SetDisabled(false)
							end
						end
					end
				end)
				s:AddChild(btnX)

				local btnIgnore = AceGUI:Create("Button")
				btnIgnore.historyid = historyid
				btnIgnore.itemId = itemId
				CheeseSLSLootTracker.lootTrackFrameButtons["btnIgnore" .. historyid] = btnIgnore
				btnIgnore:SetDisabled(CheeseSLSClient.db.profile.ignorelist[itemId])
				btnIgnore:SetText(L["Ignore"])
				btnIgnore:SetRelativeWidth(relativewidth["btnignore"])
				btnIgnore:SetCallback("OnClick", function(widget)
					CheeseSLSClient.db.profile.ignorelist[widget.itemId] = time()

					-- don't just go for one, go for ALL buttons with the same itemId
					for key,val in pairs(CheeseSLSLootTracker.lootTrackFrameButtons) do
						if key:sub(0,9) == "btnIgnore" then
							local _,iid,_ = strsplit("/", key)
							if tonumber(iid) == tonumber(widget.itemId) then
								CheeseSLSLootTracker.lootTrackFrameButtons[key]:SetDisabled(true)
							end
						end
					end
				end)
				s:AddChild(btnIgnore)
			end

			if (CheeseSLS) then
				local btnStart = AceGUI:Create("Button")
				btnStart.historyid = historyid
				btnStart.itemLink = itemLink
				btnStart.holdingPlayer = loot["playerName"]
				CheeseSLSLootTracker.lootTrackFrameButtons["btnStart" .. historyid] = btnStart
				btnStart:SetText(L["SLS bid"])
				btnStart:SetRelativeWidth(relativewidth["btnstartbid"])
				btnStart:SetCallback("OnClick", function(widget)
					if CheeseSLS:StartBidding(widget.itemLink, widget.holdingPlayer) then
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
			CheeseSLSLootTracker.lootTrackFrame:Hide()
			CheeseSLSLootTracker.lootTrackFrame = CheeseSLSLootTracker:createLootTrackFrame()
			if CheeseSLSLootTracker.lootTrackFrame then CheeseSLSLootTracker.lootTrackFrame:Show() end
		end)
		s:AddChild(btnLimitConfig)
	end

	return f
end
