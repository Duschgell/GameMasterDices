-------------------------
-- Game_master_dices.lua
-------------------------

-- 0) GLOBAL / LOCAL REFERENCES
local TRP3Loaded = false  -- Will be set to true when TotalRP3 is loaded.
local playerHistory     -- Stores dice roll results, keyed by a unique identifier.
local npcList           -- Array of NPC objects: { id = <number>, name = <string> }

-- Saved variables GMDicesDB will also store:
--   lastDiceSides: last entered dice value.
--   trp3Checked: whether the TRP3 checkbox was checked.

-------------------------
-- HELPER FUNCTIONS
-------------------------
-- Removes the realm part from a full name.
local function RemoveRealm(fullName)
    local dashPos = string.find(fullName, "-")
    if dashPos then
        return string.sub(fullName, 1, dashPos - 1)
    else
        return fullName
    end
end

-------------------------
-- TRP3 NAME & COLOR FUNCTION
-------------------------
local function GetRPNameAndColor(unitToken, engineName)
    local rpName, hexColor = nil, nil

    if trp3Checkbox and trp3Checkbox:GetChecked() and AddOn_TotalRP3 and AddOn_TotalRP3.Player then
        local playerObj = AddOn_TotalRP3.Player.CreateFromUnit(unitToken)
        if playerObj then
            rpName = playerObj:GetRoleplayingName() or ""
            rpName = rpName:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local customColor = playerObj:GetCustomColorForDisplay()
            if customColor then
                local r, g, b = customColor:GetRGB()
                hexColor = string.format("%02X%02X%02X", r * 255, g * 255, b * 255)
            end
        end
    end

    if not rpName or rpName == "" then
        rpName = engineName
    end

    if not hexColor or hexColor == "" then
        local _, class = UnitClass(unitToken)
        if class and RAID_CLASS_COLORS[class] then
            local color = RAID_CLASS_COLORS[class]
            hexColor = string.format("%02X%02X%02X", color.r * 255, color.g * 255, color.b * 255)
        else
            hexColor = "FFFFFF"
        end
    end

    return rpName, hexColor
end

-------------------------
-- 1) MAIN FRAME & UI SETUP
-------------------------
local rowHeight      = 50
local topRowsOffset  = 150
local extraMargin    = 40

local mainFrame = CreateFrame("Frame", "GMDiceMainFrame", UIParent, "BasicFrameTemplateWithInset")
mainFrame:SetSize(240, 240)
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:Hide()  -- Hide the frame on startup.

mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainFrame.title:SetPoint("LEFT", mainFrame.TitleBg, "LEFT", 5, 0)
mainFrame.title:SetText("Game Master Dices")

-- 1.1) DICE SIDES INPUT (default is 20)
local diceEditBox = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
diceEditBox:SetSize(35, 20)
diceEditBox:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -30)
diceEditBox:SetAutoFocus(false)
diceEditBox:SetNumeric(true)
diceEditBox:SetText("20")

local diceLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
diceLabel:SetPoint("LEFT", diceEditBox, "RIGHT", 5, 0)
diceLabel:SetText("Dice")

-- Save the last entered dice value when focus is lost.
diceEditBox:SetScript("OnEditFocusLost", function(self)
    GMDicesDB.lastDiceSides = self:GetText()
end)

-- 1.2) ROLL ALL & RESET ALL BUTTONS
local rollAllButton = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
rollAllButton:SetSize(80, 24)
rollAllButton:SetPoint("TOPLEFT", diceEditBox, "BOTTOMLEFT", 0, -20)
rollAllButton:SetText("Roll All")
rollAllButton:SetNormalFontObject("GameFontNormal")
rollAllButton:SetHighlightFontObject("GameFontHighlight")

local resetAllButton = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
resetAllButton:SetSize(80, 24)
resetAllButton:SetPoint("LEFT", rollAllButton, "RIGHT", 50, 0)
resetAllButton:SetText("Reset All")
resetAllButton:SetNormalFontObject("GameFontNormal")
resetAllButton:SetHighlightFontObject("GameFontHighlight")

-- 1.3) TRP3 CHECKBOX
local trp3Checkbox = CreateFrame("CheckButton", "GMDiceTRP3Check", mainFrame, "UICheckButtonTemplate")
trp3Checkbox:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -40, -25)
_G[trp3Checkbox:GetName().."Text"]:SetText("TRP3")
trp3Checkbox:SetScript("OnClick", function(self)
    GMDicesDB.trp3Checked = self:GetChecked()
    UpdateUI()
end)

-- 1.4) NPC CREATION
local npcInputBox = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
npcInputBox:SetSize(140, 20)
npcInputBox:SetPoint("TOPLEFT", rollAllButton, "BOTTOMLEFT", 0, -10)
npcInputBox:SetAutoFocus(false)
npcInputBox:SetText("")

local npcLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
npcLabel:SetPoint("LEFT", npcInputBox, "RIGHT", 5, 0)
npcLabel:SetText("Create NPC")

local function AddNPC(name)
    if not name or name:trim() == "" then return end
    GMDicesDB.npcIdCounter = (GMDicesDB.npcIdCounter or 0) + 1
    local newId = GMDicesDB.npcIdCounter
    table.insert(npcList, 1, { id = newId, name = name })
end

npcInputBox:SetScript("OnEnterPressed", function(self)
    AddNPC(self:GetText())
    self:SetText("")
    self:ClearFocus()
    UpdateUI()
end)

local addNPCButton = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
addNPCButton:SetSize(60, 20)
addNPCButton:SetPoint("TOPLEFT", npcLabel, "BOTTOMLEFT", -10, -2)
addNPCButton:SetText("Add")
addNPCButton:SetNormalFontObject("GameFontNormalSmall")
addNPCButton:SetHighlightFontObject("GameFontHighlightSmall")
addNPCButton:SetScript("OnClick", function()
    AddNPC(npcInputBox:GetText())
    npcInputBox:SetText("")
    npcInputBox:ClearFocus()
    UpdateUI()
end)

-------------------------
-- 2) TRP3 HELPER FUNCTION
-------------------------
local function GetRPNameAndColor(unitToken, engineName)
    local rpName, hexColor = nil, nil

    if trp3Checkbox and trp3Checkbox:GetChecked() and AddOn_TotalRP3 and AddOn_TotalRP3.Player then
        local playerObj = AddOn_TotalRP3.Player.CreateFromUnit(unitToken)
        if playerObj then
            rpName = playerObj:GetRoleplayingName() or ""
            rpName = rpName:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local customColor = playerObj:GetCustomColorForDisplay()
            if customColor then
                local r, g, b = customColor:GetRGB()
                hexColor = string.format("%02X%02X%02X", r * 255, g * 255, b * 255)
            end
        end
    end

    if not rpName or rpName == "" then
        rpName = engineName
    end

    if not hexColor or hexColor == "" then
        local _, class = UnitClass(unitToken)
        if class and RAID_CLASS_COLORS[class] then
            local color = RAID_CLASS_COLORS[class]
            hexColor = string.format("%02X%02X%02X", color.r * 255, color.g * 255, color.b * 255)
        else
            hexColor = "FFFFFF"
        end
    end

    return rpName, hexColor
end

-------------------------
-- 3) PLAYER & NPC ROWS
-------------------------
local playerRows = {}

local function RollDiceForKey(key, sides)
    local result = math.random(1, sides)
    if not playerHistory[key] then
        playerHistory[key] = {}
    end
    table.insert(playerHistory[key], 1, result)
    if #playerHistory[key] > 3 then
        table.remove(playerHistory[key], 4)
    end
    return result
end

local function GetGroupPlayers()
    local players = {}
    if IsInRaid() then
        local numRaid = GetNumGroupMembers()
        for i = 1, numRaid do
            local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
            if name and online then
                table.insert(players, { unit = "raid" .. i, name = RemoveRealm(name) })
            end
        end
    elseif IsInGroup() then
        table.insert(players, { unit = "player", name = RemoveRealm(UnitName("player")) })
        local numParty = GetNumGroupMembers() - 1
        for i = 1, numParty do
            local pName = UnitName("party" .. i)
            if pName then
                table.insert(players, { unit = "party" .. i, name = RemoveRealm(pName) })
            end
        end
    else
        table.insert(players, { unit = "player", name = RemoveRealm(UnitName("player")) })
    end
    return players
end

local function CreateOrUpdateRow(index, displayName, uniqueKey, xOffset, rowNum, unitToken)
    local row = playerRows[index]
    if not row then
        row = CreateFrame("Frame", nil, mainFrame)
        row:SetSize(mainFrame:GetWidth() - 20, rowHeight)
        
        row.nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.nameLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -10)
        
        row.rollButton = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        row.rollButton:SetSize(50, 20)
        row.rollButton:SetText("Roll")
        row.rollButton:SetNormalFontObject("GameFontNormalSmall")
        row.rollButton:SetHighlightFontObject("GameFontHighlightSmall")
        row.rollButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -10)
        
        row.historyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.historyLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -30)
        row.historyLabel:SetText("History:")
        
        row.resetButton = CreateFrame("Button", nil, row, "GameMenuButtonTemplate")
        row.resetButton:SetSize(50, 20)
        row.resetButton:SetText("Reset")
        row.resetButton:SetNormalFontObject("GameFontNormalSmall")
        row.resetButton:SetHighlightFontObject("GameFontHighlightSmall")
        row.resetButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -30)
        
        row.roll1 = row:CreateFontString(nil, "OVERLAY")
        row.roll1:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        row.roll2 = row:CreateFontString(nil, "OVERLAY")
        row.roll2:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        row.roll3 = row:CreateFontString(nil, "OVERLAY")
        row.roll3:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        
        row.roll1:SetPoint("LEFT", row.historyLabel, "RIGHT", 5, 0)
        row.roll2:SetPoint("LEFT", row.roll1, "RIGHT", 10, 0)
        row.roll3:SetPoint("LEFT", row.roll2, "RIGHT", 10, 0)
        
        row.removeButton = CreateFrame("Button", nil, row, "UIPanelCloseButton")
        row.removeButton:SetSize(18, 18)
        row.removeButton:SetPoint("LEFT", row.nameLabel, "RIGHT", 5, 0)
        row.removeButton:Hide()
        
        playerRows[index] = row
    end

    local finalName = displayName
    if not uniqueKey:find("^NPCID:") and unitToken then
        local rpName, cColor = GetRPNameAndColor(unitToken, displayName)
        finalName = "|cff" .. cColor .. rpName .. "|r"
    end

    row.nameLabel:SetText(finalName)
    local hist = playerHistory[uniqueKey] or {}
    row.roll1:SetText(hist[1] and tostring(hist[1]) or "")
    row.roll2:SetText(hist[2] and tostring(hist[2]) or "")
    row.roll3:SetText(hist[3] and tostring(hist[3]) or "")

    row.rollButton:SetScript("OnClick", function()
        local sides = tonumber(diceEditBox:GetText()) or 20
        local result = RollDiceForKey(uniqueKey, sides)
        UpdateUI()
    end)
    row.resetButton:SetScript("OnClick", function()
        playerHistory[uniqueKey] = {}
        UpdateUI()
    end)

    if uniqueKey:find("^NPCID:") then
        row.removeButton:Show()
        row.removeButton:SetScript("OnClick", function()
            local npcId = tonumber(uniqueKey:match("NPCID:(%d+)"))
            if npcId then
                for i, npcObj in ipairs(npcList) do
                    if npcObj.id == npcId then
                        table.remove(npcList, i)
                        break
                    end
                end
            end
            UpdateUI()
        end)
    else
        row.removeButton:Hide()
    end

    row:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", xOffset, -(topRowsOffset + (rowNum - 1) * rowHeight))
    row:Show()
    return row
end

-------------------------
-- 4) UPDATE UI (single column)
-------------------------
function UpdateUI()
    if not playerHistory or not npcList then return end

    local allRows = {}

    for _, npcObj in ipairs(npcList) do
        local uniqueKey = "NPCID:" .. npcObj.id
        local displayName = "NPC: " .. npcObj.name
        table.insert(allRows, { key = uniqueKey, label = displayName })
    end

    local groupPlayers = GetGroupPlayers()
    for _, entry in ipairs(groupPlayers) do
        table.insert(allRows, { key = entry.unit, label = entry.name, unit = entry.unit })
    end

    local totalRows = #allRows
    mainFrame:SetWidth(240)
    local newHeight = topRowsOffset + (totalRows * rowHeight) + extraMargin
    mainFrame:SetHeight(newHeight)

    for i, rowInfo in ipairs(allRows) do
        local xOffset = 10
        local rowNum = i
        CreateOrUpdateRow(i, rowInfo.label, rowInfo.key, xOffset, rowNum, rowInfo.unit)
    end

    for i = totalRows + 1, #playerRows do
        playerRows[i]:Hide()
    end
end

-------------------------
-- 5) ROLL ALL / RESET ALL BUTTONS
-------------------------
rollAllButton:SetScript("OnClick", function()
    local sides = tonumber(diceEditBox:GetText()) or 20

    for _, npcObj in ipairs(npcList) do
        local uniqueKey = "NPCID:" .. npcObj.id
        local displayName = "NPC: " .. npcObj.name
        local result = RollDiceForKey(uniqueKey, sides)
    end

    local groupPlayers = GetGroupPlayers()
    for _, entry in ipairs(groupPlayers) do
        local result = RollDiceForKey(entry.unit, sides)
    end

    UpdateUI()
end)

resetAllButton:SetScript("OnClick", function()
    for name in pairs(playerHistory) do
        playerHistory[name] = {}
    end
    UpdateUI()
end)

-------------------------
-- 6) REGISTER PREFIX
-------------------------
C_ChatInfo.RegisterAddonMessagePrefix("GMDiceRoll")

-------------------------
-- 7) GROUP/EVENT UPDATES
-------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function()
    UpdateUI()
end)

-------------------------
-- 8) SLASH COMMAND
-------------------------
SLASH_GMDICE1 = "/gmdice"
SlashCmdList["GMDICE"] = function()
    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        UpdateUI()
    end
end

-------------------------
-- 9) SAVED VARIABLES HANDLING
-------------------------
local savedVarsFrame = CreateFrame("Frame")
savedVarsFrame:RegisterEvent("ADDON_LOADED")
savedVarsFrame:RegisterEvent("PLAYER_LOGOUT")
savedVarsFrame:RegisterEvent("ADDON_LOADED")  -- for TRP3
savedVarsFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "Game_master_dices" then
            if not GMDicesDB then
                GMDicesDB = {}
            end
            if not GMDicesDB.playerHistory then
                GMDicesDB.playerHistory = {}
            end
            if not GMDicesDB.npcList then
                GMDicesDB.npcList = {}
            end
            for i = 1, #GMDicesDB.npcList do
                if type(GMDicesDB.npcList[i]) == "string" then
                    GMDicesDB.npcIdCounter = (GMDicesDB.npcIdCounter or 0) + 1
                    GMDicesDB.npcList[i] = { id = GMDicesDB.npcIdCounter, name = GMDicesDB.npcList[i] }
                end
            end

            playerHistory = GMDicesDB.playerHistory
            npcList       = GMDicesDB.npcList

            if GMDicesDB.lastDiceSides then
                diceEditBox:SetText(GMDicesDB.lastDiceSides)
            else
                diceEditBox:SetText("20")
            end

            if GMDicesDB.trp3Checked ~= nil then
                trp3Checkbox:SetChecked(GMDicesDB.trp3Checked)
            end

            UpdateUI()
        elseif arg1 == "TotalRP3" then
            TRP3Loaded = true
            UpdateUI()
        end
    elseif event == "PLAYER_LOGOUT" then
        if playerHistory then
            GMDicesDB.playerHistory = playerHistory
        end
        if npcList then
            GMDicesDB.npcList = npcList
        end
        GMDicesDB.lastDiceSides = diceEditBox:GetText()
        GMDicesDB.trp3Checked = trp3Checkbox:GetChecked()
    end
end)

-------------------------
-- 10) MINIMAP ICON
-------------------------
local LDB = LibStub("LibDataBroker-1.1", true)
if LDB then
    local dataobj = LDB:NewDataObject("GameMasterDices", {
        type = "launcher",
        text = "GMDice",
        icon = "Interface\\AddOns\\Game_master_dices\\Icon\\dice.tga",
        OnClick = function(_, button)
            if mainFrame:IsShown() then
                mainFrame:Hide()
            else
                mainFrame:Show()
                UpdateUI()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Game Master Dices")
            tooltip:AddLine("Left-click to toggle the dice window.")
        end,
    })
    local LibDBIcon = LibStub("LibDBIcon-1.0", true)
    if LibDBIcon then
        local defaults = { minimapPos = 220 }
        if not GMDicesDB then GMDicesDB = {} end
        LibDBIcon:Register("GameMasterDices", dataobj, GMDicesDB)
    end
end
