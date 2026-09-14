local addonName, OA = ...
_G.OmniAttendance = OA

OA.VERSION = "0.1.0"
OA.PREFIX = "|cff4fc3f7Omni Attendance|r: "

local function trim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function copyTable(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}
    for key, child in pairs(value) do
        result[copyTable(key)] = copyTable(child)
    end
    return result
end

local function sortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do
        table.insert(keys, key)
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    return keys
end

local function words(value)
    local result = {}
    for word in tostring(value or ""):gmatch("%S+") do
        table.insert(result, word)
    end
    return result
end

function OA:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(self.PREFIX .. tostring(message))
end

function OA:NormalizeName(name)
    name = trim(name)
    if name == "" then
        return nil
    end
    return string.lower(name)
end

function OA:DisplayName(name)
    name = trim(name)
    if name == "" then
        return nil
    end

    local character, realm = name:match("^([^%-]+)%-(.+)$")
    if character then
        character = character:sub(1, 1):upper() .. character:sub(2):lower()
        return character .. "-" .. realm
    end

    return name:sub(1, 1):upper() .. name:sub(2):lower()
end

function OA:InitializeDatabase()
    OmniAttendanceDB = OmniAttendanceDB or {}
    local db = OmniAttendanceDB

    db.schemaVersion = db.schemaVersion or 1
    db.settings = db.settings or {}
    db.settings.windowSize = tonumber(db.settings.windowSize) or 10
    db.settings.windowSize = math.max(1, math.floor(db.settings.windowSize))
    db.raids = db.raids or {}
    db.players = db.players or {}
    db.aliases = db.aliases or {}
    db.aliasNames = db.aliasNames or {}
    db.nextRaidNumber = tonumber(db.nextRaidNumber) or 1

    self.db = db
end

function OA:IsOfficer()
    if not IsInGroup() then
        return true
    end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function OA:RequireOfficer()
    if self:IsOfficer() then
        return true
    end
    self:Print("You must be the raid leader or an assistant to change attendance.")
    return false
end

function OA:RememberPlayer(mainKey, displayName)
    if not mainKey then
        return
    end

    self.db.players[mainKey] = self.db.players[mainKey] or {}
    if displayName and displayName ~= "" then
        self.db.players[mainKey].name = self:DisplayName(displayName)
    elseif not self.db.players[mainKey].name then
        self.db.players[mainKey].name = self:DisplayName(mainKey)
    end
end

function OA:ResolveMain(characterName)
    local characterKey = self:NormalizeName(characterName)
    if not characterKey then
        return nil
    end
    return self.db.aliases[characterKey] or characterKey
end

function OA:GetPlayerName(mainKey)
    local player = self.db.players[mainKey]
    return player and player.name or self:DisplayName(mainKey)
end

function OA:GetAliases(mainKey)
    local aliases = {}
    for aliasKey, targetKey in pairs(self.db.aliases) do
        if targetKey == mainKey then
            table.insert(aliases, self.db.aliasNames[aliasKey] or self:DisplayName(aliasKey))
        end
    end
    table.sort(aliases)
    return aliases
end

local function mergeRosterEntry(target, source)
    target.present = target.present or source.present
    target.characters = target.characters or {}
    for character, included in pairs(source.characters or {}) do
        if included then
            target.characters[character] = true
        end
    end
    if target.source ~= source.source then
        target.source = "mixed"
    end
    if trim(target.notes) == "" then
        target.notes = source.notes
    end
end

function OA:SetAlias(altName, mainName)
    if not self:RequireOfficer() then
        return false
    end

    local altKey = self:NormalizeName(altName)
    local mainKey = self:NormalizeName(mainName)
    if not altKey or not mainKey then
        self:Print("Usage: /oa alias Alt Main")
        return false
    end
    if altKey == mainKey then
        self:Print("An alias and its main cannot be the same character.")
        return false
    end

    local resolvedMain = self.db.aliases[mainKey] or mainKey
    if resolvedMain == altKey then
        self:Print("That alias would create a loop.")
        return false
    end

    self.db.aliases[altKey] = resolvedMain
    self.db.aliasNames[altKey] = self:DisplayName(altName)
    self:RememberPlayer(resolvedMain, mainName)

    local containers = {}
    for _, raid in ipairs(self.db.raids) do
        table.insert(containers, raid.roster)
    end
    if self.db.draft then
        table.insert(containers, self.db.draft.roster)
    end

    for _, roster in ipairs(containers) do
        local oldEntry = roster and roster[altKey]
        if oldEntry then
            roster[resolvedMain] = roster[resolvedMain] or {
                mainName = self:GetPlayerName(resolvedMain),
                present = false,
                characters = {},
                source = oldEntry.source,
                notes = oldEntry.notes,
            }
            mergeRosterEntry(roster[resolvedMain], oldEntry)
            roster[resolvedMain].mainName = self:GetPlayerName(resolvedMain)
            roster[altKey] = nil
        end
    end

    self:Print(("%s now credits attendance to %s. Existing history was updated."):format(
        self:DisplayName(altName),
        self:GetPlayerName(resolvedMain)
    ))
    self:RefreshUI()
    return true
end

function OA:RemoveAlias(altName)
    if not self:RequireOfficer() then
        return false
    end

    local altKey = self:NormalizeName(altName)
    if not altKey or not self.db.aliases[altKey] then
        self:Print("No matching alias was found.")
        return false
    end

    self.db.aliases[altKey] = nil
    self.db.aliasNames[altKey] = nil
    self:Print("Alias removed. Existing raid records remain credited to their saved main.")
    self:RefreshUI()
    return true
end

function OA:AddCharacterToRoster(roster, characterName, mainName, source)
    local characterKey = self:NormalizeName(characterName)
    if not characterKey then
        return false
    end

    local mainKey
    if mainName and trim(mainName) ~= "" then
        local requestedMainKey = self:NormalizeName(mainName)
        mainKey = self.db.aliases[requestedMainKey] or requestedMainKey
        if characterKey ~= mainKey then
            self.db.aliases[characterKey] = mainKey
            self.db.aliasNames[characterKey] = self:DisplayName(characterName)
        end
    else
        mainKey = self:ResolveMain(characterName)
    end

    self:RememberPlayer(mainKey, mainName or characterName)
    roster[mainKey] = roster[mainKey] or {
        mainName = self:GetPlayerName(mainKey),
        present = true,
        characters = {},
        source = source or "manual",
        notes = "",
    }
    roster[mainKey].present = true
    roster[mainKey].characters[self:DisplayName(characterName)] = true
    if roster[mainKey].source ~= (source or "manual") then
        roster[mainKey].source = "mixed"
    end
    return true
end

function OA:CaptureCurrentGroup(roster)
    local count = GetNumGroupMembers()
    if IsInRaid() then
        for index = 1, count do
            local name = GetUnitName("raid" .. index, true)
            if name then
                self:AddCharacterToRoster(roster, name, nil, "group")
            end
        end
    elseif IsInGroup() then
        local playerName = GetUnitName("player", true)
        if playerName then
            self:AddCharacterToRoster(roster, playerName, nil, "group")
        end
        for index = 1, math.max(0, count - 1) do
            local name = GetUnitName("party" .. index, true)
            if name then
                self:AddCharacterToRoster(roster, name, nil, "group")
            end
        end
    else
        local name = GetUnitName("player", true)
        if name then
            self:AddCharacterToRoster(roster, name, nil, "group")
        end
    end
end

function OA:DefaultRaidName()
    local instanceName = GetInstanceInfo()
    if instanceName and instanceName ~= "" then
        return instanceName
    end
    return "Official Raid"
end

function OA:StartRaid(name)
    if not self:RequireOfficer() then
        return false
    end
    if self.db.draft then
        self:Print("A draft already exists. Save or cancel it before starting another raid.")
        return false
    end

    local now = GetServerTime()
    self.db.draft = {
        name = trim(name) ~= "" and trim(name) or self:DefaultRaidName(),
        date = date("%Y-%m-%d %H:%M", now),
        createdAt = now,
        roster = {},
    }
    self:CaptureCurrentGroup(self.db.draft.roster)
    self:Print(("Draft started with %d credited player(s). Review it, then use /oa save."):format(
        self:CountPresent(self.db.draft.roster)
    ))
    self:Show()
    self:RefreshUI()
    return true
end

function OA:AddToDraft(characterName, mainName)
    if not self:RequireOfficer() then
        return false
    end
    if not self.db.draft then
        self:Print("Start a draft first with /oa start [raid name].")
        return false
    end
    if not self:AddCharacterToRoster(self.db.draft.roster, characterName, mainName, "manual") then
        self:Print("Usage: /oa add Character [Main]")
        return false
    end
    self:Print(("%s was added to the draft."):format(self:DisplayName(characterName)))
    self:RefreshUI()
    return true
end

function OA:RemoveFromDraft(characterName)
    if not self:RequireOfficer() then
        return false
    end
    if not self.db.draft then
        self:Print("There is no active draft.")
        return false
    end

    local characterKey = self:NormalizeName(characterName)
    local mainKey = self:ResolveMain(characterName)
    local entry = mainKey and self.db.draft.roster[mainKey]
    if not entry then
        self:Print("That player is not in the draft.")
        return false
    end

    local display = self:DisplayName(characterName)
    if entry.characters and entry.characters[display] and self:NormalizeName(entry.mainName) ~= characterKey then
        entry.characters[display] = nil
        if not next(entry.characters) then
            self.db.draft.roster[mainKey] = nil
        end
    else
        self.db.draft.roster[mainKey] = nil
    end

    self:Print(("%s was removed from the draft."):format(display))
    self:RefreshUI()
    return true
end

function OA:CountPresent(roster)
    local count = 0
    for _, entry in pairs(roster or {}) do
        if entry.present then
            count = count + 1
        end
    end
    return count
end

function OA:SaveDraft()
    if not self:RequireOfficer() then
        return false
    end
    local draft = self.db.draft
    if not draft then
        self:Print("There is no active draft.")
        return false
    end
    if self:CountPresent(draft.roster) == 0 then
        self:Print("The draft has no credited players and was not saved.")
        return false
    end

    local now = GetServerTime()
    if draft.editingRaidID then
        local raid = self:FindRaid(draft.editingRaidID)
        if not raid then
            self:Print("The raid being edited no longer exists.")
            return false
        end
        raid.name = trim(draft.name) ~= "" and trim(draft.name) or raid.name
        raid.date = draft.date or raid.date
        raid.roster = copyTable(draft.roster)
        raid.updatedAt = now
        self:Print(("Raid #%d was updated."):format(raid.sequence))
    else
        local sequence = self.db.nextRaidNumber
        local raid = {
            id = tostring(now) .. "-" .. tostring(sequence),
            sequence = sequence,
            name = trim(draft.name) ~= "" and trim(draft.name) or self:DefaultRaidName(),
            date = draft.date or date("%Y-%m-%d %H:%M", now),
            createdAt = draft.createdAt or now,
            updatedAt = now,
            roster = copyTable(draft.roster),
            voided = false,
        }
        table.insert(self.db.raids, raid)
        self.db.nextRaidNumber = sequence + 1
        self:Print(("Raid #%d saved with %d credited player(s)."):format(sequence, self:CountPresent(raid.roster)))
    end

    self.db.draft = nil
    self:RefreshUI()
    return true
end

function OA:CancelDraft()
    if not self:RequireOfficer() then
        return false
    end
    if not self.db.draft then
        self:Print("There is no active draft.")
        return false
    end
    self.db.draft = nil
    self:Print("Draft discarded. No attendance was recorded.")
    self:RefreshUI()
    return true
end

function OA:FindRaid(identifier)
    identifier = trim(identifier)
    if identifier == "" then
        return nil
    end

    for _, raid in ipairs(self.db.raids) do
        if raid.id == identifier or tostring(raid.sequence) == identifier then
            return raid
        end
    end

    local match
    for _, raid in ipairs(self.db.raids) do
        if raid.id:sub(1, #identifier) == identifier then
            if match then
                return nil
            end
            match = raid
        end
    end
    return match
end

function OA:EditRaid(identifier)
    if not self:RequireOfficer() then
        return false
    end
    if self.db.draft then
        self:Print("Save or cancel the current draft before editing history.")
        return false
    end

    local raid = self:FindRaid(identifier)
    if not raid then
        self:Print("Raid not found. Use /oa raids to see raid numbers.")
        return false
    end

    self.db.draft = {
        editingRaidID = raid.id,
        name = raid.name,
        date = raid.date,
        createdAt = raid.createdAt,
        roster = copyTable(raid.roster),
    }
    self:Print(("Editing raid #%d. Save to apply changes or cancel to keep the archive unchanged."):format(raid.sequence))
    self:Show()
    self:RefreshUI()
    return true
end

function OA:SetRaidVoided(identifier, voided)
    if not self:RequireOfficer() then
        return false
    end

    local raid = self:FindRaid(identifier)
    if not raid then
        self:Print("Raid not found.")
        return false
    end

    raid.voided = voided and true or false
    raid.updatedAt = GetServerTime()
    self:Print(("Raid #%d is now %s. Its archived data was not deleted."):format(
        raid.sequence,
        raid.voided and "voided" or "active"
    ))
    self:RefreshUI()
    return true
end

function OA:GetRecentRaids()
    local active = {}
    for _, raid in ipairs(self.db.raids) do
        if not raid.voided then
            table.insert(active, raid)
        end
    end
    table.sort(active, function(left, right)
        return (left.sequence or 0) < (right.sequence or 0)
    end)

    local result = {}
    local first = math.max(1, #active - self.db.settings.windowSize + 1)
    for index = first, #active do
        table.insert(result, active[index])
    end
    return result
end

function OA:GetScores()
    local scores = {}
    for mainKey in pairs(self.db.players) do
        scores[mainKey] = 0
    end
    for _, mainKey in pairs(self.db.aliases) do
        scores[mainKey] = scores[mainKey] or 0
    end

    for _, raid in ipairs(self:GetRecentRaids()) do
        for mainKey, entry in pairs(raid.roster or {}) do
            scores[mainKey] = scores[mainKey] or 0
            if entry.present then
                scores[mainKey] = scores[mainKey] + 1
            end
        end
    end
    return scores
end

function OA:SetWindowSize(value)
    if not self:RequireOfficer() then
        return false
    end

    value = tonumber(value)
    if not value or value < 1 or value > 100 then
        self:Print("Window size must be a whole number from 1 to 100.")
        return false
    end

    self.db.settings.windowSize = math.floor(value)
    self:Print(("Attendance now uses the latest %d official raid(s). Archived raids were retained."):format(
        self.db.settings.windowSize
    ))
    self:RefreshUI()
    return true
end

local function csvCell(value)
    value = tostring(value or "")
    if value:find('[,"\n\r]') then
        value = '"' .. value:gsub('"', '""') .. '"'
    end
    return value
end

local function csvRow(values)
    local escaped = {}
    for index, value in ipairs(values) do
        escaped[index] = csvCell(value)
    end
    return table.concat(escaped, ",")
end

function OA:ExportSummary()
    local raids = self:GetRecentRaids()
    local scores = self:GetScores()
    local header = {
        "Player",
        "Attended",
        "RaidsInWindow",
        "AttendanceBonus",
        "GargulPoints",
        "Aliases",
    }

    for _, raid in ipairs(raids) do
        table.insert(header, ("#%d %s %s"):format(raid.sequence, raid.date, raid.name))
    end

    local lines = { csvRow(header) }
    for _, mainKey in ipairs(sortedKeys(scores)) do
        local score = scores[mainKey]
        local row = {
            self:GetPlayerName(mainKey),
            score,
            #raids,
            score,
            100 + score,
            table.concat(self:GetAliases(mainKey), " | "),
        }
        for _, raid in ipairs(raids) do
            local entry = raid.roster and raid.roster[mainKey]
            table.insert(row, entry and entry.present and 1 or 0)
        end
        table.insert(lines, csvRow(row))
    end
    return table.concat(lines, "\n")
end

function OA:ExportHistory()
    local lines = {
        csvRow({ "RaidID", "RaidNumber", "Date", "Raid", "Status", "Player", "Present", "Characters", "Source", "Notes" })
    }

    local raids = copyTable(self.db.raids)
    table.sort(raids, function(left, right)
        return (left.sequence or 0) < (right.sequence or 0)
    end)

    for _, raid in ipairs(raids) do
        local roster = raid.roster or {}
        if not next(roster) then
            table.insert(lines, csvRow({
                raid.id, raid.sequence, raid.date, raid.name, raid.voided and "Voided" or "Active", "", "", "", "", "",
            }))
        else
            for _, mainKey in ipairs(sortedKeys(roster)) do
                local entry = roster[mainKey]
                table.insert(lines, csvRow({
                    raid.id,
                    raid.sequence,
                    raid.date,
                    raid.name,
                    raid.voided and "Voided" or "Active",
                    entry.mainName or self:GetPlayerName(mainKey),
                    entry.present and "Yes" or "No",
                    table.concat(sortedKeys(entry.characters), " | "),
                    entry.source or "",
                    entry.notes or "",
                }))
            end
        end
    end
    return table.concat(lines, "\n")
end

function OA:ExportGargul()
    local scores = self:GetScores()
    local lines = {}

    for _, mainKey in ipairs(sortedKeys(scores)) do
        local row = { self:GetPlayerName(mainKey), 100 + scores[mainKey] }
        for _, alias in ipairs(self:GetAliases(mainKey)) do
            table.insert(row, alias)
        end
        table.insert(lines, csvRow(row))
    end
    return table.concat(lines, "\n")
end

function OA:ShowExport(kind)
    kind = string.lower(trim(kind))
    local title
    local content
    if kind == "history" then
        title = "Full Attendance History CSV"
        content = self:ExportHistory()
    elseif kind == "gargul" then
        title = "Gargul Boosted Rolls Import"
        content = self:ExportGargul()
    else
        title = "Rolling Attendance Summary CSV"
        content = self:ExportSummary()
    end

    if content == "" then
        self:Print("There is no attendance data to export.")
        return
    end
    self:OpenExportWindow(title, content)
end

function OA:SyncGargul()
    if not self:RequireOfficer() then
        return false
    end

    local GL = _G.Gargul
    if not GL or not GL.BoostedRolls or type(GL.BoostedRolls.import) ~= "function" then
        self:Print("Gargul 8.0.0 or a compatible version must be enabled.")
        return false
    end

    local data = self:ExportGargul()
    if data == "" then
        self:Print("There is no attendance data to sync.")
        return false
    end

    local imported = GL.BoostedRolls:import(data, false)
    if not imported then
        self:Print("Gargul did not accept the attendance data.")
        return false
    end

    if GL.Settings and type(GL.Settings.set) == "function" then
        GL.Settings:set("BoostedRolls.enabled", true)
        GL.Settings:set("BoostedRolls.defaultPoints", 100)
        GL.Settings:set("BoostedRolls.reserveThreshold", 0)
        GL.Settings:set("BoostedRolls.system", 0)
    end

    self:Print(("Gargul synced for %d player(s). Use /oa broadcast if you want to share it now."):format(
        #sortedKeys(self:GetScores())
    ))
    return true
end

function OA:BroadcastGargul()
    if not self:RequireOfficer() then
        return false
    end

    local GL = _G.Gargul
    if not GL or not GL.BoostedRolls or type(GL.BoostedRolls.broadcast) ~= "function" then
        self:Print("Gargul 8.0.0 or a compatible version must be enabled.")
        return false
    end

    return GL.BoostedRolls:broadcast()
end

function OA:ListRaids()
    if #self.db.raids == 0 then
        self:Print("No official raids have been saved.")
        return
    end

    local first = math.max(1, #self.db.raids - 14)
    self:Print("Recent archived raids:")
    for index = #self.db.raids, first, -1 do
        local raid = self.db.raids[index]
        self:Print(("#%d | %s | %s | %d present%s | ID %s"):format(
            raid.sequence,
            raid.date,
            raid.name,
            self:CountPresent(raid.roster),
            raid.voided and " | VOIDED" or "",
            raid.id
        ))
    end
end

function OA:ShowHelp()
    self:Print("Commands: start, add, remove, save, cancel, raids, edit, void, restore, alias, unalias, window, export, sync, broadcast")
    self:Print("Use /oa export summary, /oa export history, or /oa export gargul.")
end

function OA:HandleSlash(message)
    local command, remainder = tostring(message or ""):match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")
    remainder = trim(remainder)

    if command == "" then
        self:Toggle()
    elseif command == "start" then
        self:StartRaid(remainder)
    elseif command == "add" then
        local args = words(remainder)
        self:AddToDraft(args[1], args[2])
    elseif command == "remove" then
        self:RemoveFromDraft(remainder)
    elseif command == "save" then
        self:SaveDraft()
    elseif command == "cancel" then
        self:CancelDraft()
    elseif command == "raids" or command == "history" then
        self:ListRaids()
    elseif command == "edit" then
        self:EditRaid(remainder)
    elseif command == "void" then
        self:SetRaidVoided(remainder, true)
    elseif command == "restore" then
        self:SetRaidVoided(remainder, false)
    elseif command == "alias" then
        local args = words(remainder)
        self:SetAlias(args[1], args[2])
    elseif command == "unalias" then
        self:RemoveAlias(remainder)
    elseif command == "window" then
        self:SetWindowSize(remainder)
    elseif command == "export" then
        self:ShowExport(remainder)
    elseif command == "sync" then
        self:SyncGargul()
    elseif command == "broadcast" then
        self:BroadcastGargul()
    elseif command == "help" then
        self:ShowHelp()
    else
        self:Print("Unknown command.")
        self:ShowHelp()
    end
end

function OA:RefreshUI()
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon ~= addonName then
        return
    end

    OA:InitializeDatabase()
    SLASH_OMNIATTENDANCE1 = "/oa"
    SLASH_OMNIATTENDANCE2 = "/omniattendance"
    SlashCmdList.OMNIATTENDANCE = function(message)
        OA:HandleSlash(message)
    end

    OA:Print(("v%s loaded. Type /oa help for commands."):format(OA.VERSION))
end)
