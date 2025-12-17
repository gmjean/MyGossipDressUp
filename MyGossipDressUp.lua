--[[
    MyGossipDressUp - Save & Load Edition (3.3.5a)
    Versão 2.1
    Novidades: 
    - Botão "Salvar Set": Guarda a combinação atual.
    - Botão "Carregar Set": Reaplica a combinação salva.
    - Sistema inteligente de rastreamento de slots (InvType).
]]

local addonName, MGDU = ...
MGDU = MGDU or {}
MGDU.version = "2.1-SaveLoad"
MGDU.enabled = true
MGDU.debug = false
MGDU.colorPrefix = "|cff00ff00[MyGossipDressUp]|r"

-- Configurações Salvas (serão carregadas no ADDON_LOADED)
MyGossipDressUpSettings = MyGossipDressUpSettings or {}
MyGossipDressUpSettings.savedOutfit = nil -- Onde o set será salvo

-- Estado Interno
MGDU.state = {
    mouseOverButton = nil,
    isCtrlDown = false,
    lastLink = nil,
    currentOutfitTracker = {} -- Rastreia o que está no modelo agora
}

MGDU.dressUpQueue = {
    link = nil,
    frameDelay = 0,
    maxDelay = 3
}

MGDU.rotation = {
    active = false,
    target = nil,
    speed = math.rad(360)
}

MGDU.previewFrame = nil
MGDU.previewModel = nil

local eventFrame = CreateFrame("Frame")
local updateFrame = CreateFrame("Frame")

-- Mapeamento de InvType (API 3.3.5a) para agrupar slots
-- Isso garante que se você trocar um Robe por uma Túnica, ele atualize o slot certo.
local INVTYPE_MAP = {
    ["INVTYPE_HEAD"] = "HEAD",
    ["INVTYPE_SHOULDER"] = "SHOULDER",
    ["INVTYPE_BODY"] = "SHIRT",
    ["INVTYPE_CHEST"] = "CHEST",
    ["INVTYPE_ROBE"] = "CHEST",
    ["INVTYPE_WAIST"] = "WAIST",
    ["INVTYPE_LEGS"] = "LEGS",
    ["INVTYPE_FEET"] = "FEET",
    ["INVTYPE_WRIST"] = "WRIST",
    ["INVTYPE_HAND"] = "HANDS",
    ["INVTYPE_CLOAK"] = "CLOAK",
    ["INVTYPE_WEAPON"] = "MAINHAND",
    ["INVTYPE_SHIELD"] = "OFFHAND",
    ["INVTYPE_2HWEAPON"] = "MAINHAND",
    ["INVTYPE_WEAPONMAINHAND"] = "MAINHAND",
    ["INVTYPE_WEAPONOFFHAND"] = "OFFHAND",
    ["INVTYPE_HOLDABLE"] = "OFFHAND",
    ["INVTYPE_RANGED"] = "RANGED",
    ["INVTYPE_THROWN"] = "RANGED",
    ["INVTYPE_RANGEDRIGHT"] = "RANGED",
    ["INVTYPE_RELIC"] = "RANGED",
    ["INVTYPE_TABARD"] = "TABARD",
}

-- =============================================================
-- FUNÇÕES UTILITÁRIAS
-- =============================================================

function MGDU:Print(msg) print(self.colorPrefix .. " " .. msg) end
function MGDU:Debug(msg) if self.debug then print("|cffaaaaaa[MGDU-D]|r " .. msg) end end

function MGDU:ExtractLink(text)
    if not text then return nil end
    return string.match(text, "(|c%x+|Hitem:[^|]+|h[^|]+|h|r)")
end

local function NormalizeAngle(angle)
    return angle - (2 * math.pi) * math.floor((angle + math.pi) / (2 * math.pi))
end

-- =============================================================
-- LOGICA DE SETS (SALVAR / CARREGAR)
-- =============================================================

function MGDU:TrackItem(link)
    -- Descobre onde o item é equipado e salva na tabela de rastreamento
    local _, _, _, _, _, _, _, _, equipSlot = GetItemInfo(link)
    if equipSlot and INVTYPE_MAP[equipSlot] then
        local slotKey = INVTYPE_MAP[equipSlot]
        MGDU.state.currentOutfitTracker[slotKey] = link
        self:Debug("Item rastreado no slot: " .. slotKey)
    end
end

function MGDU:SaveOutfit()
    -- Copia o tracker atual para as variáveis salvas
    local count = 0
    local newSet = {}
    for k, v in pairs(MGDU.state.currentOutfitTracker) do
        newSet[k] = v
        count = count + 1
    end
    
    if count > 0 then
        MyGossipDressUpSettings.savedOutfit = newSet
        self:Print("Conjunto com " .. count .. " itens salvo com sucesso!")
    else
        self:Print("Nada para salvar. Visualize itens primeiro.")
    end
end

function MGDU:LoadOutfit()
    local savedSet = MyGossipDressUpSettings.savedOutfit
    if not savedSet or next(savedSet) == nil then
        self:Print("Nenhum conjunto salvo encontrado.")
        return
    end

    if not self.previewFrame:IsShown() then self.previewFrame:Show() end

    -- Limpa o modelo primeiro para evitar sobreposição errada
    self.previewModel:Undress()
    MGDU.state.currentOutfitTracker = {} -- Reinicia o tracker

    self:Print("Carregando conjunto salvo...")
    
    -- Aplica item por item
    for slot, link in pairs(savedSet) do
        -- Atualiza tracker
        MGDU.state.currentOutfitTracker[slot] = link
        -- Aplica visual
        pcall(function() self.previewModel:TryOn(link) end)
    end
end

-- =============================================================
-- UI: PREVIEW FRAME
-- =============================================================

function MGDU:CreatePreviewFrame()
    if MGDU.previewFrame then return end
    
    local f = CreateFrame("Frame", "MGDU_PreviewFrame", UIParent)
    f:SetSize(340, 480) -- Um pouco mais largo para os botões extras
    f:SetPoint("CENTER", UIParent, "CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetBackdrop({ 
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", 
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", 
        tile = true, tileSize = 32, edgeSize = 32, 
        insets = { left = 11, right = 12, top = 12, bottom = 11 } 
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); self:SetUserPlaced(true) end)
    f:Hide()

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("Outfit Manager")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -10)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local model = CreateFrame("DressUpModel", "MGDU_PreviewModel", f)
    model:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -38)
    model:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 80) -- Mais espaço embaixo
    model:EnableMouse(true)
    
    f:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then model:ZoomIn() else model:ZoomOut() end
    end)
    
    model:SetScript("OnMouseDown", function(self, button) 
        if button == "LeftButton" then 
            self.isDragging = true
            self.prevX, _ = GetCursorPosition()
        end
    end)
    model:SetScript("OnMouseUp", function(self) self.isDragging = false end)
    model:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local currentX, _ = GetCursorPosition()
            local rotation = (currentX - self.prevX) / 50
            self:SetFacing(self:GetFacing() + rotation)
            self.prevX = currentX
        end
    end)

    -- === BOTÕES DE CONTROLE ===

    local function CreateBtn(name, text, w, h, anchor, relPoint, x, y, func)
        local b = CreateFrame("Button", name, f, "UIPanelButtonTemplate")
        b:SetSize(w, h)
        b:SetPoint(anchor, relPoint, anchor, x, y) -- Ajuste relativo simples
        b:SetText(text)
        b:SetScript("OnClick", func)
        return b
    end

    -- Rotação
    local btnLeft = CreateBtn(nil, "<", 25, 25, "BOTTOMLEFT", f, 15, 45, function() MGDU:TargetRotation(-1) end)
    local btnRight = CreateBtn(nil, ">", 25, 25, "BOTTOMRIGHT", f, -15, 45, function() MGDU:TargetRotation(1) end)

    -- Reset (Volta ao Player)
    local btnReset = CreateBtn(nil, "Reset Char", 80, 25, "BOTTOM", f, 0, 45, function() MGDU:ResetModelToPlayer() end)

    -- Linha de Baixo (Gerenciamento)
    
    -- Limpar (Undress)
    local btnUndress = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnUndress:SetSize(60, 25)
    btnUndress:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 15, 15)
    btnUndress:SetText("Limpar")
    btnUndress:SetScript("OnClick", function() 
        model:Undress()
        MGDU.state.currentOutfitTracker = {} -- Limpa tracker
    end)

    -- Salvar
    local btnSave = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnSave:SetSize(80, 25)
    btnSave:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
    btnSave:SetText("Salvar Set")
    btnSave:SetScript("OnClick", function() MGDU:SaveOutfit() end)

    -- Carregar
    local btnLoad = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnLoad:SetSize(80, 25)
    btnLoad:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 15)
    btnLoad:SetText("Carregar Set")
    btnLoad:SetScript("OnClick", function() MGDU:LoadOutfit() end)

    MGDU.previewFrame = f
    MGDU.previewModel = model
end

-- =============================================================
-- LÓGICA CORE
-- =============================================================

function MGDU:TargetRotation(dir)
    if not self.previewModel then return end
    local step = math.rad(45)
    local current = self.rotation.active and self.rotation.target or self.previewModel:GetFacing() or 0
    self.rotation.target = NormalizeAngle(current + (dir * step))
    self.rotation.active = true
end

function MGDU:ResetModelToPlayer()
    if self.previewModel then
        self.previewModel:SetUnit("player")
        self.previewModel:SetFacing(0)
        self.rotation.target = nil
        self.rotation.active = false
        MGDU.state.currentOutfitTracker = {} -- Reseta tracker pois voltou ao player
        self:Debug("Modelo resetado para Player.")
    end
end

function MGDU:ProcessPreview(textSource)
    if not self.enabled then return end
    local link = self:ExtractLink(textSource)
    if link then
        if link == self.state.lastLink then return end
        self.state.lastLink = link
        self:PrepareFrame(link)
    end
end

function MGDU:PrepareFrame(link)
    if not self.previewFrame then self:CreatePreviewFrame() end
    local f = self.previewFrame
    
    local isNewWindow = not f:IsShown()
    f:Show()
    
    if isNewWindow then
        if not f:IsUserPlaced() then
            f:ClearAllPoints()
            f:SetPoint("CENTER", UIParent, "CENTER")
        end
        self.previewModel:SetUnit("player")
        self.previewModel:SetFacing(0)
        MGDU.state.currentOutfitTracker = {} 
        self.dressUpQueue.frameDelay = self.dressUpQueue.maxDelay
    else
        self.dressUpQueue.frameDelay = 0
    end

    self.dressUpQueue.link = link
end

function MGDU:ApplyDressUp()
    local model = self.previewModel
    local link = self.dressUpQueue.link
    
    if not model or not link then return end
    
    -- Rastreia o item na nossa "memória" do set
    self:TrackItem(link)

    -- Aplica visualmente
    local success, _ = pcall(function() model:TryOn(link) end)
    if not success then
        pcall(function() model:SetHyperlink(link) end)
    end
    
    self.dressUpQueue.link = nil
end

-- =============================================================
-- HOOKS E EVENTOS
-- =============================================================

function MGDU:HookGossipButtons()
    for i = 1, 32 do
        local btn = _G["GossipTitleButton" .. i]
        if btn and not btn.MGDU_Hooked then
            btn:HookScript("OnEnter", function(self)
                MGDU.state.mouseOverButton = self
                if IsControlKeyDown() then
                    local text = self:GetText() or (self.text and self.text:GetText())
                    MGDU:ProcessPreview(text)
                end
            end)
            btn:HookScript("OnLeave", function(self)
                MGDU.state.mouseOverButton = nil
                MGDU.state.lastLink = nil 
            end)
            btn.MGDU_Hooked = true
        end
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")

eventFrame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Carrega SavedVariables
        if not MyGossipDressUpSettings then MyGossipDressUpSettings = {} end
        
        MGDU:CreatePreviewFrame()
        MGDU:HookGossipButtons()
        MGDU:Print("Carregado v" .. MGDU.version)
        
    elseif event == "GOSSIP_SHOW" then
        MGDU:HookGossipButtons()
        
    elseif event == "MODIFIER_STATE_CHANGED" then
        if string.find(arg1, "CTRL") then
            local isDown = (arg2 == 1)
            MGDU.state.isCtrlDown = isDown
            if isDown and MGDU.state.mouseOverButton then
                local btn = MGDU.state.mouseOverButton
                local text = btn:GetText() or (btn.text and btn.text:GetText())
                MGDU:ProcessPreview(text)
            end
        end
    end
end)

updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not MGDU.enabled then return end

    if MGDU.dressUpQueue.link then
        if MGDU.dressUpQueue.frameDelay > 0 then
            MGDU.dressUpQueue.frameDelay = MGDU.dressUpQueue.frameDelay - 1
        else
            MGDU:ApplyDressUp()
        end
    end

    if MGDU.rotation.active and MGDU.previewModel then
        local current = MGDU.previewModel:GetFacing()
        local target = MGDU.rotation.target
        if current and target then
            local diff = NormalizeAngle(target - current)
            if math.abs(diff) < math.rad(1) then
                MGDU.previewModel:SetFacing(target)
                MGDU.rotation.active = false
            else
                local step = MGDU.rotation.speed * elapsed
                if step > math.abs(diff) then step = math.abs(diff) end
                local dir = (diff > 0) and 1 or -1
                MGDU.previewModel:SetFacing(NormalizeAngle(current + (dir * step)))
            end
        else
            MGDU.rotation.active = false
        end
    end
end)

SLASH_MGDRESSUP1 = "/mgdu"
SlashCmdList["MGDRESSUP"] = function(msg)
    local cmd = msg:lower()
    if cmd == "reset" then
        if MGDU.previewFrame then
            MGDU.previewFrame:Hide()
            MGDU.previewFrame:ClearAllPoints()
            MGDU.previewFrame:SetPoint("CENTER", UIParent, "CENTER")
            MGDU:Print("Janela resetada.")
        end
    else
        MGDU:Print("Use CTRL + Mouse no Gossip para visualizar.")
    end
end
