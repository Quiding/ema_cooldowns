local addonName, ns = ...
-- Official EMA Module initialization
local EMA_Cooldowns = LibStub("AceAddon-3.0"):NewAddon("EMA_Cooldowns", "Module-1.0", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
ns.EMA_Cooldowns = EMA_Cooldowns

EMA_Cooldowns.moduleName = "EMA_Cooldowns"
EMA_Cooldowns.settingsDatabaseName = "EMA_CooldownsProfileDB"
EMA_Cooldowns.chatCommand = "ema-cooldowns"

-- Global database of common spell IDs
ns.warmupIDs = {
    16166, 16188, 16190, 2825, 32182, 8056, 8042, 8050, 421, 403, 2062, 2894, -- Shaman
    31884, 642, 633, 1044, 1022, 10278, 20217, 19746, 20271, 20066, -- Paladin
    22812, 29166, 17116, 16689, 5217, 1850, 9846, 2908, 22842, -- Druid
    10060, 14751, 15487, 10890, 10909, 15286, 15473, -- Priest
    12042, 12043, 12472, 11129, 12051, 11958, 11426, -- Mage
    871, 1719, 12292, 12975, 11578, 12323, 12328, -- Warrior
    13750, 13877, 11305, 14177, 14185, 14183, -- Rogue
    18708, 19028, 17920, 18708, 6229, -- Warlock
    3045, 19263, 19574, 19263, 1510, 19503, 14311 -- Hunter
}

-- REQUIRED: GetConfiguration for EMA core
function EMA_Cooldowns:GetConfiguration()
    return {
        name = "Cooldowns", handler = self, type = 'group',
        args = {
            showBars = { type = "toggle", name = "Show Cooldown Bars", get = "EMAConfigurationGetSetting", set = "EMAConfigurationSetSetting" },
        },
    }
end

-- Initialize runtime tables
EMA_Cooldowns.activeCooldowns = {}
-- Spells that start cooldown only AFTER the buff is gone.
-- Map: [SpellName] = { buffName, buffID }
EMA_Cooldowns.delayedSpells = {
    ["Nature's Swiftness"] = { name = "Nature's Swiftness", id = 16188 },
    ["Elemental Mastery"] = { name = "Elemental Mastery", id = 16166 },
    ["Presence of Mind"] = { name = "Presence of Mind", id = 12043 },
}
-- Team active buffs: [charKey][buffName] = true
EMA_Cooldowns.teamBuffs = {}

local L = LibStub("AceLocale-3.0"):GetLocale("Core")
local EMAUtilities = LibStub:GetLibrary("EbonyUtilities-1.0")

-- EMA metadata
EMA_Cooldowns.parentDisplayName = "Class"
EMA_Cooldowns.moduleDisplayName = "Cooldowns"
EMA_Cooldowns.moduleIcon = "Interface\\Addons\\EMA\\Media\\SettingsIcon.tga"
EMA_Cooldowns.moduleOrder = 11

-- EMA key bindings
_G["BINDING_HEADER_EMACDS"] = "EMA Cooldowns"
_G["BINDING_NAME_EMACDSHOW"] = "Toggle Cooldown Bars"

-- Settings defaults
EMA_Cooldowns.settings = {
    profile = {
        showBars = true,
        barScale = 1.0,
        barAlpha = 1.0,
        lockBars = false,
        barOrder = "RoleAsc",
        showNames = true,
        -- Opacity
        runningAlpha = 0.3,
        readyAlpha = 1.0,
        -- Glow
        glowIfBuffActive = true,
        glowAnimated = true,
        glowColorR = 0.0, glowColorG = 1.0, glowColorB = 1.0, glowColorA = 1.0,
        -- Frame Styles
        frameBorderStyle = "Blizzard Tooltip",
        frameBackgroundStyle = "Blizzard Dialog Background",
        frameBackgroundColourR = 0.1, frameBackgroundColourG = 0.1, frameBackgroundColourB = 0.1, frameBackgroundColourA = 0.7,
        frameBorderColourR = 0.5, frameBorderColourG = 0.5, frameBorderColourB = 0.5, frameBorderColourA = 1.0,
        -- Bar Styles
        barBorderStyle = "Blizzard Tooltip",
        barBackgroundStyle = "Blizzard Dialog Background",
        barBackgroundColourR = 0.1, barBackgroundColourG = 0.1, barBackgroundColourB = 0.1, barBackgroundColourA = 0.7,
        barBorderColourR = 0.5, barBorderColourG = 0.5, barBorderColourB = 0.5, barBorderColourA = 1.0,
        
        fontStyle = "Arial Narrow",
        fontSize = 12,
        iconSize = 30,
        iconMargin = 2,
        barMargin = 4,
        showTimers = true,
        timerFontSize = 14,
        timerColorR = 1.0, timerColorG = 1.0, timerColorB = 1.0,
        enabledMembers = {},
        trackedSpells = {
            ["WARRIOR"] = {}, ["PALADIN"] = {}, ["HUNTER"] = {}, ["ROGUE"] = {},
            ["PRIEST"] = {}, ["DEATHKNIGHT"] = {}, ["SHAMAN"] = {}, ["MAGE"] = {},
            ["WARLOCK"] = {}, ["DRUID"] = {},
        },
        teamBarsPos = { point = "CENTER", x = 200, y = 0 },
    }
}

function EMA_Cooldowns:OnInitialize()
    self.completeDatabase = LibStub("AceDB-3.0"):New(self.settingsDatabaseName, self.settings)
    self.db = self.completeDatabase.profile
    self.characterName = UnitName("player")
    self:SettingsCreate()
    self:RegisterChatCommand("ecd", "ChatCommand")
    self:RegisterChatCommand("ema-cooldowns", "ChatCommand")
    local _, englishClass = UnitClass("player")
    self.selectedClass = englishClass
    self:SettingsRefresh()
    for _, id in ipairs(ns.warmupIDs) do GetSpellInfo(id); GetSpellLink(id) end
    hooksecurefunc("HandleModifiedItemClick", function(link) self:HandleSpellHook(link) end)
end

function EMA_Cooldowns:GetSpellInfoRobust(search)
    if not search or search == "" then return nil end
    local name, icon, spellID
    if tonumber(search) then
        name, _, icon, _, _, _, spellID = GetSpellInfo(tonumber(search))
        if name then return name, icon, spellID end
    end
    name, _, icon, _, _, _, spellID = GetSpellInfo(search)
    if name then return name, icon, spellID end
    local searchLower = search:lower()
    for i = 1, 100000 do
        local n = GetSpellInfo(i)
        if n and n:lower() == searchLower then
            name, _, icon, _, _, _, spellID = GetSpellInfo(i)
            return name, icon, spellID
        end
    end
    return nil
end

function EMA_Cooldowns:HandleSpellHook(link)
    if not link then return end
    if IsControlKeyDown() and EMAPrivate.SettingsFrame.Widget:IsVisible() then
        local GUIPanel = EMAPrivate.SettingsFrame.TreeGroupStatus.selected
        if GUIPanel and string.find(GUIPanel, self.moduleDisplayName) then
            local spellID = string.match(link, "spell:(%d+)")
            if spellID then
                local name, _, icon = GetSpellInfo(tonumber(spellID))
                if name then
                    self.settingsControl.editBoxAddSpell:SetText(name)
                    local cooldown = GetSpellBaseCooldown(tonumber(spellID)) or 0
                    self.settingsControl.editBoxDuration:SetText(tostring(cooldown / 1000))
                end
            end
        end
    end
end

function EMA_Cooldowns:ChatCommand(input)
    local cmd = input and input:trim():lower() or ""
    if cmd == "config" then self:EMAChatCommand("config")
    elseif cmd == "test" then self:TestCooldown()
    else self:Print("Usage: /ecd config, /ecd test") end
end

function EMA_Cooldowns:TestCooldown()
    local charKey = Ambiguate(self.characterName, "none"):lower()
    local class, _ = EMAApi.GetClass(self.characterName)
    local classKey = class:upper()
    local tracked = self.db.trackedSpells[classKey]
    local spellName = (tracked and tracked[1] and tracked[1].name) or "Test Spell"
    self.activeCooldowns[charKey] = self.activeCooldowns[charKey] or {}
    self.activeCooldowns[charKey][spellName] = { startTime = GetTime(), duration = 10 }
    self:Print("Started 10s Test Cooldown.")
    ns.UI:RefreshBars()
end

function EMA_Cooldowns:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("UNIT_AURA")
    if EMAApi then
        self:RegisterMessage( EMAApi.MESSAGE_CHARACTER_ONLINE, "RefreshTeamStatus" )
        self:RegisterMessage( EMAApi.MESSAGE_CHARACTER_OFFLINE, "RefreshTeamStatus" )
    end
    if ns.UI then ns.UI:Initialize() end
    self:ScheduleRepeatingTimer("ScanTeamBuffs", 0.5)
end

function EMA_Cooldowns:RefreshTeamStatus() 
    self:ScanTeamBuffs()
    ns.UI:RefreshBars() 
end
function EMA_Cooldowns:PLAYER_LOGIN() 
    self:ScanTeamBuffs()
    if ns.UI then ns.UI:RefreshBars() end 
end

function EMA_Cooldowns:UNIT_AURA(event, unit)
    if not unit then return end
    self:ScanUnitBuffs(unit)
end

function EMA_Cooldowns:ScanTeamBuffs()
    self:ScanUnitBuffs("player")
    for i = 1, 4 do self:ScanUnitBuffs("party"..i) end
    if IsInRaid() then
        for i = 1, 40 do self:ScanUnitBuffs("raid"..i) end
    end
end

function EMA_Cooldowns:ScanUnitBuffs(unit)
    local characterName = GetUnitName(unit, true)
    if not characterName or not EMAApi.IsCharacterInTeam(characterName) then return end
    local charKey = Ambiguate(characterName, "none"):lower()
    self.teamBuffs[charKey] = self.teamBuffs[charKey] or {}
    
    local foundAnyBuff = {}
    local foundAnyBuffID = {}
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellID = UnitBuff(unit, i)
        if not name then break end
        foundAnyBuff[name] = true
        if spellID then foundAnyBuffID[spellID] = true end
        self.teamBuffs[charKey][name] = true
    end

    -- Update existing pending cooldowns if the buff is now gone
    if self.activeCooldowns[charKey] then
        for spellName, data in pairs(self.activeCooldowns[charKey]) do
            if data.pendingBuff then
                local bInfo = self.delayedSpells[spellName]
                local stillHasBuff = false
                if bInfo then
                    if foundAnyBuff[bInfo.name] or (bInfo.id and foundAnyBuffID[bInfo.id]) then
                        stillHasBuff = true
                    end
                end
                
                if not stillHasBuff then
                    -- Buff is gone, start the cooldown now!
                    data.startTime = GetTime()
                    data.pendingBuff = false
                    ns.UI:UpdateUI()
                end
            end
        end
    end

    -- Cleanup teamBuffs
    for bName, _ in pairs(self.teamBuffs[charKey]) do
        if not foundAnyBuff[bName] then
            self.teamBuffs[charKey][bName] = nil
        end
    end
end

function EMA_Cooldowns:COMBAT_LOG_EVENT_UNFILTERED()
    local _, event, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
    if event == "SPELL_CAST_SUCCESS" or event == "SPELL_SUMMON" then
        local characterName = EMAUtilities:AddRealmToNameIfMissing(sourceName or "")
        if EMAApi.IsCharacterInTeam(characterName) then
            local class, _ = EMAApi.GetClass(characterName)
            if class then
                local classKey = class:upper()
                local spellList = self.db.trackedSpells[classKey]
                if spellList then
                    for _, spellInfo in ipairs(spellList) do
                        if spellInfo.name == spellName or (spellInfo.id ~= 0 and tostring(spellInfo.id) == tostring(spellID)) then
                            local charKey = Ambiguate(characterName, "none"):lower()
                            self.activeCooldowns[charKey] = self.activeCooldowns[charKey] or {}
                            
                            local bInfo = self.delayedSpells[spellName]
                            local isBuffActive = false
                            
                            -- Fix: Scan unit buffs immediately to avoid the "timer blink"
                            if bInfo then
                                local units = {"player", "party1", "party2", "party3", "party4"}
                                if IsInRaid() then for i=1,40 do table.insert(units, "raid"..i) end end
                                for _, unit in ipairs(units) do
                                    if GetUnitName(unit, true) == characterName then
                                        self:ScanUnitBuffs(unit)
                                        break
                                    end
                                end
                            end

                            if bInfo and self.teamBuffs[charKey] then
                                if self.teamBuffs[charKey][bInfo.name] then
                                    isBuffActive = true
                                end
                            end
                            
                            if isBuffActive then
                                -- Buff is active, don't start timer yet, mark as pending
                                self.activeCooldowns[charKey][spellName] = { startTime = 0, duration = spellInfo.duration, pendingBuff = true }
                            else
                                self.activeCooldowns[charKey][spellName] = { startTime = GetTime(), duration = spellInfo.duration, pendingBuff = false }
                            end
                            ns.UI:UpdateUI()
                            break
                        end
                    end
                end
            end
        end
    end
end

function EMA_Cooldowns:PushSettingsToTeam() self:EMASendSettings() end

-- REQUIRED BY EMA CORE FOR SYNC
function EMA_Cooldowns:EMAOnSettingsReceived(characterName, settings)
    if characterName ~= self.characterName then
        for k, v in pairs(settings) do
            self.db[k] = v
        end
        self:SettingsRefresh()
        ns.UI:RefreshBars()
        ns.UI:UpdatePositionFromDB()
    end
end

function EMA_Cooldowns:EMAOnCommandReceived(sender, commandName, ...)
    -- Handle commands if needed
end

function EMA_Cooldowns:BeforeEMAProfileChanged() end
function EMA_Cooldowns:OnEMAProfileChanged()
    if self.completeDatabase then self.db = self.completeDatabase.profile end
    self:SettingsRefresh()
    ns.UI:RefreshBars()
end

function EMA_Cooldowns:SettingsCreate()
    self.settingsControl = {}
    self.settingsControlClass = {}
    local EMAHelperSettings = LibStub("EMAHelperSettings-1.0")
    EMAHelperSettings:CreateSettings(self.settingsControlClass, "Class", "Class", function() end, "Interface\\AddOns\\EMA\\Media\\TeamCore.tga", 5)
    EMAHelperSettings:CreateSettings(self.settingsControl, "Cooldowns", "Class", function() self:PushSettingsToTeam() end, "Interface\\AddOns\\EMA\\Media\\SettingsIcon.tga", 11)
    
    local top, left = EMAHelperSettings:TopOfSettings(), EMAHelperSettings:LeftOfSettings()
    local headingHeight, headingWidth = EMAHelperSettings:HeadingHeight(), EMAHelperSettings:HeadingWidth(true)
    local checkBoxHeight, sliderHeight = EMAHelperSettings:GetCheckBoxHeight(), EMAHelperSettings:GetSliderHeight()
    local dropdownHeight, verticalSpacing = EMAHelperSettings:GetDropdownHeight(), EMAHelperSettings:GetVerticalSpacing()
    local movingTop = top
    local halfWidth = headingWidth / 2
    
    EMAHelperSettings:CreateHeading(self.settingsControl, "General Options", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.checkBoxShowBars = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Show Cooldown Bars", function(w, e, v) self.db.showBars = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.checkBoxLockBars = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Lock Bars (Alt-Click to move)", function(w, e, v) self.db.lockBars = v; self:SettingsRefresh() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.checkBoxShowNames = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Show Character Names", function(w, e, v) self.db.showNames = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.dropdownOrder = EMAHelperSettings:CreateDropdown(self.settingsControl, halfWidth, left, movingTop, "Bar Order")
    self.settingsControl.dropdownOrder:SetList({ ["NameAsc"] = "Name (Asc)", ["NameDesc"] = "Name (Desc)", ["EMAPosition"] = "EMA Team Order", ["RoleAsc"] = "Role (Tank > Healer > DPS)" })
    self.settingsControl.dropdownOrder:SetCallback("OnValueChanged", function(w, e, v) self.db.barOrder = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - dropdownHeight - verticalSpacing
    self.settingsControl.sliderScale = EMAHelperSettings:CreateSlider(self.settingsControl, halfWidth, left, movingTop, "Overall Scale")
    self.settingsControl.sliderScale:SetSliderValues(0.5, 2.0, 0.01)
    self.settingsControl.sliderScale:SetCallback("OnValueChanged", function(w, e, v) self.db.barScale = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.sliderAlpha = EMAHelperSettings:CreateSlider(self.settingsControl, halfWidth, left, movingTop, "Overall Alpha")
    self.settingsControl.sliderAlpha:SetSliderValues(0.1, 1.0, 0.01)
    self.settingsControl.sliderAlpha:SetCallback("OnValueChanged", function(w, e, v) self.db.barAlpha = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.buttonRefreshTeam = EMAHelperSettings:CreateButton(self.settingsControl, headingWidth, left, movingTop, "Refresh Team Members", function() ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30

    EMAHelperSettings:CreateHeading(self.settingsControl, "Visual Effects", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.checkBoxGlowIfBuffActive = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Glow when associated buff is active", function(w, e, v) self.db.glowIfBuffActive = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.checkBoxGlowAnimated = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Glow Animation", function(w, e, v) self.db.glowAnimated = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.colorGlow = EMAHelperSettings:CreateColourPicker(self.settingsControl, halfWidth, left, movingTop, "Glow Color")
    self.settingsControl.colorGlow:SetCallback("OnValueChanged", function(w, e, r, g, b, a) self.db.glowColorR, self.db.glowColorG, self.db.glowColorB, self.db.glowColorA = r, g, b, a; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30
    self.settingsControl.sliderRunningAlpha = EMAHelperSettings:CreateSlider(self.settingsControl, halfWidth, left, movingTop, "On cooldown")
    self.settingsControl.sliderRunningAlpha:SetSliderValues(0.1, 1.0, 0.01)
    self.settingsControl.sliderRunningAlpha:SetCallback("OnValueChanged", function(w, e, v) self.db.runningAlpha = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.sliderReadyAlpha = EMAHelperSettings:CreateSlider(self.settingsControl, halfWidth, left, movingTop, "Ready")
    self.settingsControl.sliderReadyAlpha:SetSliderValues(0.1, 1.0, 0.01)
    self.settingsControl.sliderReadyAlpha:SetCallback("OnValueChanged", function(w, e, v) self.db.readyAlpha = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight

    EMAHelperSettings:CreateHeading(self.settingsControl, "Appearance: Whole UI Frame", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.dropdownFrameBorder = EMAHelperSettings:CreateMediaBorder(self.settingsControl, halfWidth, left, movingTop, "UI Border Style")
    self.settingsControl.dropdownFrameBorder:SetCallback("OnValueChanged", function(w, e, v) self.db.frameBorderStyle = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 110
    self.settingsControl.dropdownFrameBackground = EMAHelperSettings:CreateMediaBackground(self.settingsControl, halfWidth, left, movingTop, "UI Background Style")
    self.settingsControl.dropdownFrameBackground:SetCallback("OnValueChanged", function(w, e, v) self.db.frameBackgroundStyle = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 110
    self.settingsControl.colorFrameBackground = EMAHelperSettings:CreateColourPicker(self.settingsControl, halfWidth, left, movingTop, "UI Background Color")
    self.settingsControl.colorFrameBackground:SetCallback("OnValueChanged", function(w, e, r, g, b, a) self.db.frameBackgroundColourR, self.db.frameBackgroundColourG, self.db.frameBackgroundColourB, self.db.frameBackgroundColourA = r, g, b, a; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30
    self.settingsControl.colorFrameBorder = EMAHelperSettings:CreateColourPicker(self.settingsControl, halfWidth, left, movingTop, "UI Border Color")
    self.settingsControl.colorFrameBorder:SetCallback("OnValueChanged", function(w, e, r, g, b, a) self.db.frameBorderColourR, self.db.frameBorderColourG, self.db.frameBorderColourB, self.db.frameBorderColourA = r, g, b, a; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30

    EMAHelperSettings:CreateHeading(self.settingsControl, "Appearance: Individual Bars", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.dropdownBarBorder = EMAHelperSettings:CreateMediaBorder(self.settingsControl, halfWidth, left, movingTop, "Bar Border Style")
    self.settingsControl.dropdownBarBorder:SetCallback("OnValueChanged", function(w, e, v) self.db.barBorderStyle = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 110
    self.settingsControl.dropdownBarBackground = EMAHelperSettings:CreateMediaBackground(self.settingsControl, halfWidth, left, movingTop, "Bar Background Style")
    self.settingsControl.dropdownBarBackground:SetCallback("OnValueChanged", function(w, e, v) self.db.barBackgroundStyle = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 110
    self.settingsControl.colorBarBackground = EMAHelperSettings:CreateColourPicker(self.settingsControl, halfWidth, left, movingTop, "Bar Background Color")
    self.settingsControl.colorBarBackground:SetCallback("OnValueChanged", function(w, e, r, g, b, a) self.db.barBackgroundColourR, self.db.barBackgroundColourG, self.db.barBackgroundColourB, self.db.barBackgroundColourA = r, g, b, a; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30
    self.settingsControl.colorBarBorder = EMAHelperSettings:CreateColourPicker(self.settingsControl, halfWidth, left, movingTop, "Bar Border Color")
    self.settingsControl.colorBarBorder:SetCallback("OnValueChanged", function(w, e, r, g, b, a) self.db.barBorderColourR, self.db.barBorderColourG, self.db.barBorderColourB, self.db.barBorderColourA = r, g, b, a; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30

    EMAHelperSettings:CreateHeading(self.settingsControl, "Sizing & Spacing", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.sliderIconSize = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Icon Size")
    self.settingsControl.sliderIconSize:SetSliderValues(16, 64, 1)
    self.settingsControl.sliderIconSize:SetCallback("OnValueChanged", function(w, e, v) self.db.iconSize = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.sliderIconMargin = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Icon Spacing")
    self.settingsControl.sliderIconMargin:SetSliderValues(0, 20, 1)
    self.settingsControl.sliderIconMargin:SetCallback("OnValueChanged", function(w, e, v) self.db.iconMargin = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.sliderBarMargin = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Bar Spacing")
    self.settingsControl.sliderBarMargin:SetSliderValues(0, 50, 1)
    self.settingsControl.sliderBarMargin:SetCallback("OnValueChanged", function(w, e, v) self.db.barMargin = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight

    EMAHelperSettings:CreateHeading(self.settingsControl, "Text & Timers", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.dropdownFont = EMAHelperSettings:CreateMediaFont(self.settingsControl, headingWidth, left, movingTop, "Font Style")
    self.settingsControl.dropdownFont:SetCallback("OnValueChanged", function(w, e, v) self.db.fontStyle = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 110
    self.settingsControl.sliderFontSize = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Name Font Size")
    self.settingsControl.sliderFontSize:SetSliderValues(6, 24, 1)
    self.settingsControl.sliderFontSize:SetCallback("OnValueChanged", function(w, e, v) self.db.fontSize = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.checkBoxShowTimers = EMAHelperSettings:CreateCheckBox(self.settingsControl, headingWidth, left, movingTop, "Show Timer Text", function(w, e, v) self.db.showTimers = v; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - checkBoxHeight
    self.settingsControl.sliderTimerFontSize = EMAHelperSettings:CreateSlider(self.settingsControl, headingWidth, left, movingTop, "Timer Font Size")
    self.settingsControl.sliderTimerFontSize:SetSliderValues(6, 32, 1)
    self.settingsControl.sliderTimerFontSize:SetCallback("OnValueChanged", function(w, e, v) self.db.timerFontSize = tonumber(v); ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - sliderHeight
    self.settingsControl.colorTimer = EMAHelperSettings:CreateColourPicker(self.settingsControl, headingWidth, left, movingTop, "Timer Color")
    self.settingsControl.colorTimer:SetCallback("OnValueChanged", function(w, e, r, g, b, a) self.db.timerColorR, self.db.timerColorG, self.db.timerColorB = r, g, b; ns.UI:RefreshBars(); self:SettingsRefresh() end)
    movingTop = movingTop - 30

    EMAHelperSettings:CreateHeading(self.settingsControl, "Members List", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.memberList = {
        listFrameName = "EMACooldownsSettingsMemberListFrame", parentFrame = self.settingsControl.widgetSettings.content, listTop = movingTop, listLeft = left, listWidth = headingWidth, rowHeight = 25, rowsToDisplay = 5, columnsToDisplay = 2,
        columnInformation = {{ width = 70, alignment = "LEFT" }, { width = 30, alignment = "LEFT" }},
        scrollRefreshCallback = function() self:SettingsMemberListScrollRefresh() end, rowClickCallback = function(obj, rowNumber, columnNumber) self:SettingsMemberListRowClick(rowNumber, columnNumber) end
    }
    EMAHelperSettings:CreateScrollList(self.settingsControl.memberList)
    movingTop = movingTop - self.settingsControl.memberList.listHeight - verticalSpacing

    EMAHelperSettings:CreateHeading(self.settingsControl, "Cooldown Spells by Class", movingTop, false)
    movingTop = movingTop - headingHeight
    self.settingsControl.dropdownClass = EMAHelperSettings:CreateDropdown(self.settingsControl, headingWidth, left, movingTop, "Select Class to Manage")
    self.settingsControl.dropdownClass:SetList({
        ["WARRIOR"] = "Warrior", ["PALADIN"] = "Paladin", ["HUNTER"] = "Hunter", ["ROGUE"] = "Rogue",
        ["PRIEST"] = "Priest", ["DEATHKNIGHT"] = "Death Knight", ["SHAMAN"] = "Shaman", ["MAGE"] = "Mage",
        ["WARLOCK"] = "Warlock", ["DRUID"] = "Druid"
    })
    self.settingsControl.dropdownClass:SetCallback("OnValueChanged", function(w, e, v) self.selectedClass = v; self:SettingsSpellListScrollRefresh(); self:SettingsRefresh() end)
    movingTop = movingTop - dropdownHeight - verticalSpacing
    
    self.settingsControl.spellList = {
        listFrameName = "EMACooldownsSettingsSpellListFrame", parentFrame = self.settingsControl.widgetSettings.content, listTop = movingTop, listLeft = left, listWidth = headingWidth, rowHeight = 25, rowsToDisplay = 8, columnsToDisplay = 5,
        columnInformation = { { width = 12, alignment = "CENTER" }, { width = 8, alignment = "CENTER" }, { width = 45, alignment = "LEFT" }, { width = 15, alignment = "LEFT" }, { width = 20, alignment = "CENTER" } },
        scrollRefreshCallback = function() self:SettingsSpellListScrollRefresh() end, rowClickCallback = function(obj, rowNumber, columnNumber) self:SettingsSpellListRowClick(rowNumber, columnNumber) end
    }
    EMAHelperSettings:CreateScrollList(self.settingsControl.spellList)
    movingTop = movingTop - self.settingsControl.spellList.listHeight - verticalSpacing
    
    local halfWidth = (headingWidth - 10) / 2
    self.settingsControl.editBoxAddSpell = EMAHelperSettings:CreateEditBox(self.settingsControl, halfWidth, left, movingTop, "Spell Name or ID")
    self.settingsControl.editBoxDuration = EMAHelperSettings:CreateEditBox(self.settingsControl, halfWidth - 70, left + halfWidth + 5, movingTop, "CD (sec)")
    self.settingsControl.buttonAddSpell = EMAHelperSettings:CreateButton(self.settingsControl, 60, left + headingWidth - 60, movingTop, "Add", function() self:AddSpellToTrackedList() end)
    movingTop = movingTop - EMAHelperSettings:GetEditBoxHeight()

    self:EMAModuleInitialize(self.settingsControl.widgetSettings.frame)
    self.settingsControl.widgetSettings.content:SetHeight(-movingTop + 20)
end

function EMA_Cooldowns:SettingsMemberListScrollRefresh()
    local team = {}
    for index, characterName in EMAApi.TeamListOrdered() do
        local class, color = EMAApi.GetClass(characterName)
        table.insert(team, { name = characterName, color = color })
    end
    FauxScrollFrame_Update(self.settingsControl.memberList.listScrollFrame, #team, self.settingsControl.memberList.rowsToDisplay, self.settingsControl.memberList.rowHeight)
    local offset = FauxScrollFrame_GetOffset(self.settingsControl.memberList.listScrollFrame)
    for i = 1, self.settingsControl.memberList.rowsToDisplay do
        local row = self.settingsControl.memberList.rows[i]
        local dataIndex = i + offset
        if dataIndex <= #team then
            local info = team[dataIndex]
            local name = info.name
            local color = info.color or {r=1, g=1, b=1}
            local enabled = self.db.enabledMembers[name] ~= false
            row.columns[1].textString:SetText(Ambiguate(name, "short"))
            row.columns[1].textString:SetTextColor(color.r, color.g, color.b)
            row.columns[2].textString:SetText(enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r")
            row.charName = name
            row:Show()
        else row:Hide() end
    end
end

function EMA_Cooldowns:SettingsMemberListRowClick(rowNumber, columnNumber)
    local offset = FauxScrollFrame_GetOffset(self.settingsControl.memberList.listScrollFrame)
    local team = {}
    for index, characterName in EMAApi.TeamListOrdered() do table.insert(team, characterName) end
    local dataIndex = rowNumber + offset
    if dataIndex <= #team then
        local name = team[dataIndex]
        self.db.enabledMembers[name] = not (self.db.enabledMembers[name] ~= false)
        self:SettingsMemberListScrollRefresh(); ns.UI:RefreshBars(); self:SettingsRefresh()
    end
end

function EMA_Cooldowns:AddSpellToTrackedList()
    local class = self.selectedClass
    if not class then self:Print("Please select a class first."); return end
    local rawSpell = self.settingsControl.editBoxAddSpell:GetText()
    local spellVal = strtrim(rawSpell or "")
    local duration = tonumber(self.settingsControl.editBoxDuration:GetText())
    if not spellVal or spellVal == "" or not duration then self:Print("Invalid Name/ID or Duration."); return end
    local name, icon, spellID = self:GetSpellInfoRobust(spellVal)
    if not name then self:Print("Could not find spell information for: " .. spellVal); return end
    table.insert(self.db.trackedSpells[class], { name = name, id = tonumber(spellID) or 0, duration = duration, icon = icon or 134400 })
    self.settingsControl.editBoxAddSpell:SetText(""); self.settingsControl.editBoxDuration:SetText("")
    self:SettingsSpellListScrollRefresh(); self:PushSettingsToTeam(); self:SettingsRefresh()
end

function EMA_Cooldowns:SettingsSpellListScrollRefresh()
    local class = self.selectedClass
    local spells = class and self.db.trackedSpells[class] or {}
    local rh = self.settingsControl.spellList.rowHeight
    FauxScrollFrame_Update(self.settingsControl.spellList.listScrollFrame, #spells, self.settingsControl.spellList.rowsToDisplay, rh)
    local offset = FauxScrollFrame_GetOffset(self.settingsControl.spellList.listScrollFrame)
    for i = 1, self.settingsControl.spellList.rowsToDisplay do
        local row = self.settingsControl.spellList.rows[i]
        local dataIndex = i + offset
        if dataIndex <= #spells then
            local spell = spells[dataIndex]
            row.columns[1].textString:SetText("[Up] [Dn]")
            if not row.iconTex then
                row.iconTex = row.columns[2]:CreateTexture(nil, "ARTWORK")
                row.iconTex:SetSize(rh-4, rh-4)
                row.iconTex:SetPoint("CENTER")
                row.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            row.iconTex:SetTexture(spell.icon)
            row.columns[2].textString:SetText("")
            row.columns[3].textString:SetText(spell.name)
            row.columns[4].textString:SetText(spell.duration .. "s")
            row.columns[5].textString:SetText("Remove")
            row.dataIndex = dataIndex
            row:Show()
        else row:Hide() end
    end
end

function EMA_Cooldowns:SettingsSpellListRowClick(rowNumber, columnNumber)
    local class = self.selectedClass
    if not class then return end
    local offset = FauxScrollFrame_GetOffset(self.settingsControl.spellList.listScrollFrame)
    local dataIndex = rowNumber + offset
    local spells = self.db.trackedSpells[class]
    if columnNumber == 1 then
        -- Multi-column logic simplified
        local x = GetCursorPosition() / UIParent:GetEffectiveScale()
        local mid = self.settingsControl.spellList.rows[rowNumber].columns[1]:GetCenter()
        if x < mid then -- Up
            if dataIndex > 1 then
                local spell = table.remove(spells, dataIndex)
                table.insert(spells, dataIndex - 1, spell)
            end
        else -- Dn
            if dataIndex < #spells then
                local spell = table.remove(spells, dataIndex)
                table.insert(spells, dataIndex + 1, spell)
            end
        end
    elseif columnNumber == 5 then
        table.remove(spells, dataIndex)
    else return end
    self:SettingsSpellListScrollRefresh(); self:PushSettingsToTeam(); self:SettingsRefresh()
end

function EMA_Cooldowns:SettingsRefresh()
    if self.settingsControl and self.db then
        local db = self.db
        local showTimers = db.showTimers
        self.settingsControl.checkBoxShowBars:SetValue(db.showBars)
        self.settingsControl.checkBoxLockBars:SetValue(db.lockBars)
        self.settingsControl.checkBoxShowNames:SetValue(db.showNames)
        
        self.settingsControl.sliderScale:SetValue(db.barScale or 1.0)
        self.settingsControl.sliderAlpha:SetValue(db.barAlpha or 1.0)
        
        self.settingsControl.dropdownOrder:SetValue(db.barOrder or "RoleAsc")
        
        self.settingsControl.sliderRunningAlpha:SetValue(db.runningAlpha or 0.3)
        self.settingsControl.sliderReadyAlpha:SetValue(db.readyAlpha or 1.0)
        
        self.settingsControl.checkBoxGlowIfBuffActive:SetValue(db.glowIfBuffActive)
        self.settingsControl.checkBoxGlowAnimated:SetValue(db.glowAnimated)
        self.settingsControl.checkBoxGlowAnimated:SetDisabled(not db.glowIfBuffActive)
        self.settingsControl.colorGlow:SetColor(db.glowColorR or 0, db.glowColorG or 1, db.glowColorB or 1, db.glowColorA or 1)
        self.settingsControl.colorGlow:SetDisabled(not db.glowIfBuffActive)
        
        -- Frame Styles
        self.settingsControl.dropdownFrameBorder:SetValue(db.frameBorderStyle or "Blizzard Tooltip")
        self.settingsControl.dropdownFrameBackground:SetValue(db.frameBackgroundStyle or "Blizzard Dialog Background")
        self.settingsControl.colorFrameBackground:SetColor(db.frameBackgroundColourR or 0.1, db.frameBackgroundColourG or 0.1, db.frameBackgroundColourB or 0.1, db.frameBackgroundColourA or 0.7)
        self.settingsControl.colorFrameBorder:SetColor(db.frameBorderColourR or 0.5, db.frameBorderColourG or 0.5, db.frameBorderColourB or 0.5, db.frameBorderColourA or 1.0)
        
        -- Bar Styles
        self.settingsControl.dropdownBarBorder:SetValue(db.barBorderStyle or "Blizzard Tooltip")
        self.settingsControl.dropdownBarBackground:SetValue(db.barBackgroundStyle or "Blizzard Dialog Background")
        self.settingsControl.colorBarBackground:SetColor(db.barBackgroundColourR or 0.1, db.barBackgroundColourG or 0.1, db.barBackgroundColourB or 0.1, db.barBackgroundColourA or 0.7)
        self.settingsControl.colorBarBorder:SetColor(db.barBorderColourR or 0.5, db.barBorderColourG or 0.5, db.barBorderColourB or 0.5, db.barBorderColourA or 1.0)
        
        self.settingsControl.sliderIconSize:SetValue(db.iconSize or 30)
        self.settingsControl.sliderIconMargin:SetValue(db.iconMargin or 2)
        self.settingsControl.sliderBarMargin:SetValue(db.barMargin or 4)
        
        self.settingsControl.dropdownFont:SetValue(db.fontStyle or "Arial Narrow")
        self.settingsControl.sliderFontSize:SetValue(db.fontSize or 12)
        self.settingsControl.checkBoxShowTimers:SetValue(showTimers)
        self.settingsControl.sliderTimerFontSize:SetValue(db.timerFontSize or 14)
        self.settingsControl.sliderTimerFontSize:SetDisabled(not showTimers)
        
        self.settingsControl.colorTimer:SetColor(db.timerColorR or 1, db.timerColorG or 1, db.timerColorB or 1, 1.0)
        self.settingsControl.colorTimer:SetDisabled(not showTimers)
        
        self.settingsControl.dropdownClass:SetValue(self.selectedClass)
        self:SettingsMemberListScrollRefresh(); self:SettingsSpellListScrollRefresh()
    end
end

function EMA_Cooldowns:OnEMAProfileChanged()
    if self.completeDatabase then self.db = self.completeDatabase.profile end
    self:SettingsRefresh()
    ns.UI:RefreshBars()
end
function EMA_Cooldowns:BeforeEMAProfileChanged() end
