local L = LibStub("AceLocale-3.0"):GetLocale("CheeseSLSLootTracker", true)
local AceGUI = LibStub("AceGUI-3.0")

local function roundFloored(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult) / mult
end


function CheeseSLSLootTracker:createLootTrackFrame()
	-- no current loot? don't create frame
	if not self.db.profile.loothistory then
		self:Print(L["No loot history to show"] .. " (nil)")
		return
	end

	local twohoursago = time() - 2*60*60

	-- delete old entries
	-- and prepapre to sort loot history while we're at it
	local keyset={}
	for historyid,loot in pairs(self.db.profile.loothistory) do
		if self.db.profile.deletetwohour and tonumber(loot["queueTime"]) < twohoursago then
			-- remove loot history if requested
			self.db.profile.loothistory[historyid] = nil
		else
			-- insert to keyset for sorting
			tinsert(keyset, historyid)
		end
	end

	-- if there is no loot left to show after possible deletion, stop
	if self:htlen(self.db.profile.loothistory) == 0 then
		self:Print(L["No loot history to show"] .. " (#0)")
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
		btnalert = 75,
		btnx = 45,
		btnignore = 75,
		btnstartbid = 60,
		winner = 75,
	}
	local windowwidth = absolutsizes["timestamp"] + absolutsizes["icon"] + absolutsizes["item"] + absolutsizes["player"] + absolutsizes["winner"]
	if (CheeseSLSClient) then windowwidth = windowwidth + absolutsizes["btnalert"] + absolutsizes["btnx"] + absolutsizes["btnignore"] end
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
		winner = roundFloored(absolutsizes["winner"]/windowwidth,2),
	}

	local windowheight = min( 700,  75 + 25 * self:htlen(self.db.profile.loothistory) )

	local f = AceGUI:Create("Window")
	self.lootTrackFrame = f
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
		hdrNotifications:SetRelativeWidth(relativewidth["btnalert"] + relativewidth["btnx"] + relativewidth["btnignore"])
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

	if not self.lootTrackFrameButtons then self.lootTrackFrameButtons = {} end
	if not self.db.profile.alreadyStarted then self.db.profile.alreadyStarted = {} end

	if CheeseSLSClient then
		if not CheeseSLSClient.db.profile.alertlist then CheeseSLSClient.db.profile.alertlist = {} end
		if not CheeseSLSClient.db.profile.ignorelist then CheeseSLSClient.db.profile.ignorelist = {} end
	end

	-- for presenting number at the end, if there are hidden entries
	local counthidden = 0

	-- keyset is now sorted in DESCENDING TIME
	for i = 1, #keyset do
		local historyid = keyset[i]
		local loot = self.db.profile.loothistory[ historyid ]

		-- set ignorance for CheeseSLSClient, if installed
		local itemIgnorance = self:determineItemIgnorance(tonumber(loot["itemId"]))
		if CheeseSLSClient and itemIgnorance then
			CheeseSLSClient.db.profile.ignorelist[tonumber(loot["itemId"])] = time()
		end

		if self.db.profile.limittwohour and tonumber(loot["queueTime"]) < twohoursago then
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
			lbIcon.paramItemLink = itemLink
			lbIcon:SetRelativeWidth(relativewidth["icon"])
			lbIcon:SetImage(itemTexture)
			lbIcon:SetImageSize(15,15)
			lbIcon:SetCallback("OnEnter", function(widget)
				GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
				GameTooltip:SetHyperlink(widget.paramItemLink)
				GameTooltip:Show()
			end)
			lbIcon:SetCallback("OnLeave", function(widget)
				GameTooltip:Hide()
			end)
			s:AddChild(lbIcon)

			local lbItem = AceGUI:Create("InteractiveLabel")
			lbItem.paramItemLink = itemLink
			lbItem:SetText(itemLink)
			lbItem:SetRelativeWidth(relativewidth["item"])
			lbItem:SetCallback("OnEnter", function(widget)
				GameTooltip:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
				GameTooltip:SetHyperlink(widget.paramItemLink)
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
				self.lootTrackFrameButtons["btnAlert" .. historyid] = btnAlert
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
				self.lootTrackFrameButtons["btnX" .. historyid] = btnX
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
				self.lootTrackFrameButtons["btnIgnore" .. historyid] = btnIgnore
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
				btnStart.history = historyid
				self.lootTrackFrameButtons["btnStart" .. historyid] = btnStart
				btnStart:SetText(L["SLS bid"])
				btnStart:SetRelativeWidth(relativewidth["btnstartbid"])
				btnStart:SetCallback("OnClick", function(widget)
					if CheeseSLS:StartBidding(widget.itemLink, widget.holdingPlayer, widget.historyid) then
						CheeseSLSLootTracker.db.profile.alreadyStarted[widget.historyid] = time()
						CheeseSLSLootTracker.lootTrackFrameButtons["btnStart" .. widget.historyid]:SetDisabled(true)
					end
				end)
				-- don't enable if already used
				if self.db.profile.alreadyStarted[historyid] then
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
			self.winnerLabels[historyid] = lbWinner


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
