local addonName, ns = ...
local EMA_Cooldowns = LibStub("AceAddon-3.0"):NewAddon("EMA_Cooldowns", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
ns.EMA_Cooldowns = EMA_Cooldowns

EMA_Cooldowns.moduleName = "EMA_Cooldowns"
EMA_Cooldowns.settingsDatabaseName = "EMA_CooldownsProfileDB"
EMA_Cooldowns.chatCommand = "ema-cooldowns"

-- Initialize runtime tables
EMA_Cooldowns.activeCooldowns = {} -- [characterName][spellName] = { startTime, duration, icon }

local L = LibStub("AceLocale-3.0"):GetLocale("Core")
local EMAUtilities = LibStub:GetLibrary("EbonyUtilities-1.0")

-- EMA metadata
EMA_Cooldowns.parentDisplayName = "Class"
EMA_Cooldowns.moduleDisplayName = "Cooldowns"
EMA_Cooldowns.moduleIcon = "Interface\AddOns\EMA\Media\SettingsIcon.tga"
EMA_Cooldowns.moduleOrder = 11

-- EMA integration mixins
local EMAModule = LibStub("Module-1.0")
EMAModule:Embed(EMA_Cooldowns)

-- Settings defaults
EMA_Cooldowns.settings = {
    profile = {
        showBars = true,
        barScale = 1.0,
        barAlpha = 1.0,
        lockBars = false,
        barOrder = "NameAsc",
        showNames = true,
        borderStyle = "Blizzard Tooltip",
        backgroundStyle = "Blizzard Dialog Background",
        fontStyle = "Arial Narrow",
        fontSize = 12,
        iconSize = 30,
        iconMargin = 2,
        barMargin = 4,
        showTimers = true,
        timerFontSize = 14,
        timerColorR = 1.0,
        timerColorG = 1.0,
        timerColorB = 1.0,
        frameBackgroundColourR = 0.1,
        frameBackgroundColourG = 0.1,
        frameBackgroundColourB = 0.1,
        frameBackgroundColourA = 0.7,
        frameBorderColourR = 0.5,
        frameBorderColourG = 0.5,
        frameBorderColourB = 0.5,
        frameBorderColourA = 1.0,
        trackedSpells = {
            ["WARRIOR"] = {},
            ["PALADIN"] = {},
            ["HUNTER"] = {},
            ["ROGUE"] = {},
            ["PRIEST"] = {},
            ["DEATHKNIGHT"] = {},
            ["SHAMAN"] = {},
            ["MAGE"] = {},
            ["WARLOCK"] = {},
            ["DRUID"] = {},
        },
        teamBarsPos = { point = "CENTER", x = 200, y = 0 },
    }
}

function EMA_Cooldowns:OnInitialize()
    local k = GetRealmName()
    local realm = k:gsub( "%s+", "")
    self.characterRealm = realm
    self.characterNameLessRealm = UnitName( "player" ) 
    self.characterName = self.characterNameLessRealm.."-"..self.characterRealm

    self:SettingsCreate()
    self:RegisterChatCommand("ec", "ChatCommand")
    self:RegisterChatCommand("ema-cooldowns", "ChatCommand")
    local _, playerClass = UnitClass("player")
    self.selectedClass = playerClass
    self:SettingsRefresh()
    
    -- Hook for Ctrl+Click spells
    hooksecurefunc("HandleModifiedItemClick", function(link)
        self:HandleSpellHook(link)
    end)
end

function EMA_Cooldowns:HandleSpellHook(link)
    if not link then return end
    if IsControlKeyDown() and EMAPrivate.SettingsFrame.Widget:IsVisible() then
        local GUIPanel = EMAPrivate.SettingsFrame.TreeGroupStatus.selected
        if GUIPanel and string.find(GUIPanel, self.moduleDisplayName) then
            local spellID = string.match(link, "spell:(%d+)")
            if spellID then
                local name = GetSpellInfo(spellID)
                if name then
                    self.settingsControl.editBoxAddSpell:SetText(name)
                    -- Try to find duration if known, else default to empty
                    local duration = 0
                    local cooldown = GetSpellBaseCooldown(tonumber(spellID))
                    if cooldown then duration = cooldown / 1000 end
                    self.settingsControl.editBoxDuration:SetText(tostring(duration))
                end
            end
        end
    end
end

function EMA_Cooldowns:ChatCommand(input)
    local cmd = input and input:trim():lower() or ""
    if cmd == "config" then
        self:EMAChatCommand("config")
    else
        self:Print("Usage: /ec config")
    end
end

function EMA_Cooldowns:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    if ns.UI then ns.UI:Initialize() end
end

function EMA_Cooldowns:PLAYER_LOGIN()
    if ns.UI then ns.UI:RefreshBars() end
end

function EMA_Cooldowns:COMBAT_LOG_EVENT_UNFILTERED()
    local _, event, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
    
    if event == "SPELL_CAST_SUCCESS" then
        local characterName = EMAUtilities:AddRealmToNameIfMissing(sourceName)
        if EMAApi.IsCharacterInTeam(characterName) then
            local class, _ = EMAApi.GetClass(characterName)
            if class then
                local classKey = class:upper()
                local spellList = self.db.trackedSpells[classKey]
                if spellList then
                    for _, spellInfo in ipairs(spellList) do
                        if spellInfo.name == spellName or tostring(spellInfo.id) == tostring(spellID) then
                            local icon = select(3, GetSpellInfo(spellID))
                            local charKey = Ambiguate(characterName, "none")
                            self.activeCooldowns[charKey] = self.activeCooldowns[charKey] or {}
                            self.activeCooldowns[charKey][spellName] = {
                                startTime = GetTime(),
                                duration = spellInfo.duration,
                                icon = icon
                            }
                            break
                        end
                    end
                end
            end
        end
    end
end

function EMA_Cooldowns:PushSettingsToTeam()
    self:EMASendSettings()
end

function EMA_Cooldowns:GetConfiguration()
    local configuration = {
        name = "Cooldowns", handler = self, type = 'group',
        args = {
            showBars = { type = "toggle", name = "Show Cooldown Bars", get = "EMAConfigurationGetSetting", set = "EMAConfigurationSetSetting" },
        },
    }
    return configuration
end

function EMA_Cooldowns:SettingsCreate()
    self.settingsControl = {}
    self.settingsControlClass = {}
    local EMAHelperSettings = LibStub("EMAHelperSettings-1.0")
    
    EMAHelperSettings:CreateSettings(self.settingsControlClass, "Class", "Class", function() end, "Interface\AddOns\EMA\Media\TeamCore.tga", 5)
    EMAHelperSettings:CreateSettings(self.settingsControl, "Cooldowns", "Class", function() self:PushSettingsToTeam() end, "Interface\Addons\EMA\Media\SettingsIcon.tga", 11)
    
    local top, left = EMAHelperSettings:TopOfSettings(), EMAHelperSettings:LeftOfSettings()
    local headingHeight, headingWidth = EMAHelperSettings:HeadingHeight(), EMAHelperSettings:HeadingWidth(true)
    local checkBoxHeight, sliderHeight = EMAHelperSettings:GetCheckBoxHeight(), EMAHelperSettings:GetSliderHeight()
    local dropdownHeight = EMAHelperSettings:GetDropdownHeight()
    local verticalSpacing = EMAHelperSettings:GetVerticalSpacing()
    local movingTop = top
    
    EMAHelperSettings:CreateHeading(self.settingsControl, "General Options", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.checkBoxShowBars = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Show Cooldown Bars", function(w, e, v) self.db.showBars = v; ns.UI:RefreshBars() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.checkBoxLockBars = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Lock Bars (Alt-Click to move)", function(w, e, v) self.db.lockBars = v end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.checkBoxShowNames = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Show Character Names", function(w, e, v) self.db.showNames = v; ns.UI:RefreshBars() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.sliderScale = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Bar Scale")
    self.settingsControl.sliderScale:SetSliderValues(0.5, 2.0, 0.01)
    self.settingsControl.sliderScale:SetCallback("OnValueChanged", function(w, e, v) self.db.barScale = tonumber(v); ns.UI:RefreshBars() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.sliderAlpha = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Bar Alpha")
    self.settingsControl.sliderAlpha:SetSliderValues(0.1, 1.0, 0.01)
    self.settingsControl.sliderAlpha:SetCallback("OnValueChanged", function(w, e, v) self.db.barAlpha = tonumber(v); ns.UI:RefreshBars() end)
    movingTop = movingTop - sliderHeight
    
    EMAHelperSettings:CreateHeading(self.settingsControl, "Appearance", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.dropdownBorder = EMAHelperSettings:CreateMediaBorder(self.settingsControl, headingWidth, left, movingTop, "Border Style")
    self.settingsControl.dropdownBorder:SetCallback("OnValueChanged", function(w, e, v) self.db.borderStyle = v; ns.UI:RefreshBars() end)
    movingTop = movingTop - 110
    self.settingsControl.dropdownBackground = EMAHelperSettings:CreateMediaBackground(self.settingsControl, headingWidth, left, movingTop, "Background Style")
    self.settingsControl.dropdownBackground:SetCallback("OnValueChanged", function(w, e, v) self.db.backgroundStyle = v; ns.UI:RefreshBars() end)
    movingTop = movingTop - 110
    self.settingsControl.dropdownFont = EMAHelperSettings:CreateMediaFont(self.settingsControl, headingWidth, left, movingTop, "Font Style")
    self.settingsControl.dropdownFont:SetCallback("OnValueChanged", function(w, e, v) self.db.fontStyle = v; ns.UI:RefreshBars() end)
    movingTop = movingTop - 110
    self.settingsControl.sliderFontSize = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Font Size")
    self.settingsControl.sliderFontSize:SetSliderValues(6, 24, 1)
    self.settingsControl.sliderFontSize:SetCallback("OnValueChanged", function(w, e, v) self.db.fontSize = tonumber(v); ns.UI:RefreshBars() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.sliderIconSize = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Icon Size")
    self.settingsControl.sliderIconSize:SetSliderValues(16, 64, 1)
    self.settingsControl.sliderIconSize:SetCallback("OnValueChanged", function(w, e, v) self.db.iconSize = tonumber(v); ns.UI:RefreshBars() end)
    movingTop = movingTop - sliderHeight
    
    EMAHelperSettings:CreateHeading(self.settingsControl, "Cooldown Spells by Class", movingTop, false)
    movingTop = movingTop - headingHeight
    
    -- Class Selection Dropdown
    self.settingsControl.dropdownClass = EMAHelperSettings:CreateDropdown(self.settingsControl, headingWidth, left, movingTop, "Select Class to Manage")
    self.settingsControl.dropdownClass:SetList({
        ["WARRIOR"] = "Warrior", ["PALADIN"] = "Paladin", ["HUNTER"] = "Hunter", ["ROGUE"] = "Rogue",
        ["PRIEST"] = "Priest", ["DEATHKNIGHT"] = "Death Knight", ["SHAMAN"] = "Shaman", ["MAGE"] = "Mage",
        ["WARLOCK"] = "Warlock", ["DRUID"] = "Druid"
    })
    self.settingsControl.dropdownClass:SetCallback("OnValueChanged", function(w, e, v) 
        self.selectedClass = v
        self:SettingsSpellListScrollRefresh()
    end)
    movingTop = movingTop - dropdownHeight - verticalSpacing
    
    -- Spell Scroll List
    self.settingsControl.spellList = {
        listFrameName = "EMACooldownsSettingsSpellListFrame",
        parentFrame = self.settingsControl.widgetSettings.content,
        listTop = movingTop,
        listLeft = left,
        listWidth = headingWidth,
        rowHeight = 25, rowsToDisplay = 10, columnsToDisplay = 3,
        columnInformation = {
            { width = 50, alignment = "LEFT" }, -- Name/ID
            { width = 30, alignment = "LEFT" }, -- Duration
            { width = 20, alignment = "CENTER" } -- Remove
        },
        scrollRefreshCallback = function() self:SettingsSpellListScrollRefresh() end,
        rowClickCallback = function(obj, rowNumber, columnNumber) self:SettingsSpellListRowClick(rowNumber, columnNumber) end
    }
    EMAHelperSettings:CreateScrollList(self.settingsControl.spellList)
    movingTop = movingTop - self.settingsControl.spellList.listHeight - verticalSpacing
    
    -- Add Spell Functionality
    local halfWidth = (headingWidth - 10) / 2
    self.settingsControl.editBoxAddSpell = EMAHelperSettings:CreateEditBox(self.settingsControl, halfWidth, left, movingTop, "Spell Name or ID")
    self.settingsControl.editBoxDuration = EMAHelperSettings:CreateEditBox(self.settingsControl, halfWidth - 60, left + halfWidth + 5, movingTop, "CD (sec)")
    self.settingsControl.buttonAddSpell = EMAHelperSettings:CreateButton(self.settingsControl, 50, left + headingWidth - 50, movingTop, "Add", function()
        self:AddSpellToTrackedList()
    end)
    movingTop = movingTop - EMAHelperSettings:GetEditBoxHeight()

    self:EMAModuleInitialize(self.settingsControl.widgetSettings.frame)
    self.settingsControl.widgetSettings.content:SetHeight(-movingTop + 20)
end

function EMA_Cooldowns:AddSpellToTrackedList()
    local class = self.selectedClass
    if not class then self:Print("Please select a class first."); return end
    
    local spellVal = self.settingsControl.editBoxAddSpell:GetText()
    local duration = tonumber(self.settingsControl.editBoxDuration:GetText())
    
    if not spellVal or spellVal == "" or not duration then
        self:Print("Invalid Name/ID or Duration."); return
    end
    
    local name, _, icon = GetSpellInfo(spellVal)
    if not name then
        self:Print("Could not find spell information for: " .. spellVal)
        return
    end
    
    table.insert(self.db.trackedSpells[class], {
        name = name,
        id = tonumber(spellVal) or 0,
        duration = duration,
        icon = icon
    })
    
    self.settingsControl.editBoxAddSpell:SetText("")
    self.settingsControl.editBoxDuration:SetText("")
    self:SettingsSpellListScrollRefresh()
    self:PushSettingsToTeam()
end

function EMA_Cooldowns:SettingsSpellListScrollRefresh()
    local class = self.selectedClass
    local spells = class and self.db.trackedSpells[class] or {}
    
    FauxScrollFrame_Update(self.settingsControl.spellList.listScrollFrame, #spells, self.settingsControl.spellList.rowsToDisplay, self.settingsControl.spellList.rowHeight)
    local offset = FauxScrollFrame_GetOffset(self.settingsControl.spellList.listScrollFrame)
    
    for i = 1, self.settingsControl.spellList.rowsToDisplay do
        local row = self.settingsControl.spellList.rows[i]
        local dataIndex = i + offset
        if dataIndex <= #spells then
            local spell = spells[dataIndex]
            row.columns[1].textString:SetText(spell.name)
            row.columns[2].textString:SetText(spell.duration .. "s")
            row.columns[3].textString:SetText("Remove")
            row.dataIndex = dataIndex
            row:Show()
        else
            row:Hide()
        end
    end
end

function EMA_Cooldowns:SettingsSpellListRowClick(rowNumber, columnNumber)
    local class = self.selectedClass
    if not class then return end
    local offset = FauxScrollFrame_GetOffset(self.settingsControl.spellList.listScrollFrame)
    local dataIndex = rowNumber + offset
    if columnNumber == 3 then
        table.remove(self.db.trackedSpells[class], dataIndex)
        self:SettingsSpellListScrollRefresh()
        self:PushSettingsToTeam()
    end
end

function EMA_Cooldowns:SettingsRefresh()
    if self.settingsControl then
        self.settingsControl.checkBoxShowBars:SetValue(self.db.showBars)
        self.settingsControl.checkBoxLockBars:SetValue(self.db.lockBars)
        self.settingsControl.checkBoxShowNames:SetValue(self.db.showNames)
        self.settingsControl.sliderScale:SetValue(self.db.barScale)
        self.settingsControl.sliderAlpha:SetValue(self.db.barAlpha)
        self.settingsControl.dropdownBorder:SetValue(self.db.borderStyle)
        self.settingsControl.dropdownBackground:SetValue(self.db.backgroundStyle)
        self.settingsControl.dropdownFont:SetValue(self.db.fontStyle)
        self.settingsControl.sliderFontSize:SetValue(self.db.fontSize)
        self.settingsControl.sliderIconSize:SetValue(self.db.iconSize)
        self.settingsControl.dropdownClass:SetValue(self.selectedClass)
        self:SettingsSpellListScrollRefresh()
    end
end

function EMA_Cooldowns:OnEMAProfileChanged() self:SettingsRefresh(); ns.UI:RefreshBars() end
function EMA_Cooldowns:BeforeEMAProfileChanged() end
