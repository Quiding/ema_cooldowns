local addonName, ns = ...
local EMA_Cooldowns = ns.EMA_Cooldowns
local UI = {}
ns.UI = UI

local SharedMedia = LibStub("LibSharedMedia-3.0")

-- UI Utils
local function ApplySkin(f, prefix)
    if not EMA_Cooldowns.db or not f then return end
    local db = EMA_Cooldowns.db
    local backgroundFile = SharedMedia:Fetch("background", db[prefix.."BackgroundStyle"])
    local borderFile = SharedMedia:Fetch("border", db[prefix.."BorderStyle"])
    
    if f.SetBackdrop then
        -- Insets set to 0 to make background match icon height perfectly
        f:SetBackdrop({
            bgFile = backgroundFile,
            edgeFile = borderFile,
            tile = false, tileSize = 0, edgeSize = 2,
            insets = { left = 0, right = 0, top = 0, bottom = 0 }
        })
        f:SetBackdropColor(
            db[prefix.."BackgroundColourR"] or 0.1, 
            db[prefix.."BackgroundColourG"] or 0.1, 
            db[prefix.."BackgroundColourB"] or 0.1, 
            db[prefix.."BackgroundColourA"] or 0.7
        )
        f:SetBackdropBorderColor(
            db[prefix.."BorderColourR"] or 0.5, 
            db[prefix.."BorderColourG"] or 0.5, 
            db[prefix.."BorderColourB"] or 0.5, 
            db[prefix.."BorderColourA"] or 1.0
        )
    end
end

local function ApplyFontStyle(textString)
    if not EMA_Cooldowns.db or not textString then return end
    local db = EMA_Cooldowns.db
    local fontFile = SharedMedia:Fetch("font", db.fontStyle)
    textString:SetFont(fontFile, db.fontSize, "OUTLINE")
end

-----------------------------------------------------------------------
-- BAR CREATION
-----------------------------------------------------------------------
local function CreateCooldownBar(characterName, parent)
    local f = CreateFrame("Frame", "EMACooldownsBar_"..Ambiguate(characterName, "none"), parent, "BackdropTemplate")
    f.characterName = characterName
    f:SetFrameLevel(parent:GetFrameLevel() + 1)
    f.extraWidth = 0 
    f.leftExtraWidth = 0
    f.extraHeight = 0
    f.topExtraHeight = 0
    f.topExtraWidth = 0
    f.bottomExtraWidth = 0

    f.nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.nameLabel:SetText(Ambiguate(characterName, "short"))

    f.icons = {}

    -- Move Handle
    f.handle = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.handle:SetSize(10, 10) -- Height will be updated in UpdateLayout
    f.handle:SetPoint("TOPRIGHT", f, "TOPLEFT", 0, 0)
    f.handle:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f.handle:SetBackdropColor(0, 0, 0, 1)
    f.handle:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    f.handle:EnableMouse(true)
    f.handle:RegisterForDrag("LeftButton")
    f.handle:SetScript("OnDragStart", function()
        if not EMA_Cooldowns.db.lockBars then
            f:StartMoving()
        end
    end)
    f.handle:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relativePoint, x, y = f:GetPoint()
        if point then
            local charKey = Ambiguate(f.characterName, "none"):lower()
            EMA_Cooldowns.db.individualBarPositions[charKey] = { point = point, relativePoint = relativePoint, x = x, y = y }
        end
    end)

    f.UpdateLayout = function(self)
        if not EMA_Cooldowns.db then return end
        local db = EMA_Cooldowns.db
        local size = db.iconSize
        local margin = db.iconMargin
        local showNames = db.showNames
        local nameHeight = showNames and (db.fontSize + 2) or 0
        
        local charKey = Ambiguate(self.characterName, "none"):lower()
        local class, _ = EMAApi.GetClass(self.characterName)
        local classKey = class and class:upper() or "SHAMAN"
        local tracked = db.trackedSpells[classKey] or {}
        
        -- Update handle visibility and size
        if db.breakUpBars and not db.lockBars then
            self.handle:Show()
        else
            self.handle:Hide()
        end
        self.handle:SetHeight(size + nameHeight)

        for _, iconFrame in ipairs(self.icons) do iconFrame:Hide() end

        local activeCount = 0
        for i, spellInfo in ipairs(tracked) do
            activeCount = i
            if not self.icons[i] then
                local b = CreateFrame("Frame", nil, self, "BackdropTemplate")
                b:SetFrameLevel(self:GetFrameLevel() + 2)
                
                b.icon = b:CreateTexture(nil, "BACKGROUND")
                b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                
                b.glow = b:CreateTexture(nil, "OVERLAY", nil, 7)
                b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                b.glow:SetBlendMode("ADD")
                b.glow:Hide()
                
                b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
                b.cooldown:SetAllPoints(b.icon)
                b.cooldown:SetDrawEdge(false)
                b.cooldown:SetFrameLevel(b:GetFrameLevel() + 1)

                b.timerText = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
                b.timerText:SetPoint("CENTER", 0, 0)
                
                self.icons[i] = b
            end
            
            local b = self.icons[i]
            b:SetSize(size, size)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", (i-1)*(size + margin) + (self.leftExtraWidth or 0), (self.extraHeight or 0))
            
            -- Update Backdrop and Icon Points
            b:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = nil,
                edgeSize = 0,
            })
            b:SetBackdropColor(0, 0, 0, 0)
            b:SetBackdropBorderColor(0, 0, 0, 0)
            b.icon:ClearAllPoints()
            b.icon:SetAllPoints(b)
            b.glow:ClearAllPoints()
            b.glow:SetPoint("TOPLEFT", -4, 4)
            b.glow:SetPoint("BOTTOMRIGHT", 4, -4)

            b.icon:SetTexture(spellInfo.icon or 134400)
            
            local LBG = LibStub("LibButtonGlow-1.0", true)
            local activeData = EMA_Cooldowns.activeCooldowns[charKey] and EMA_Cooldowns.activeCooldowns[charKey][spellInfo.name]
            local bInfo = EMA_Cooldowns.delayedSpells[spellInfo.name]
            local buffName = bInfo and bInfo.name
            local isBuffActive = buffName and EMA_Cooldowns.teamBuffs[charKey] and EMA_Cooldowns.teamBuffs[charKey][buffName]
            
            local shouldGlow = false
            if db.glowIfBuffActive and isBuffActive then shouldGlow = true end
            if activeData and activeData.pendingBuff then shouldGlow = true end
            
            local readyAlpha = db.readyAlpha or 1.0
            local runningAlpha = db.runningAlpha or 0.3

            if shouldGlow then
                if db.glowAnimated and LBG then
                    b.glow:Hide()
                    LBG.ShowOverlayGlow(b, { color = { db.glowColorR or 0, db.glowColorG or 1, db.glowColorB or 1, db.glowColorA or 1 } })
                else
                    if LBG then LBG.HideOverlayGlow(b) end
                    b.glow:SetVertexColor(db.glowColorR or 0, db.glowColorG or 1, db.glowColorB or 1, db.glowColorA or 1)
                    b.glow:Show()
                end
                b.icon:SetAlpha(readyAlpha)
                b.cooldown:Hide()
                b.timerText:Hide()
            elseif activeData and not activeData.pendingBuff then
                b.glow:Hide()
                if LBG then LBG.HideOverlayGlow(b) end
                local remaining = activeData.startTime + activeData.duration - GetTime()
                if remaining > 0 then
                    b.icon:SetAlpha(runningAlpha)
                    b.cooldown:SetCooldown(activeData.startTime, activeData.duration)
                    b.cooldown:Show()
                    if db.showTimers then
                        local fontFile = SharedMedia:Fetch("font", db.fontStyle)
                        b.timerText:SetFont(fontFile, db.timerFontSize, "OUTLINE")
                        b.timerText:SetTextColor(db.timerColorR or 1, db.timerColorG or 1, db.timerColorB or 1)
                        b.timerText:SetText(math.floor(remaining))
                        b.timerText:Show()
                    else
                        b.timerText:Hide()
                    end
                else
                    EMA_Cooldowns.activeCooldowns[charKey][spellInfo.name] = nil
                    b.icon:SetAlpha(readyAlpha)
                    b.cooldown:Hide()
                    b.timerText:Hide()
                end
            else
                b.glow:Hide()
                if LBG then LBG.HideOverlayGlow(b) end
                b.icon:SetAlpha(readyAlpha)
                b.cooldown:Hide()
                b.timerText:Hide()
            end
            b:Show()
        end

        ApplyFontStyle(self.nameLabel)
        local nameWidth = showNames and (self.nameLabel:GetStringWidth() + 4) or 0
        local iconsWidth = (size * activeCount) + (margin * math.max(0, activeCount - 1)) + (self.extraWidth or 0) + (self.leftExtraWidth or 0)
        local totalWidth = math.max(nameWidth, iconsWidth, (self.topExtraWidth or 0), (self.bottomExtraWidth or 0))
        if activeCount == 0 and (self.extraWidth or 0) == 0 and (self.leftExtraWidth or 0) == 0 and (self.topExtraWidth or 0) == 0 and (self.bottomExtraWidth or 0) == 0 then totalWidth = math.max(totalWidth, 40) end
        
        local totalHeight = size + nameHeight + (self.extraHeight or 0) + (self.topExtraHeight or 0)
        self:SetSize(totalWidth, totalHeight)

        self.nameLabel:ClearAllPoints()
        if showNames then
            self.nameLabel:Show()
            self.nameLabel:SetPoint("TOPLEFT", (self.leftExtraWidth or 0), 0)
            self.nameLabel:SetJustifyH("LEFT")
        else
            self.nameLabel:Hide()
        end

        ApplySkin(self, "bar")
    end

    f:UpdateLayout()
    return f
end

-----------------------------------------------------------------------
-- UI MANAGEMENT
-----------------------------------------------------------------------
UI.teamBars = {}
UI.masterFrame = nil

function UI:UpdatePositionFromDB()
    if not EMA_Cooldowns.db then return end
    local p = EMA_Cooldowns.db.teamBarsPos
    if self.masterFrame then
        self.masterFrame:ClearAllPoints()
        self.masterFrame:SetPoint(p.point, UIParent, p.point, p.x, p.y)
    end
end

function UI:Initialize()
    if not self.masterFrame then
        self.masterFrame = CreateFrame("Frame", "EMACooldownsMasterFrame", UIParent, "BackdropTemplate")
        self.masterFrame:SetMovable(true)
        self.masterFrame:EnableMouse(true)
        self.masterFrame:SetFrameStrata("MEDIUM")
        self.masterFrame:SetSize(200, 40)

        -- Master Handle
        self.masterFrame.handle = CreateFrame("Frame", nil, self.masterFrame, "BackdropTemplate")
        self.masterFrame.handle:SetSize(10, 40)
        self.masterFrame.handle:SetPoint("TOPRIGHT", self.masterFrame, "TOPLEFT", 0, 0)
        self.masterFrame.handle:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        self.masterFrame.handle:SetBackdropColor(0, 0, 0, 1)
        self.masterFrame.handle:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        self.masterFrame.handle:EnableMouse(true)
        self.masterFrame.handle:RegisterForDrag("LeftButton")
        self.masterFrame.handle:SetScript("OnDragStart", function()
            if not EMA_Cooldowns.db or not EMA_Cooldowns.db.lockBars then
                self.masterFrame:StartMoving()
            end
        end)
        self.masterFrame.handle:SetScript("OnDragStop", function()
            self.masterFrame:StopMovingOrSizing()
            if EMA_Cooldowns.db then
                local point, _, relativePoint, x, y = self.masterFrame:GetPoint()
                EMA_Cooldowns.db.teamBarsPos = { point = point, relativePoint = relativePoint, x = x, y = y }
            end
        end)
    end
    
    self:UpdatePositionFromDB()
    self:RefreshBars()
end

function UI:RefreshBars()
    if not EMA_Cooldowns.db or not self.masterFrame then return end
    
    local db = EMA_Cooldowns.db
    if not db.showBars then
        self.masterFrame:Hide()
        for _, bar in pairs(self.teamBars) do bar:Hide() end
        return
    end

    self.masterFrame:Show()
    self.masterFrame:SetScale(db.barScale)
    self.masterFrame:SetAlpha(db.barAlpha)
    
    -- If breaking up bars, hide the master frame's visual skin
    if db.breakUpBars then
        self.masterFrame:SetBackdrop(nil)
        self.masterFrame.handle:Hide()
    else
        ApplySkin(self.masterFrame, "frame")
        if not db.lockBars then
            self.masterFrame.handle:Show()
        else
            self.masterFrame.handle:Hide()
        end
    end
    
    local teamList = {}
    for index, characterName in EMAApi.TeamListOrdered() do
        local isOnline = EMAApi.GetCharacterOnlineStatus(characterName)
        if (isOnline == true or characterName == EMA_Cooldowns.characterName) and db.enabledMembers[characterName] ~= false then
            local class, color = EMAApi.GetClass(characterName)
            table.insert(teamList, { name = characterName, position = index, color = color })
        end
    end

    local order = db.barOrder
    if order == "NameAsc" then
        table.sort(teamList, function(a, b) return a.name < b.name end)
    elseif order == "NameDesc" then
        table.sort(teamList, function(a, b) return a.name > b.name end)
    elseif order == "EMAPosition" then
        table.sort(teamList, function(a, b) return a.position < b.position end)
    elseif order == "RoleAsc" then
        local roleWeights = { ["TANK"] = 1, ["HEALER"] = 2, ["DAMAGER"] = 3, ["NONE"] = 4 }
        table.sort(teamList, function(a, b)
            local unitA = Ambiguate(a.name, "none")
            local unitB = Ambiguate(b.name, "none")
            local roleA = UnitGroupRolesAssigned(unitA) or "NONE"
            local roleB = UnitGroupRolesAssigned(unitB) or "NONE"
            if roleA ~= roleB then
                return (roleWeights[roleA] or 99) < (roleWeights[roleB] or 99)
            end
            return a.name < b.name
        end)
    end

    for name, bar in pairs(self.teamBars) do bar:Hide() end

    local currentY = 0
    local barMargin = db.barMargin
    local maxBarWidth = 0
    
    for _, info in ipairs(teamList) do
        local characterName = info.name
        local color = info.color
        local charKey = Ambiguate(characterName, "none"):lower()
        
        if not self.teamBars[characterName] then
            self.teamBars[characterName] = CreateCooldownBar(characterName, self.masterFrame)
        end
        local bar = self.teamBars[characterName]
        
        if db.breakUpBars then
            local pos = db.individualBarPositions[charKey]
            if not pos then
                -- Initial position calculation: Stay where you were in the group
                local point, relativeTo, relativePoint, x, y = bar:GetPoint()
                if point and bar:GetLeft() and bar:GetTop() then
                    -- Convert to screen coordinates
                    local s = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
                    local left = bar:GetLeft() * s
                    local top = bar:GetTop() * s
                    db.individualBarPositions[charKey] = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = left, y = (top - UIParent:GetHeight()) }
                    pos = db.individualBarPositions[charKey]
                end
            end

            bar:SetParent(UIParent)
            bar:SetMovable(true)
            bar:SetScale(db.barScale)
            bar:SetAlpha(db.barAlpha)
            bar:SetFrameStrata("MEDIUM")
            bar:ClearAllPoints()
            
            if pos then
                bar:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
            else
                bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            end
        else
            bar:SetParent(self.masterFrame)
            bar:SetMovable(false)
            bar:SetScale(1.0) -- Scale inherited from master
            bar:SetAlpha(1.0) -- Alpha inherited from master
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", 0, currentY)
        end
        
        bar:UpdateLayout()
        bar:Show()

        if not db.breakUpBars then
            currentY = currentY - bar:GetHeight() - barMargin
        end
        
        if color then
            bar.nameLabel:SetTextColor(color.r, color.g, color.b)
        end
        
        maxBarWidth = math.max(maxBarWidth, bar:GetWidth())
    end
    
    if not db.breakUpBars then
        if #teamList > 0 then
            self.masterFrame:SetHeight(math.abs(currentY) - barMargin)
            self.masterFrame:SetWidth(maxBarWidth)
            self.masterFrame.handle:SetHeight(self.masterFrame:GetHeight())
        else
            self.masterFrame:SetHeight(40)
            self.masterFrame:SetWidth(200)
        end
    else
        self.masterFrame:Hide() -- Hide master frame entirely if bars are independent
    end
    
    EMA_Cooldowns.teamBars = self.teamBars
end

function UI:UpdateUI()
    for _, bar in pairs(self.teamBars) do
        if bar:IsShown() then
            bar:UpdateLayout()
        end
    end
end

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed > 0.1 then
        UI:UpdateUI()
        self.elapsed = 0
    end
end)
