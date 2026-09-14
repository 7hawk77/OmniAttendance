local _, OA = ...

OA.UI = OA.UI or {}
local UI = OA.UI

local function makeButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 110, height or 24)
    button:SetText(text)
    return button
end

local function makeEditBox(parent, width, height)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width or 150, height or 24)
    box:SetAutoFocus(false)
    box:SetMaxLetters(100)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    return box
end

local function joinCharacters(characters)
    local names = {}
    for name, included in pairs(characters or {}) do
        if included then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return table.concat(names, ", ")
end

function UI:CreateMainWindow()
    if self.Frame then
        return self.Frame
    end

    local frame = CreateFrame("Frame", "OmniAttendanceMainFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(790, 610)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()
    tinsert(UISpecialFrames, frame:GetName())

    frame.TitleText:SetText("Omni Attendance")
    self.Frame = frame

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", 16, -34)
    subtitle:SetText("Official raids are recorded only when you save a reviewed draft.")
    self.Subtitle = subtitle

    local raidNameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    raidNameLabel:SetPoint("TOPLEFT", 16, -60)
    raidNameLabel:SetText("Raid name")

    local raidNameBox = makeEditBox(frame, 260, 24)
    raidNameBox:SetPoint("LEFT", raidNameLabel, "RIGHT", 12, 0)
    raidNameBox:SetScript("OnTextChanged", function(box, userInput)
        if userInput and OA.db and OA.db.draft then
            OA.db.draft.name = box:GetText()
        end
    end)
    self.RaidNameBox = raidNameBox

    local startButton = makeButton(frame, "Start Raid", 95)
    startButton:SetPoint("LEFT", raidNameBox, "RIGHT", 8, 0)
    startButton:SetScript("OnClick", function()
        OA:StartRaid(raidNameBox:GetText())
    end)

    local saveButton = makeButton(frame, "Save Raid", 95)
    saveButton:SetPoint("LEFT", startButton, "RIGHT", 6, 0)
    saveButton:SetScript("OnClick", function()
        OA:SaveDraft()
    end)
    self.SaveButton = saveButton

    local cancelButton = makeButton(frame, "Cancel Draft", 100)
    cancelButton:SetPoint("LEFT", saveButton, "RIGHT", 6, 0)
    cancelButton:SetScript("OnClick", function()
        OA:CancelDraft()
    end)
    self.CancelButton = cancelButton

    local rosterTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rosterTitle:SetPoint("TOPLEFT", 16, -98)
    rosterTitle:SetText("Draft roster")
    self.RosterTitle = rosterTitle

    local rosterHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rosterHint:SetPoint("TOPLEFT", rosterTitle, "BOTTOMLEFT", 0, -5)
    rosterHint:SetText("Uncheck a player to record them as absent. Alts are shown beside their main.")

    local rosterBorder = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
    rosterBorder:SetPoint("TOPLEFT", 16, -134)
    rosterBorder:SetSize(472, 324)

    local scroll = CreateFrame("ScrollFrame", "OmniAttendanceRosterScrollFrame", rosterBorder, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(420, 1)
    scroll:SetScrollChild(scrollChild)
    self.RosterScrollChild = scrollChild
    self.RosterRows = {}

    local manualLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    manualLabel:SetPoint("TOPLEFT", rosterBorder, "BOTTOMLEFT", 0, -16)
    manualLabel:SetText("Manual attendance correction")

    local characterBox = makeEditBox(frame, 150, 24)
    characterBox:SetPoint("TOPLEFT", manualLabel, "BOTTOMLEFT", 5, -7)
    characterBox:SetText("")
    self.CharacterBox = characterBox

    local characterHint = characterBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    characterHint:SetPoint("TOPLEFT", characterBox, "BOTTOMLEFT", -5, -2)
    characterHint:SetText("Character or alt")

    local mainBox = makeEditBox(frame, 150, 24)
    mainBox:SetPoint("LEFT", characterBox, "RIGHT", 14, 0)
    self.MainBox = mainBox

    local mainHint = mainBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    mainHint:SetPoint("TOPLEFT", mainBox, "BOTTOMLEFT", -5, -2)
    mainHint:SetText("Main (optional)")

    local addButton = makeButton(frame, "Add / Credit", 120)
    addButton:SetPoint("LEFT", mainBox, "RIGHT", 12, 0)
    addButton:SetScript("OnClick", function()
        if OA:AddToDraft(characterBox:GetText(), mainBox:GetText()) then
            characterBox:SetText("")
            mainBox:SetText("")
        end
    end)

    local windowLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    windowLabel:SetPoint("TOPLEFT", 16, -526)
    windowLabel:SetText("Rolling raid window")

    local windowBox = makeEditBox(frame, 52, 24)
    windowBox:SetPoint("LEFT", windowLabel, "RIGHT", 10, 0)
    windowBox:SetNumeric(true)
    self.WindowBox = windowBox

    local applyWindowButton = makeButton(frame, "Apply", 64)
    applyWindowButton:SetPoint("LEFT", windowBox, "RIGHT", 7, 0)
    applyWindowButton:SetScript("OnClick", function()
        OA:SetWindowSize(windowBox:GetText())
    end)

    local exportSummaryButton = makeButton(frame, "Summary CSV", 105)
    exportSummaryButton:SetPoint("TOPLEFT", 16, -564)
    exportSummaryButton:SetScript("OnClick", function()
        OA:ShowExport("summary")
    end)

    local exportHistoryButton = makeButton(frame, "History CSV", 105)
    exportHistoryButton:SetPoint("LEFT", exportSummaryButton, "RIGHT", 6, 0)
    exportHistoryButton:SetScript("OnClick", function()
        OA:ShowExport("history")
    end)

    local exportGargulButton = makeButton(frame, "Gargul CSV", 105)
    exportGargulButton:SetPoint("LEFT", exportHistoryButton, "RIGHT", 6, 0)
    exportGargulButton:SetScript("OnClick", function()
        OA:ShowExport("gargul")
    end)

    local syncButton = makeButton(frame, "Sync Gargul", 105)
    syncButton:SetPoint("LEFT", exportGargulButton, "RIGHT", 14, 0)
    syncButton:SetScript("OnClick", function()
        OA:SyncGargul()
    end)

    local broadcastButton = makeButton(frame, "Broadcast", 95)
    broadcastButton:SetPoint("LEFT", syncButton, "RIGHT", 6, 0)
    broadcastButton:SetScript("OnClick", function()
        OA:BroadcastGargul()
    end)

    local sideTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    sideTitle:SetPoint("TOPLEFT", 510, -98)
    sideTitle:SetText("Current standing")

    local standingText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    standingText:SetPoint("TOPLEFT", sideTitle, "BOTTOMLEFT", 0, -10)
    standingText:SetWidth(250)
    standingText:SetJustifyH("LEFT")
    standingText:SetJustifyV("TOP")
    self.StandingText = standingText

    local recentTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    recentTitle:SetPoint("TOPLEFT", 510, -310)
    recentTitle:SetText("Recent raids")

    local recentText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    recentText:SetPoint("TOPLEFT", recentTitle, "BOTTOMLEFT", 0, -10)
    recentText:SetWidth(250)
    recentText:SetJustifyH("LEFT")
    recentText:SetJustifyV("TOP")
    self.RecentText = recentText

    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("BOTTOMRIGHT", -16, 12)
    footer:SetText("Corrections: /oa raids, /oa edit #, /oa void #")

    return frame
end

function UI:RefreshRoster()
    local child = self.RosterScrollChild
    if not child then
        return
    end

    for _, row in ipairs(self.RosterRows) do
        row:Hide()
    end

    local draft = OA.db and OA.db.draft
    local keys = {}
    if draft then
        for key in pairs(draft.roster or {}) do
            table.insert(keys, key)
        end
        table.sort(keys, function(left, right)
            return OA:GetPlayerName(left) < OA:GetPlayerName(right)
        end)
    end

    for index, mainKey in ipairs(keys) do
        local row = self.RosterRows[index]
        if not row then
            row = CreateFrame("CheckButton", nil, child, "UICheckButtonTemplate")
            row:SetSize(410, 24)
            row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.Text:SetPoint("LEFT", row, "LEFT", 28, 0)
            row.Text:SetWidth(370)
            row.Text:SetJustifyH("LEFT")
            self.RosterRows[index] = row
        end

        local entry = draft.roster[mainKey]
        row:SetPoint("TOPLEFT", 0, -(index - 1) * 25)
        row:SetChecked(entry.present and true or false)
        local characters = joinCharacters(entry.characters)
        local suffix = characters ~= "" and ("  |cff888888(" .. characters .. ")|r") or ""
        row.Text:SetText((entry.mainName or OA:GetPlayerName(mainKey)) .. suffix)
        row:SetScript("OnClick", function(button)
            entry.present = button:GetChecked() and true or false
            UI:Refresh()
        end)
        row:Show()
    end

    child:SetHeight(math.max(1, #keys * 25))
    self.RosterTitle:SetText(("Draft roster (%d credited / %d listed)"):format(
        draft and OA:CountPresent(draft.roster) or 0,
        #keys
    ))
end

function UI:RefreshStanding()
    local scores = OA:GetScores()
    local rows = {}
    for mainKey, score in pairs(scores) do
        table.insert(rows, {
            name = OA:GetPlayerName(mainKey),
            score = score,
        })
    end
    table.sort(rows, function(left, right)
        if left.score == right.score then
            return left.name < right.name
        end
        return left.score > right.score
    end)

    local lines = {
        ("Latest %d official raid(s)"):format(OA.db.settings.windowSize),
        "",
    }
    if #rows == 0 then
        table.insert(lines, "No attendance recorded yet.")
    else
        for index = 1, math.min(10, #rows) do
            local row = rows[index]
            table.insert(lines, ("%s  +%d  (%d)"):format(row.name, row.score, 100 + row.score))
        end
        if #rows > 10 then
            table.insert(lines, ("...and %d more"):format(#rows - 10))
        end
    end
    self.StandingText:SetText(table.concat(lines, "\n"))
end

function UI:RefreshRecent()
    local lines = {}
    local raids = OA.db.raids
    if #raids == 0 then
        table.insert(lines, "No archived raids.")
    else
        local first = math.max(1, #raids - 8)
        for index = #raids, first, -1 do
            local raid = raids[index]
            table.insert(lines, ("#%d  %s"):format(raid.sequence, raid.name))
            table.insert(lines, ("|cff999999%s · %d present%s|r"):format(
                raid.date,
                OA:CountPresent(raid.roster),
                raid.voided and " · VOIDED" or ""
            ))
        end
    end
    self.RecentText:SetText(table.concat(lines, "\n"))
end

function UI:Refresh()
    if not self.Frame or not self.Frame:IsShown() or not OA.db then
        return
    end

    local draft = OA.db.draft
    self.RaidNameBox:SetText(draft and draft.name or "")
    self.SaveButton:SetEnabled(draft ~= nil)
    self.CancelButton:SetEnabled(draft ~= nil)
    self.CharacterBox:SetEnabled(draft ~= nil)
    self.MainBox:SetEnabled(draft ~= nil)
    self.WindowBox:SetText(tostring(OA.db.settings.windowSize))

    if draft and draft.editingRaidID then
        self.Subtitle:SetText("Editing archived raid " .. draft.editingRaidID .. ". Saving updates the existing record.")
    elseif draft then
        self.Subtitle:SetText("Draft only—attendance is not official until you press Save Raid.")
    else
        self.Subtitle:SetText("No active draft. Nothing is being recorded automatically.")
    end

    self:RefreshRoster()
    self:RefreshStanding()
    self:RefreshRecent()
end

function OA:Show()
    local frame = UI:CreateMainWindow()
    frame:Show()
    UI:Refresh()
end

function OA:Toggle()
    local frame = UI:CreateMainWindow()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        UI:Refresh()
    end
end

function OA:OpenExportWindow(title, content)
    if not UI.ExportFrame then
        local frame = CreateFrame("Frame", "OmniAttendanceExportFrame", UIParent, "BasicFrameTemplateWithInset")
        frame:SetSize(720, 520)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetClampedToScreen(true)
        frame:Hide()
        tinsert(UISpecialFrames, frame:GetName())

        local instruction = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        instruction:SetPoint("TOPLEFT", 16, -35)
        instruction:SetText("Press Ctrl+C to copy. Paste into Google Sheets, Discord, or Gargul as appropriate.")

        local border = CreateFrame("Frame", nil, frame, "InsetFrameTemplate3")
        border:SetPoint("TOPLEFT", 14, -58)
        border:SetPoint("BOTTOMRIGHT", -14, 48)

        local scroll = CreateFrame("ScrollFrame", "OmniAttendanceExportScrollFrame", border, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", -28, 8)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(650)
        edit:SetTextInsets(4, 4, 4, 4)
        edit:SetMaxLetters(999999)
        edit:SetScript("OnEscapePressed", function()
            frame:Hide()
        end)
        edit:SetScript("OnCursorChanged", function(_, _, y, _, cursorHeight)
            local scrollTop = scroll:GetVerticalScroll()
            local scrollBottom = scrollTop + scroll:GetHeight()
            if -y < scrollTop then
                scroll:SetVerticalScroll(-y)
            elseif -y + cursorHeight > scrollBottom then
                scroll:SetVerticalScroll(-y + cursorHeight - scroll:GetHeight())
            end
        end)
        scroll:SetScrollChild(edit)

        local closeButton = makeButton(frame, "Close", 100)
        closeButton:SetPoint("BOTTOM", 0, 14)
        closeButton:SetScript("OnClick", function()
            frame:Hide()
        end)

        UI.ExportFrame = frame
        UI.ExportEditBox = edit
    end

    UI.ExportFrame.TitleText:SetText(title)
    UI.ExportEditBox:SetText(content)
    local lineCount = 1
    for _ in content:gmatch("\n") do
        lineCount = lineCount + 1
    end
    UI.ExportEditBox:SetHeight(math.max(420, lineCount * 15 + 20))
    UI.ExportFrame:Show()
    UI.ExportEditBox:SetFocus()
    UI.ExportEditBox:HighlightText()
end
