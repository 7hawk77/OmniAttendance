local failures = 0

local function expect(condition, message)
    if not condition then
        failures = failures + 1
        io.stderr:write("FAIL: " .. message .. "\n")
    end
end

local messages = {}
DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, message)
        table.insert(messages, message)
    end,
}

local serverTime = 1000
local groupNames = { "Mainone-Realm", "Altone-Realm", "Absent-Realm" }

GetServerTime = function()
    return serverTime
end
date = os.date
GetBuildInfo = function()
    return "1.16.1", "12345", "Oct 14 2026", 16001
end
GetInstanceInfo = function()
    return "Test Raid"
end
GetNumGroupMembers = function()
    return #groupNames
end
IsInRaid = function()
    return true
end
IsInGroup = function()
    return true
end
UnitIsGroupLeader = function()
    return true
end
UnitIsGroupAssistant = function()
    return false
end
GetUnitName = function(unit)
    local index = tonumber(unit:match("raid(%d+)$"))
    return index and groupNames[index] or "Mainone-Realm"
end

local eventHandler
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(_, event, handler)
            if event == "OnEvent" then
                eventHandler = handler
            end
        end,
    }
end

SlashCmdList = {}
C_AddOns = {
    GetAddOnMetadata = function(addon, field)
        if addon == "Gargul" and field == "Version" then
            return "8.0.1"
        end
    end,
}

local importedData
local settings = {}
Gargul = {
    _initialized = true,
    BoostedRolls = {
        import = function(_, data)
            importedData = data
            return true
        end,
        broadcast = function()
            return true
        end,
    },
    Settings = {
        set = function(_, key, value)
            settings[key] = value
        end,
    },
}

OmniAttendanceDB = nil
local OA = {}
local chunk = assert(loadfile("Core.lua"))
chunk("OmniAttendance", OA)
eventHandler(nil, "ADDON_LOADED", "OmniAttendance")

expect(OA.db ~= nil, "database initializes")
expect(#OA.db.raids == 0, "no raid is recorded on load")

OA:SetAlias("Altone-Realm", "Mainone-Realm")
OA:StartRaid("Molten Core")
expect(#OA.db.raids == 0, "starting creates only a draft")
expect(OA.db.draft ~= nil, "draft exists after start")
expect(OA:CountPresent(OA.db.draft.roster) == 2, "alt and main consolidate into one attendance credit")

OA.db.draft.roster[OA:ResolveMain("Absent-Realm")].present = false
OA:SaveDraft()
expect(#OA.db.raids == 1, "save creates one official raid")
expect(OA.db.draft == nil, "draft clears after save")

for index = 2, 11 do
    serverTime = serverTime + 1
    groupNames = { "Mainone-Realm" }
    OA:StartRaid("Raid " .. index)
    OA:SaveDraft()
end

local scores = OA:GetScores()
local mainKey = OA:ResolveMain("Mainone-Realm")
expect(scores[mainKey] == 10, "rolling score uses the latest ten raids")
expect(#OA.db.raids == 11, "older raids remain archived")

local summary = OA:ExportSummary()
expect(summary:find("GargulPoints", 1, true) ~= nil, "summary CSV has its header")
expect(summary:find("Mainone%-Realm") ~= nil, "summary CSV includes the main")

expect(OA:SyncGargul(), "Gargul sync succeeds")
expect(importedData and importedData:find(",110", 1, true), "Gargul receives 100 plus attendance")
expect(settings["BoostedRolls.enabled"] == true, "Boosted Rolls are enabled")
expect(settings["BoostedRolls.defaultPoints"] == 100, "Gargul default points are 100")
expect(settings["BoostedRolls.reserveThreshold"] == 0, "Gargul reserve threshold is disabled")
expect(settings["BoostedRolls.system"] == 0, "Gargul uses Increased Both")

OA:ShowStatus()
expect(messages[#messages]:find("Forever interface detected correctly", 1, true) ~= nil, "status detects Forever")

if failures > 0 then
    os.exit(1)
end

print("OmniAttendance core tests passed")
