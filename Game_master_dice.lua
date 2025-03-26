-------------------------
-- Game_master_dice.lua
-------------------------
-- Main module for Game Master Dice.
-- Initializes the UI, handles dice rolling, and applies color mappings.

local addonObj = _G.GMDice and _G.GMDice.AceAddonObj
if not addonObj then
    error("AceAddon instance not yet available. Ensure settings.lua is loaded before Game_master_dice.lua")
end

-- Ensure the GetColorForRoll method is attached.
if not addonObj.GetColorForRoll then
  function addonObj:GetColorForRoll(diceSides, rollValue)
    local key = tostring(diceSides)
    local profiles = self.db.profile.diceProfiles
    local prof = profiles and profiles[key]
    if not prof or not prof.mappings then
      return "FFFFFF"
    end
    local matches = {}
    for _, mapping in ipairs(prof.mappings) do
      local pass = false
      local op = mapping.op
      local thr = mapping.threshold or 1
      local thr2 = mapping.threshold2 or 1
      if op == "=" then
        pass = (rollValue == thr)
      elseif op == "!=" then
        pass = (rollValue ~= thr)
      elseif op == "<" then
        pass = (rollValue < thr)
      elseif op == "<=" then
        pass = (rollValue <= thr)
      elseif op == ">" then
        pass = (rollValue > thr)
      elseif op == ">=" then
        pass = (rollValue >= thr)
      elseif op == "range" then
        local low = math.min(thr, thr2)
        local high = math.max(thr, thr2)
        pass = (rollValue >= low and rollValue <= high)
      end
      if pass then
        table.insert(matches, mapping)
      end
    end
    if #matches == 0 then
      return "FFFFFF"
    end
    local bestColor = "FFFFFF"
    local bestValue = math.huge
    for _, m in ipairs(matches) do
      local tmin = (m.op == "range") and math.min(m.threshold or 1, m.threshold2 or 1) or (m.threshold or 1)
      if tmin < bestValue then
        bestValue = tmin
        bestColor = m.color or "FFFFFF"
      end
    end
    return bestColor
  end
end

-- Helper: Convert a hex color string to RGB values (0–1)
local function HexToRGB(hex)
    local r = tonumber(hex:sub(1,2), 16) / 255
    local g = tonumber(hex:sub(3,4), 16) / 255
    local b = tonumber(hex:sub(5,6), 16) / 255
    return r, g, b
end

--------------------------------------------------------------------------------
-- Initialization of the Dice Module (Deferred until AceDB is ready)
--------------------------------------------------------------------------------
local function InitializeDiceModule()
    if _G.GMDice.Initialized then return end
    _G.GMDice.Initialized = true

    local function DB()
        return _G.GMDice.AceAddonObj.db.profile
    end

    ------------------------------------------------------------------------
    -- Helper Functions
    ------------------------------------------------------------------------
    local function RemoveRealm(fullName)
        local dashPos = string.find(fullName, "-")
        if dashPos then
            return string.sub(fullName, 1, dashPos - 1)
        end
        return fullName
    end

    local function GetRPNameAndColor(unitToken, engineName)
        if DB().trp3Checked and AddOn_TotalRP3 and AddOn_TotalRP3.Player then
            local playerObj = AddOn_TotalRP3.Player.CreateFromUnit(unitToken)
            if playerObj then
                local rpName = playerObj:GetRoleplayingName() or ""
                rpName = rpName:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                local customColor = playerObj:GetCustomColorForDisplay()
                if customColor then
                    local r, g, b = customColor:GetRGB()
                    local hexColor = string.format("%02X%02X%02X", r*255, g*255, b*255)
                    if rpName ~= "" then
                        return rpName, hexColor
                    end
                end
                if rpName ~= "" then
                    local _, class = UnitClass(unitToken)
                    if class and RAID_CLASS_COLORS[class] then
                        local color = RAID_CLASS_COLORS[class]
                        local hexColor = string.format("%02X%02X%02X", color.r*255, color.g*255, color.b*255)
                        return rpName, hexColor
                    else
                        return rpName, "FFFFFF"
                    end
                end
            end
        end
        local _, class = UnitClass(unitToken)
        local classColor = "FFFFFF"
        if class and RAID_CLASS_COLORS[class] then
            local color = RAID_CLASS_COLORS[class]
            classColor = string.format("%02X%02X%02X", color.r*255, color.g*255, color.b*255)
        end
        return engineName, classColor
    end

    ------------------------------------------------------------------------
    -- UI Setup
    ------------------------------------------------------------------------
    local rowHeight     = 50
    local topRowsOffset = 130  -- Adjusted for improved layout
    local extraMargin   = 40

    local mainFrame = CreateFrame("Frame", "GMDiceMainFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(240, 240)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
    mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
    mainFrame:Hide()

    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainFrame.title:SetPoint("LEFT", mainFrame.TitleBg, "LEFT", 5, 0)
    mainFrame.title:SetText("Game Master Dice")

    mainFrame:SetAlpha(DB().opacity or 1)
    _G.GMDice.MainFrame = mainFrame

    -- Dice sides input
    local diceEditBox = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
    diceEditBox:SetSize(35, 20)
    diceEditBox:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 15, -30)
    diceEditBox:SetAutoFocus(false)
    diceEditBox:SetNumeric(true)
    diceEditBox:SetText(DB().lastDiceSides or 20)
    diceEditBox:SetScript("OnEditFocusLost", function(self)
        local val = tonumber(self:GetText()) or 20
        DB().lastDiceSides = val
        if DB().diceProfiles[tostring(val)] then
            self:SetTextColor(0.8, 0.8, 0.8)
        else
            self:SetTextColor(1, 1, 1)
        end
    end)
    do
        local sides = tonumber(diceEditBox:GetText()) or 20
        if DB().diceProfiles[tostring(sides)] then
            diceEditBox:SetTextColor(0.8, 0.8, 0.8)
        else
            diceEditBox:SetTextColor(1, 1, 1)
        end
    end

    local diceLabel = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    diceLabel:SetPoint("LEFT", diceEditBox, "RIGHT", 5, 0)
    diceLabel:SetText("Dice")

    -- Roll All and Reset All buttons
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

    -- NPC Creation (Input and Button; "Create NPC" button text size increased)
    local npcInputBox = CreateFrame("EditBox", nil, mainFrame, "InputBoxTemplate")
    npcInputBox:SetSize(125, 20)
    npcInputBox:SetPoint("TOPLEFT", rollAllButton, "BOTTOMLEFT", 0, -10)
    npcInputBox:SetAutoFocus(false)
    npcInputBox:SetText("")

    local npcButton = CreateFrame("Button", nil, mainFrame, "GameMenuButtonTemplate")
    npcButton:SetSize(80, 24)
    npcButton:SetPoint("LEFT", npcInputBox, "RIGHT", 5, 0)
    npcButton:SetText("Create NPC")
    npcButton:SetNormalFontObject("GameFontNormal")
    npcButton:SetScript("OnClick", function()
        local text = npcInputBox:GetText()
        if text and text:trim() ~= "" then
            DB().npcIdCounter = (DB().npcIdCounter or 0) + 1
            table.insert(DB().npcList, 1, { id = DB().npcIdCounter, name = text })
            npcInputBox:SetText("")
            npcInputBox:ClearFocus()
            UpdateUI()
        end
    end)

    ------------------------------------------------------------------------
    -- Roll Functions and Group Player/NPC Handling
    ------------------------------------------------------------------------
    local function RollDiceForKey(key, sides)
        local result = math.random(1, sides)
        local history = DB().playerHistory
        if not history[key] then
            history[key] = {}
        end
        local maxHistory = DB().historyLength or 3
        table.insert(history[key], 1, result)
        while #history[key] > maxHistory do
            table.remove(history[key], maxHistory + 1)
        end
        return result
    end

    local function GetGroupPlayers()
        local players = {}
        if IsInRaid() then
            for i = 1, GetNumGroupMembers() do
                local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
                if name and online then
                    table.insert(players, { unit = "raid" .. i, name = RemoveRealm(name) })
                end
            end
        elseif IsInGroup() then
            table.insert(players, { unit = "player", name = RemoveRealm(UnitName("player")) })
            for i = 1, (GetNumGroupMembers() - 1) do
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

    local function UpdateRollColorsForRow(row, uniqueKey)
        local sides = tonumber(diceEditBox:GetText()) or 20
        local history = DB().playerHistory[uniqueKey] or {}
        local maxHistory = DB().historyLength or 3
        for i = 1, maxHistory do
            local rollField = row.rollFields[i]
            if rollField then
                if history[i] then
                    local colorHex = addonObj:GetColorForRoll(sides, tonumber(history[i]) or 0)
                    local r, g, b = HexToRGB(colorHex)
                    rollField:SetTextColor(r, g, b)
                else
                    rollField:SetTextColor(1, 1, 1)
                end
            end
        end
    end

    ------------------------------------------------------------------------
    -- Create or Update Player/NPC Rows
    ------------------------------------------------------------------------
    local playerRows = {}
    local function CreateOrUpdateRow(index, displayName, uniqueKey, xOffset, rowNum, unitToken)
        local maxHistory = DB().historyLength or 3
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

            row.rollFields = {}
            for i = 1, maxHistory do
                local rollField = row:CreateFontString(nil, "OVERLAY")
                local fontSize = (i <= 3) and (16 - (i - 1) * 4) or 8
                rollField:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
                if i == 1 then
                    rollField:SetPoint("LEFT", row.historyLabel, "RIGHT", 5, 0)
                else
                    rollField:SetPoint("LEFT", row.rollFields[i-1], "RIGHT", 10, 0)
                end
                row.rollFields[i] = rollField
            end

            row.removeButton = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            row.removeButton:SetSize(18, 18)
            row.removeButton:SetPoint("LEFT", row.nameLabel, "RIGHT", 5, 0)
            row.removeButton:Hide()

            playerRows[index] = row
        else
            for i = #row.rollFields + 1, maxHistory do
                local rollField = row:CreateFontString(nil, "OVERLAY")
                local fontSize = (i <= 3) and (16 - (i - 1) * 4) or 8
                rollField:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
                if i == 1 then
                    rollField:SetPoint("LEFT", row.historyLabel, "RIGHT", 5, 0)
                else
                    rollField:SetPoint("LEFT", row.rollFields[i-1], "RIGHT", 10, 0)
                end
                row.rollFields[i] = rollField
            end
            for i = maxHistory + 1, #row.rollFields do
                row.rollFields[i]:Hide()
            end
        end

        local finalName = displayName
        if not uniqueKey:find("^NPCID:") and unitToken then
            local rpName, cColor = GetRPNameAndColor(unitToken, displayName)
            finalName = "|cff" .. cColor .. rpName .. "|r"
        end
        row.nameLabel:SetText(finalName)

        local history = DB().playerHistory[uniqueKey] or {}
        for i = 1, maxHistory do
            if row.rollFields[i] then
                row.rollFields[i]:SetText(history[i] and tostring(history[i]) or "")
                row.rollFields[i]:Show()
            end
        end

        row.rollButton:SetScript("OnClick", function()
            local sides = tonumber(diceEditBox:GetText()) or 20
            RollDiceForKey(uniqueKey, sides)
            UpdateUI()
            UpdateRollColorsForRow(row, uniqueKey)
        end)

        row.resetButton:SetScript("OnClick", function()
            DB().playerHistory[uniqueKey] = {}
            UpdateUI()
        end)

        if uniqueKey:find("^NPCID:") then
            row.removeButton:Show()
            row.removeButton:SetScript("OnClick", function()
                local npcId = tonumber(uniqueKey:match("NPCID:(%d+)"))
                if npcId then
                    for i, npcObj in ipairs(DB().npcList) do
                        if npcObj.id == npcId then
                            table.remove(DB().npcList, i)
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
        UpdateRollColorsForRow(row, uniqueKey)
        return row
    end

    function UpdateUI()
        if not DB().playerHistory or not DB().npcList then return end
        local allRows = {}
        for _, npcObj in ipairs(DB().npcList) do
            table.insert(allRows, { key = "NPCID:" .. npcObj.id, label = "NPC: " .. npcObj.name })
        end
        for _, ply in ipairs(GetGroupPlayers()) do
            table.insert(allRows, { key = ply.unit, label = ply.name, unit = ply.unit })
        end

        local totalRows = #allRows
        mainFrame:SetWidth(240)
        mainFrame:SetHeight(topRowsOffset + (totalRows * rowHeight) + extraMargin)
        for i, rowInfo in ipairs(allRows) do
            CreateOrUpdateRow(i, rowInfo.label, rowInfo.key, 10, i, rowInfo.unit)
        end
        for i = totalRows + 1, #playerRows do
            playerRows[i]:Hide()
        end
    end

    ------------------------------------------------------------------------
    -- Roll All and Reset All Buttons
    ------------------------------------------------------------------------
    rollAllButton:SetScript("OnClick", function()
        local sides = tonumber(diceEditBox:GetText()) or 20
        for _, npcObj in ipairs(DB().npcList) do
            RollDiceForKey("NPCID:" .. npcObj.id, sides)
        end
        for _, ply in ipairs(GetGroupPlayers()) do
            RollDiceForKey(ply.unit, sides)
        end
        UpdateUI()
    end)

    resetAllButton:SetScript("OnClick", function()
        for k in pairs(DB().playerHistory) do
            DB().playerHistory[k] = {}
        end
        UpdateUI()
    end)

    ------------------------------------------------------------------------
    -- Addon Communication and Events
    ------------------------------------------------------------------------
    C_ChatInfo.RegisterAddonMessagePrefix("GMDiceRoll")
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "Game_master_dice" then
            UpdateUI()
        end
    end)

    SLASH_GMDICE1 = "/gmdice"
    SlashCmdList["GMDICE"] = function()
        if mainFrame:IsShown() then
            mainFrame:Hide()
        else
            mainFrame:Show()
            UpdateUI()
        end
    end

    ------------------------------------------------------------------------
    -- Minimap Icon Setup
    ------------------------------------------------------------------------
    local LDB = LibStub("LibDataBroker-1.1", true)
    if LDB then
        local dataObj = LDB:NewDataObject("GameMasterDice", {
            type = "launcher",
            text = "GMDice",
            icon = "Interface/Icons/inv_misc_dice_02",
            OnClick = function()
                if mainFrame:IsShown() then
                    mainFrame:Hide()
                else
                    mainFrame:Show()
                    UpdateUI()
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("Game Master Dice")
                tooltip:AddLine("Left-click to toggle the dice window.")
            end,
        })
        local LibDBIcon = LibStub("LibDBIcon-1.0", true)
        if LibDBIcon then
            LibDBIcon:Register("GameMasterDice", dataObj, DB())
        end
    end
end

--------------------------------------------------------------------------------
-- Initialize the Dice Module when AceDB is ready.
--------------------------------------------------------------------------------
if _G.GMDice and _G.GMDice.AceAddonObj then
    local origOnEnable = _G.GMDice.AceAddonObj.OnEnable or function() end
    _G.GMDice.AceAddonObj.OnEnable = function(self, ...)
        origOnEnable(self, ...)
        InitializeDiceModule()
    end
else
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, event, addon)
        if addon == "Game_master_dice" then
            if _G.GMDice and _G.GMDice.AceAddonObj and _G.GMDice.AceAddonObj.db then
                InitializeDiceModule()
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- End of Game_master_dice.lua
--------------------------------------------------------------------------------
