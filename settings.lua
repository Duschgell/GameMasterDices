-------------------------
-- settings.lua
-------------------------
-- Global namespace and AceAddon initialization
local ADDON_NAME, GMDice = ...
_G.GMDice = GMDice  -- Make addon namespace global

local AceAddon = LibStub("AceAddon-3.0")
local GameMasterDice = AceAddon:NewAddon("GameMasterDice", "AceConsole-3.0", "AceEvent-3.0")

-- AceDB defaults (saved in GameMasterDiceDB)
local defaults = {
  profile = {
    trp3Checked       = false,
    opacity           = 1,
    lastDiceSides     = 20,
    npcList           = {},
    playerHistory     = {},
    npcIdCounter      = 0,
    historyLength     = 3,    -- Number of roll results to keep (1–5)
    diceProfiles      = {},   -- Dice profiles keyed by dice sides as string
    activeDiceProfile = nil,  -- Currently active profile key
  },
}

local AceConfig         = LibStub("AceConfig-3.0", true)
local AceConfigDialog   = LibStub("AceConfigDialog-3.0", true)
local AceDB             = LibStub("AceDB-3.0", true)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)

--------------------------------------------------------------------------------
-- Dice Profiles & Mappings Options
--------------------------------------------------------------------------------
local mappingsListGroup = {
  type = "group",
  name = "Mappings",
  order = 2,
  args = {}  -- Dynamically filled
}

local function RebuildMappingsListArgs()
  if not GameMasterDice.db or not GameMasterDice.db.profile then
    for k in pairs(mappingsListGroup.args) do
      mappingsListGroup.args[k] = nil
    end
    return
  end

  local profiles = GameMasterDice.db.profile.diceProfiles or {}
  local active = GameMasterDice.db.profile.activeDiceProfile

  -- Clear old entries
  for k in pairs(mappingsListGroup.args) do
    mappingsListGroup.args[k] = nil
  end

  if not active or not profiles[active] or not profiles[active].mappings then
    return
  end

  for i, mapping in ipairs(profiles[active].mappings) do
    mappingsListGroup.args["mapping" .. i] = {
      type = "group",
      name = "Mapping " .. i,
      order = i,
      inline = true,
      args = {
        op = {
          type = "select",
          name = "Operator",
          desc = "Comparison operator for this roll condition",
          order = 1,
          values = {
            ["="]      = "Equal",
            ["!="]     = "Not equal",
            ["<"]      = "Less than",
            ["<="]     = "Less or equal",
            [">"]      = "Greater than",
            [">="]     = "Greater or equal",
            ["range"]  = "Between",
          },
          set = function(info, val)
            mapping.op = val
            RebuildMappingsListArgs()
            AceConfigRegistry:NotifyChange("GameMasterDice")
          end,
          get = function(info)
            return mapping.op
          end,
          width = "third",
        },
        threshold = {
          type = "input",
          name = function()
            return (mapping.op == "range") and "Min Value" or "Roll Value"
          end,
          desc = "The roll value (or minimum if using 'Between')",
          order = 2,
          set = function(info, val)
            mapping.threshold = tonumber(val) or mapping.threshold
            RebuildMappingsListArgs()
            AceConfigRegistry:NotifyChange("GameMasterDice")
          end,
          get = function(info)
            return tostring(mapping.threshold or 1)
          end,
          width = "half",
        },
        threshold2 = {
          type = "input",
          name = "Max Value",
          desc = "The upper bound if operator is 'Between'",
          order = 3,
          hidden = function() return mapping.op ~= "range" end,
          set = function(info, val)
            mapping.threshold2 = tonumber(val) or mapping.threshold2
            RebuildMappingsListArgs()
            AceConfigRegistry:NotifyChange("GameMasterDice")
          end,
          get = function(info)
            return tostring(mapping.threshold2 or 1)
          end,
          width = "half",
        },
        color = {
          type = "color",
          name = "Color",
          desc = "Pick the color for this roll condition",
          order = 4,
          set = function(info, r, g, b)
            mapping.color = string.format("%02X%02X%02X", r * 255, g * 255, b * 255)
            RebuildMappingsListArgs()
            AceConfigRegistry:NotifyChange("GameMasterDice")
          end,
          get = function(info)
            local col = mapping.color or "FFFFFF"
            local r = tonumber(col:sub(1,2), 16) / 255
            local g = tonumber(col:sub(3,4), 16) / 255
            local b = tonumber(col:sub(5,6), 16) / 255
            return r, g, b, 1
          end,
          width = "half",
        },
        removeMapping = {
          type = "execute",
          name = "Remove",
          desc = "Remove this mapping",
          order = 5,
          func = function()
            local profiles = GameMasterDice.db.profile.diceProfiles or {}
            local active = GameMasterDice.db.profile.activeDiceProfile
            table.remove(profiles[active].mappings, i)
            RebuildMappingsListArgs()
            AceConfigRegistry:NotifyChange("GameMasterDice")
          end,
        },
      },
    }
  end
end

local profilesGroup = {
  type = "group",
  name = "Dice Profiles",
  order = 2,
  args = {
    createNewProfile = {
      type = "input",
      name = "New Profile",
      desc = "Enter dice sides (e.g., 20) to create a new profile",
      order = 1,
      set = function(info, val)
        local sides = tonumber(val)
        if sides then
          local key = tostring(sides)
          local profiles = GameMasterDice.db.profile.diceProfiles or {}
          if not profiles[key] then
            profiles[key] = { mappings = {} }
            GameMasterDice.db.profile.diceProfiles = profiles
            GameMasterDice.db.profile.activeDiceProfile = key
            RebuildMappingsListArgs()
            AceConfigRegistry:NotifyChange("GameMasterDice")
          else
            print("Profile for dice " .. key .. " already exists.")
          end
        end
      end,
      get = function(info)
        return ""
      end,
      width = "half",
    },
    selectProfile = {
      type = "select",
      name = "Select Profile",
      desc = "Select a profile for configuration",
      order = 2,
      values = function()
        local profiles = GameMasterDice.db.profile.diceProfiles or {}
        local vals = {}
        for k, _ in pairs(profiles) do
          vals[k] = k 
        end
        return vals
      end,
      set = function(info, val)
        GameMasterDice.db.profile.activeDiceProfile = val
        RebuildMappingsListArgs()
        AceConfigRegistry:NotifyChange("GameMasterDice")
      end,
      get = function(info)
        return GameMasterDice.db.profile.activeDiceProfile or ""
      end,
      width = "half",
    },
    deleteProfile = {
      type = "execute",
      name = "Delete Profile",
      desc = "Delete the currently selected profile",
      order = 3,
      confirm = true,
      confirmText = "Are you sure you want to delete this profile?",
      func = function()
        local active = GameMasterDice.db.profile.activeDiceProfile
        if not active or active == "" then
          print("No profile selected.")
          return
        end
        local profiles = GameMasterDice.db.profile.diceProfiles
        if profiles and profiles[active] then
          profiles[active] = nil
          GameMasterDice.db.profile.activeDiceProfile = nil
          RebuildMappingsListArgs()
          AceConfigRegistry:NotifyChange("GameMasterDice")
        end
      end,
    },
    mappingsGroup = {
      type = "group",
      name = "Profile Mappings",
      order = 4,
      inline = true,
      args = {
        addMapping = {
          type = "execute",
          name = "Add Mapping",
          desc = "Add a new roll mapping",
          order = 1,
          func = function()
            local profiles = GameMasterDice.db.profile.diceProfiles or {}
            local active = GameMasterDice.db.profile.activeDiceProfile
            if active and profiles[active] then
              local mapping = { op = "=", threshold = 1, color = "FFFFFF" }
              table.insert(profiles[active].mappings, mapping)
              RebuildMappingsListArgs()
              AceConfigRegistry:NotifyChange("GameMasterDice")
            else
              print("No active profile. Please create or select a profile first.")
            end
          end,
        },
        mappingsList = {
          type = "group",
          name = "Mappings",
          order = 2,
          args = mappingsListGroup.args,
        },
      },
    },
  },
}

--------------------------------------------------------------------------------
-- Main Options Table
--------------------------------------------------------------------------------
local options = {
  type = "group",
  name = "Game Master Dice",
  childGroups = "tab",
  args = {
    general = {
      type = "group",
      name = "General",
      order = 1,
      args = {
        header1 = {
          type  = "header",
          name  = "Game Master Dice Settings",
          order = 10,
        },
        trp3Integration = {
          type  = "toggle",
          name  = "Enable TRP3",
          desc  = "Use TRP3 roleplay names & colors.",
          order = 20,
          set   = function(info, val)
                    GameMasterDice.db.profile.trp3Checked = val
                    if GameMasterDice.UpdateUI then
                      GameMasterDice:UpdateUI()
                    end
                  end,
          get   = function(info)
                    return GameMasterDice.db.profile.trp3Checked
                  end,
          width = "full",
        },
        frameOpacity = {
          type  = "range",
          name  = "Frame Opacity",
          desc  = "Adjust dice frame transparency.",
          order = 30,
          min   = 0.1,
          max   = 1.0,
          step  = 0.01,
          set   = function(info, val)
                    GameMasterDice.db.profile.opacity = val
                    if GMDice and GMDice.MainFrame then
                      GMDice.MainFrame:SetAlpha(val)
                    end
                  end,
          get   = function(info)
                    return GameMasterDice.db.profile.opacity
                  end,
          width = "full",
        },
        lastDiceSides = {
          type  = "input",
          name  = "Default Dice Sides",
          desc  = "Default number of dice sides.",
          order = 40,
          set   = function(info, val)
                    local num = tonumber(val)
                    if num then
                      GameMasterDice.db.profile.lastDiceSides = num
                    end
                  end,
          get   = function(info)
                    return tostring(GameMasterDice.db.profile.lastDiceSides or 20)
                  end,
        },
        historyLength = {
          type  = "range",
          name  = "History Length",
          desc  = "Set how many roll results to keep (1–5).",
          order = 50,
          min   = 1,
          max   = 5,
          step  = 1,
          set   = function(info, val)
                    GameMasterDice.db.profile.historyLength = tonumber(val)
                  end,
          get   = function(info)
                    return tonumber(GameMasterDice.db.profile.historyLength) or 3
                  end,
          width = "full",
        },
      },
    },
    profiles = profilesGroup,
  },
}

--------------------------------------------------------------------------------
-- Register Options and Slash Command
--------------------------------------------------------------------------------
function GameMasterDice:OnInitialize()
  self.db = AceDB:New("GameMasterDiceDB", defaults, true)
  if AceConfig and AceConfigDialog then
    AceConfig:RegisterOptionsTable("GameMasterDice", options)
    AceConfigDialog:AddToBlizOptions("GameMasterDice", "Game Master Dice")
  end
  self:RegisterChatCommand("gmdiceoptions", function()
    if AceConfigDialog then
      AceConfigDialog:Open("GameMasterDice")
    end
  end)
  RebuildMappingsListArgs()
end

function GameMasterDice:OnEnable()
  if GMDice and GMDice.MainFrame then
    GMDice.MainFrame:SetAlpha(self.db.profile.opacity or 1)
  end
end

function GameMasterDice:OnDisable()
  -- Optional disable behavior.
end

_G.GMDice.AceAddonObj = GameMasterDice

--------------------------------------------------------------------------------
-- End of settings.lua
--------------------------------------------------------------------------------
