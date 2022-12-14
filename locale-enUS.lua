local L = LibStub("AceLocale-3.0"):NewLocale("CheeseSLSLootTracker", "enUS", true)

if L then

-- configs

L["Enabled"] = "Enabled"
L["Debug"] = "Debug"

L["Track Trash"] = "Track all loot"
L["Track Trash items for debugging"] = "Track all loot (from grays) for debugging"

L["Auto Ignore"] = "Auto Ignore"
L["Automatically ignore unwearable items (e.g. plate for cloth classes or wands for meelees)"] = "Automatically ignore unwearable items (e.g. plate for cloth classes or wands for meelees)"

L["is enabled."] = "ist enabled."
L["is disabled."] = "ist disabled."

L["2 hr view limit"] = "2 hr view limit"
L["Limit shown loot to two hours (tradeable time window)"] = "Limit shown loot to two hours (tradeable time window)"
L["2 hr deletion"] = "2 hr deletion"
L["Delete loot older than two hours (tradeable time window) from tracker"] = "Delete loot older than two hours (tradeable time window) from tracker"
L["# loot items"] = "# loot items"
L["Number of loot items stored in DB"] = "Number of loot items stored in DB"
L["Clear loot table"] = "Clear loot table"
L["Send loot table"] = "Send loot table"
L["Send loot table to all other players"] = "Send loot table to all other players"

-- gui

L["No loot history to show"] = "No loot history to show"
L["SLS Loot History"] = "SLS Loot History"
L["Alert"] = "Alert"
L["Ignore"] = "Ignore"
L["SLS bid"] = "SLS"
L["hidden entries"] = function(counthidden) return tostring(counthidden) .. " hidden entries" end
L["Disable limiting to 2 hours"] = "Disable limiting to 2 hours"

end -- if L then




