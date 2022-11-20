
-- share information between GoogleSheetDKP and CheeseSLS Client

function CheeseSLSLootTracker:OnCommReceivedGSDKP(prefix, message, distribution, sender)
	-- playerName may contain "-REALM"
	sender = strsplit("-", sender)

	local success, d = self:Deserialize(message);

	-- every thing else get handled if (if not disabled)
	if not success then
		self:Debug("ERROR: " .. distribution .. " message from " .. sender .. ": cannot be deserialized")
		return
	end

	if d["command"] == "DKP_RESULT" then
		if d["playerName"] == UnitName["player"] then
			-- will accept the first result. If there are multiple, first wins. Let's hope they are in sync.
			self.GSDKP_RequestIssued = nil
			self.GSDKP_DKP = d["dkp"]
		end
	end

end

-- send out "new" loot to other CheeseSLSLootTracker

function CheeseSLSLootTracker:sendDKPRequest()
	local commmsg = { command = "DKP_REQUEST" }
	-- we might want to use this in near-realtime. so, let's go for QoS for a quick turnaround
	self:SendCommMessage(self.commPrefixGSDKP, self:Serialize(commmsg), "RAID", nil, "ALERT")
	self.GSDKP_RequestIssued = time()
end
