local addonName, ns = ...
local EMA_Cooldowns = ns.EMA_Cooldowns
local UI = {}
ns.UI = UI

local SharedMedia = LibStub("LibSharedMedia-3.0")

-- UI Utils
local function ApplySkin(f)
    if not EMA_Cooldowns.db or not f then return end
    local db = EMA_Cooldowns.db
    local backgroundFile = SharedMedia:Fetch("background", db.backgroundStyle)
    local borderFile = SharedMedia:Fetch("border", db.borderStyle)
    
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = backgroundFile,
            edgeFile = borderFile,
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        f:SetBackdropColor(db.frameBackgroundColourR, db.frameBackgroundColourG, db.frameBackgroundColourB, db.frameBackgroundColourA)
        f:SetBackdropBorderColor(db.frameBorderColourR, db.frameBorderColourG, db.frameBorderColourB, db.frameBorderColourA)
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
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f.characterName = characterName

    -- Name label
    f.nameLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.nameLabel:SetText(Ambiguate(characterName, "short"))

    f.icons = {}

    f.UpdateLayout = function(self)
        if not EMA_Cooldowns.db then return end
        local size = EMA_Cooldowns.db.iconSize
        local margin = EMA_Cooldowns.db.iconMargin
        local showNames = EMA_Cooldowns.db.showNames
        local nameHeight = showNames and (EMA_Cooldowns.db.fontSize + 2) or 0
        
        local activeCount = 0
        local charKey = Ambiguate(self.characterName, "none")
        local cooldowns = EMA_Cooldowns.activeCooldowns[charKey] or {}
        
        -- Sort active cooldowns by remaining time
        local sortedList = {}
        for name, data in pairs(cooldowns) do
            table.insert(sortedList, { name = name, data = data })
        end
        table.sort(sortedList, function(a, b) return (a.data.startTime + a.data.duration) < (b.data.startTime + b.data.duration) end)

        -- Hide all icons first
        for _, iconFrame in ipairs(self.icons) do iconFrame:Hide() end

        for i, info in ipairs(sortedList) do
            activeCount = i
            if not self.icons[i] then
                local b = CreateFrame("Frame", nil, self, "BackdropTemplate")
                b:SetBackdrop({
                    edgeFile = "Interface\Buttons\WHITE8X8",
                    edgeSize = 1,
                })
                b:SetBackdropBorderColor(0, 0, 0, 1)
                
                b.icon = b:CreateTexture(nil, "ARTWORK")
                b.icon:SetPoint("TOPLEFT", 1, -1)
                b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
                b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                
                b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
                b.cooldown:SetAllPoints(b.icon)
                b.cooldown:SetDrawEdge(false)
                
                self.icons[i] = b
            end
            
            local b = self.icons[i]
            b:SetSize(size, size)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", (i-1)*(size + margin) + 4, 4)
            b.icon:SetTexture(info.data.icon)
            b.cooldown:SetCooldown(info.data.startTime, info.data.duration)
            b:Show()
        end

        local totalWidth = math.max(100, (size * activeCount) + (margin * math.max(0, activeCount - 1)) + 8)
        self:SetSize(totalWidth, size + nameHeight + 8)

        self.nameLabel:ClearAllPoints()
        if showNames then
            self.nameLabel:Show()
            self.nameLabel:SetPoint("TOPLEFT", 4, -4)
        else
            self.nameLabel:Hide()
        end

        ApplySkin(self)
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
    ApplySkin(self.masterFrame)
    
    local teamList = {}
    for index, characterName in EMAApi.TeamListOrderedOnline() do
        local class, color = EMAApi.GetClass(characterName)
        table.insert(teamList, { name = characterName, position = index, color = color })
    end

    local order = EMA_Cooldowns.db.barOrder
    if order == "NameAsc" then
        table.sort(teamList, function(a, b) return a.name < b.name end)
    elseif order == "NameDesc" then
        table.sort(teamList, function(a, b) return a.name > b.name end)
    elseif order == "EMAPosition" then
        table.sort(teamList, function(a, b) return a.position < b.position end)
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
end

function UI:UpdateUI()
    local currentTime = GetTime()
    local needsLayoutUpdate = false

    -- Clean up expired cooldowns
    for charKey, cooldowns in pairs(EMA_Cooldowns.activeCooldowns) do
        for spellName, data in pairs(cooldowns) do
            if currentTime > (data.startTime + data.duration) then
                cooldowns[spellName] = nil
                needsLayoutUpdate = true
            end
        end
    end

    if needsLayoutUpdate or true then -- For now, update layout every tick to keep timers smooth
        for _, bar in pairs(self.teamBars) do
            if bar:IsShown() then
                bar:UpdateLayout()
            end
        end
    end
end

-- Periodical update
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed > 0.5 then
        UI:UpdateUI()
        self.elapsed = 0
    end
end)
