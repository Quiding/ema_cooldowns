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
        f:SetBackdrop({
            bgFile = backgroundFile,
            edgeFile = borderFile,
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
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

    f.nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.nameLabel:SetText(Ambiguate(characterName, "short"))

    f.icons = {}

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
        local tracked = EMA_Cooldowns.db.trackedSpells[classKey] or {}
        
        for _, iconFrame in ipairs(self.icons) do iconFrame:Hide() end

        local activeCount = 0
        for i, spellInfo in ipairs(tracked) do
            activeCount = i
            if not self.icons[i] then
                local b = CreateFrame("Frame", nil, self, "BackdropTemplate")
                b:SetFrameLevel(self:GetFrameLevel() + 2)
                b:SetBackdrop({
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                })
                b:SetBackdropBorderColor(0, 0, 0, 1)
                
                b.icon = b:CreateTexture(nil, "OVERLAY")
                b.icon:SetPoint("TOPLEFT", 1, -1)
                b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
                b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                
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
            b:SetPoint("BOTTOMLEFT", (i-1)*(size + margin) + 4 + (self.leftExtraWidth or 0), 4)
            b.icon:SetTexture(spellInfo.icon or 134400)
            
            local activeData = EMA_Cooldowns.activeCooldowns[charKey] and EMA_Cooldowns.activeCooldowns[charKey][spellInfo.name]
            if activeData then
                local remaining = activeData.startTime + activeData.duration - GetTime()
                if remaining > 0 then
                    b:SetAlpha(db.runningAlpha or 0.3)
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
                    b:SetAlpha(db.readyAlpha or 1.0)
                    b.cooldown:Hide()
                    b.timerText:Hide()
                end
            else
                b:SetAlpha(db.readyAlpha or 1.0)
                b.cooldown:Hide()
                b.timerText:Hide()
            end
            b:Show()
        end

        local totalWidth = (size * activeCount) + (margin * math.max(0, activeCount - 1)) + 8 + (self.extraWidth or 0) + (self.leftExtraWidth or 0)
        if activeCount == 0 and (self.extraWidth or 0) == 0 and (self.leftExtraWidth or 0) == 0 then totalWidth = 100 end
        self:SetSize(totalWidth, size + nameHeight + 8)

        self.nameLabel:ClearAllPoints()
        if showNames then
            self.nameLabel:Show()
            self.nameLabel:SetPoint("TOPLEFT", 4, -4)
        else
            self.nameLabel:Hide()
        end

        ApplySkin(self, "bar")
        ApplyFontStyle(self.nameLabel)
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
        self.masterFrame:RegisterForDrag("LeftButton")
        self.masterFrame:SetFrameStrata("MEDIUM")
        self.masterFrame:SetSize(200, 40)
        self.masterFrame:SetScript("OnDragStart", function(self)
            if not EMA_Cooldowns.db or not EMA_Cooldowns.db.lockBars or IsAltKeyDown() then
                self:StartMoving()
            end
        end)
        self.masterFrame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if EMA_Cooldowns.db then
                local point, _, _, x, y = self:GetPoint()
                EMA_Cooldowns.db.teamBarsPos = { point = point, x = x, y = y }
            end
        end)
    end
    
    self:UpdatePositionFromDB()
    self:RefreshBars()
end

function UI:RefreshBars()
    if not EMA_Cooldowns.db or not self.masterFrame then return end
    
    if not EMA_Cooldowns.db.showBars then
        self.masterFrame:Hide()
        return
    end

    self.masterFrame:Show()
    self.masterFrame:SetScale(EMA_Cooldowns.db.barScale)
    self.masterFrame:SetAlpha(EMA_Cooldowns.db.barAlpha)
    ApplySkin(self.masterFrame, "frame")
    
    local teamList = {}
    for index, characterName in EMAApi.TeamListOrdered() do
        if EMAApi.GetCharacterOnlineStatus(characterName) == true and EMA_Cooldowns.db.enabledMembers[characterName] ~= false then
            local class, color = EMAApi.GetClass(characterName)
            table.insert(teamList, { name = characterName, position = index, color = color })
        end
    end

    local order = EMA_Cooldowns.db.barOrder
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

    local currentY = -8
    local barMargin = EMA_Cooldowns.db.barMargin
    local maxBarWidth = 0
    
    for _, info in ipairs(teamList) do
        local characterName = info.name
        local color = info.color
        
        if not self.teamBars[characterName] then
            self.teamBars[characterName] = CreateCooldownBar(characterName, self.masterFrame)
        end
        local bar = self.teamBars[characterName]
        bar:UpdateLayout()
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", 8, currentY)
        bar:Show()
        
        if color then
            bar.nameLabel:SetTextColor(color.r, color.g, color.b)
        end
        
        currentY = currentY - bar:GetHeight() - barMargin
        maxBarWidth = math.max(maxBarWidth, bar:GetWidth())
    end
    
    if #teamList > 0 then
        self.masterFrame:SetHeight(math.abs(currentY) - barMargin + 8)
        self.masterFrame:SetWidth(maxBarWidth + 16)
    else
        self.masterFrame:SetHeight(40)
        self.masterFrame:SetWidth(200)
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
