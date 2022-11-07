local L = LibStub("AceLocale-3.0"):NewLocale("CheeseSLSLootTracker", "deDE", false)

if L then

-- configs

L["Enabled"] = "Aktiv"
L["Debug"] = "Debug"

L["is enabled."] = "ist aktiv."
L["is disabled."] = "ist deaktiviert."

L["2 hr view limit"] = "Zeige 2 Std"
L["Limit shown loot to two hours (tradeable time window)"] = "Zeige nur Loot der letzten 2 Stunden (noch handelbar)"
L["2 hr deletion"] = "Lösche nach 2 Std"
L["Delete loot older than two hours (tradeable time window) from tracker"] = "Lösche Loot älter als zwei Stunden (nicht mehr handelbar) aus der Liste"
L["# loot items"] = "# Gegenstände"
L["Number of loot items stored in DB"] = "Anzahl der Gegenstände in der Loot-Liste"
L["Clear loot table"] = "Lösche Loot-Liste"

-- gui

L["No loot history to show"] = "Keine Loot-Historie zum Anzeigen"
L["SLS Loot History"] = "SLS Loot-Historie"
L["Alert"] = "Alarm"
L["Ignore"] = "Ignorieren"
L["SLS bid"] = "SLS bieten"
L["hidden entries"] = function(counthidden) return tostring(counthidden) .. " nicht angezeigte Einträge" end
L["Disable limiting to 2 hours"] = "Limitierung auf 2 Std aufheben"

end