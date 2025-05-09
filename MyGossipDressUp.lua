--[[
    MyGossipDressUp - Custom Frame Version for 3.3.5a (AzerothCore)
    Previews items using a custom frame and DressUpModel widget.
    Reacts to mouseover on gossip options with Ctrl.
    Frame stays open. Rotation via mouse drag AND smooth button rotation.
]]

local addonName, MGDU = ...
MGDU = MGDU or {}
MGDU.version = "1.4.7-335a-customframe" -- Rotação suave nos botões
MGDU.enabled = true
MGDU.debug = false
MGDU.lastItem = nil
MGDU.colorPrefix = "|cff00ff00[MyGossipDressUp]|r"
MGDU.currentlyPreviewingLink = nil
MGDU.isCtrlDown = false 

MGDU.dressUpAttempt = {
    link = nil,
    frameDelay = 0,
    maxDelay = 3
}

-- Variáveis para Rotação Suave
MGDU.isRotating = false
MGDU.targetFacing = nil
MGDU.rotationSpeed = math.rad(270) -- Velocidade: 270 graus por segundo (ajustável)

MGDU.previewFrame = nil
MGDU.previewModel = nil

local gameEventHandlerFrame = CreateFrame("Frame")
gameEventHandlerFrame:RegisterEvent("GOSSIP_SHOW")
gameEventHandlerFrame:RegisterEvent("GOSSIP_CLOSED")
gameEventHandlerFrame:RegisterEvent("PLAYER_LEAVING_WORLD")
gameEventHandlerFrame:RegisterEvent("ADDON_LOADED")

local onUpdateLoopFrame = CreateFrame("Frame")

-- Funções Auxiliares de Ângulo (Radianos)
local PI = math.pi
local TWO_PI = 2 * PI

-- Normaliza um ângulo para o intervalo (-PI, PI]
local function NormalizeAngle(angle)
    return angle - TWO_PI * math.floor((angle + PI) / TWO_PI)
end

-- Calcula a menor diferença entre dois ângulos (target - current)
local function AngleDifference(target, current)
    local diff = target - current
    return NormalizeAngle(diff)
end


function MGDU:Print(msg, noPrefix) if noPrefix then print(msg) else print(self.colorPrefix .. " " .. msg) end end
function MGDU:Debug(msg) if self.debug then print(self.colorPrefix .. " |cffaaaaaa[Debug]|r " .. msg) end end
function MGDU:ExtractNameFromLink(itemLink) if not itemLink then return "item desconhecido" end local _, _, name = string.find(itemLink, "|h%[(.-)%]|h"); return name or "item desconhecido" end

function MGDU:CreatePreviewFrame()
    if MGDU.previewFrame then self:Debug("CreatePreviewFrame: Frame já existe."); return end
    self:Print("--- Criando PreviewFrame ---", true)

    MGDU.previewFrame = CreateFrame("Frame", "MGDU_PreviewFrame", UIParent)
    if not MGDU.previewFrame then self:Print("FALHA AO CRIAR MGDU.previewFrame!", true); return end
    MGDU.previewFrame:SetSize(320, 450)
    MGDU.previewFrame:SetPoint("CENTER", UIParent, "CENTER")
    MGDU.previewFrame:SetFrameStrata("DIALOG")
    MGDU.previewFrame:SetMovable(true)
    MGDU.previewFrame:EnableMouse(true)
    MGDU.previewFrame:RegisterForDrag("LeftButton")
    MGDU.previewFrame:SetScript("OnDragStart", function(self_drag) self_drag:StartMoving() end)
    MGDU.previewFrame:SetScript("OnDragStop", function(self_drag) self_drag:StopMovingOrSizing(); self_drag:SetUserPlaced(true) end) 
    MGDU.previewFrame:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    MGDU.previewFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    MGDU.previewFrame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    MGDU.previewFrame:Hide()

    local title = MGDU.previewFrame:CreateFontString("MGDU_PreviewFrameTitle", "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", MGDU.previewFrame, "TOP", 0, -14); title:SetText("Pré-Visualização de Item")

    local closeButton = CreateFrame("Button", "MGDU_PreviewFrameCloseButton", MGDU.previewFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", MGDU.previewFrame, "TOPRIGHT", -8, -10)
    closeButton:SetScript("OnClick", function() MGDU:ClearPreviewState(true) end)

    MGDU.previewModel = CreateFrame("DressUpModel", "MGDU_PreviewModel", MGDU.previewFrame)
    if not MGDU.previewModel then self:Print("FALHA AO CRIAR MGDU.previewModel!", true); MGDU.previewFrame:Hide(); return end
    MGDU.previewModel:SetPoint("TOPLEFT", MGDU.previewFrame, "TOPLEFT", 18, -38)
    MGDU.previewModel:SetPoint("BOTTOMRIGHT", MGDU.previewFrame, "BOTTOMRIGHT", -18, 45) 
    MGDU.previewModel:EnableMouse(true)
    MGDU.previewModel:RegisterForDrag("LeftButton") 
    MGDU.previewFrame:SetScript("OnMouseWheel", function(self_f, delta) if MGDU.previewModel then if delta > 0 then MGDU.previewModel:ZoomIn() else MGDU.previewModel:ZoomOut() end end end)
    self:Debug("CreatePreviewFrame: PreviewModel configurado.")

    -- ########## BOTÕES DE ROTAÇÃO (com lógica suave) ##########
    local rotationStep = math.rad(15) -- Quanto adicionar/subtrair ao target por clique

    local function InitiateRotation(direction)
        if MGDU.previewModel then
            local currentFacing = MGDU.previewModel:GetFacing()
            if currentFacing then
                -- Se já estiver rotacionando, usa o target atual como base, senão usa o current
                local baseFacing = MGDU.isRotating and MGDU.targetFacing or currentFacing
                -- Calcula novo target e normaliza para evitar valores muito grandes/pequenos
                MGDU.targetFacing = NormalizeAngle(baseFacing + (direction * rotationStep))
                MGDU.isRotating = true -- Inicia a animação no OnUpdate
                MGDU:Debug("Iniciando rotação suave. Target: " .. MGDU.targetFacing)
            else
                 MGDU:Debug("Não foi possível obter GetFacing para iniciar rotação.")
            end
        end
    end

    local rotateLeftButton = CreateFrame("Button", "MGDU_PreviewFrameRotateLeft", MGDU.previewFrame, "UIPanelButtonTemplate") 
    if rotateLeftButton then
        rotateLeftButton:SetSize(25, 25); rotateLeftButton:SetPoint("BOTTOMLEFT", MGDU.previewFrame, "BOTTOMLEFT", 15, 15); rotateLeftButton:SetText("<")
        rotateLeftButton:SetScript("OnClick", function() InitiateRotation(-1) end) -- -1 para esquerda
        self:Debug("CreatePreviewFrame: Botão RotateLeft criado.")
    else self:Print("Falha ao criar botão RotateLeft") end

    local rotateRightButton = CreateFrame("Button", "MGDU_PreviewFrameRotateRight", MGDU.previewFrame, "UIPanelButtonTemplate")
    if rotateRightButton then
        rotateRightButton:SetSize(25, 25); rotateRightButton:SetPoint("BOTTOMRIGHT", MGDU.previewFrame, "BOTTOMRIGHT", -15, 15); rotateRightButton:SetText(">")
        rotateRightButton:SetScript("OnClick", function() InitiateRotation(1) end) -- 1 para direita
        self:Debug("CreatePreviewFrame: Botão RotateRight criado.")
    else self:Print("Falha ao criar botão RotateRight") end
    -- #############################################

    self:Print("--- Criação do Frame Concluída ---", true)
end

function MGDU:AttemptToDressItem()
    -- (Esta função permanece a mesma da versão anterior 1.4.6)
    if not self.dressUpAttempt.link or not self.enabled then self.dressUpAttempt.link = nil; return end
    local itemLink = self.dressUpAttempt.link
    local itemName = self:ExtractNameFromLink(itemLink)
    self:Debug("AttemptToDressItem: Iniciando para (Custom Frame): " .. itemName)
    if not MGDU.previewFrame or not MGDU.previewModel then self:Print("CRÍTICO: PreviewFrame/Model não inicializado! Item: " .. itemName); self.dressUpAttempt.link = nil; return end
    if not MGDU.previewFrame:IsShown() then self:Debug("PreviewFrame não visível na tentativa final. Abortando."); self.dressUpAttempt.link = nil; return end
    self:Debug("Configurando unidade 'player' no PreviewModel customizado.")
    MGDU.previewModel:ClearModel()
    MGDU.previewModel:SetUnit("player")
    local success, err
    self:Debug("Tentando MGDU.previewModel:TryOn() com link: ".. itemLink)
    success, err = pcall(function() MGDU.previewModel:TryOn(itemLink) end)
    if not success or err then 
        self:Debug("TryOn falhou ou não existe (" .. tostring(err) .. "). Tentando MGDU.previewModel:SetHyperlink().")
        if type(MGDU.previewModel.SetHyperlink) == "function" then
            success, err = pcall(function() MGDU.previewModel:SetHyperlink(itemLink) end)
        else
            self:Debug("SetHyperlink também não existe como função.")
            success = false 
        end
    end
    if success then self:Debug("Chamada para vestir '" .. itemName .. "' bem-sucedida (sem erro LUA).")
    else self:Print("Erro LUA ou falha ao tentar vestir '" .. itemName .. "': " .. tostring(err)) end
    self.dressUpAttempt.link = nil 
end

function MGDU:PrepareDressUp(itemLink)
   -- (Esta função permanece a mesma da versão anterior 1.4.6)
    if not itemLink then self:Debug("PrepareDressUp: link nulo."); return false end
    if not string.match(itemLink, "^|c%x+|Hitem:") then self:Debug("PrepareDressUp: link inválido."); return false end
    if not MGDU.previewFrame then MGDU:CreatePreviewFrame() end 
    if not MGDU.previewFrame then self:Print("Falha crítica ao criar frame em PrepareDressUp."); return false end
    local itemName = self:ExtractNameFromLink(itemLink)
    if itemLink ~= MGDU.currentlyPreviewingLink or not MGDU.previewFrame:IsShown() then
        self:Print("Tentando pré-visualizar (Custom Frame): " .. itemName, true)
    end
    self:Debug("Preparando para vestir (Custom Frame): " .. itemName)
    if not MGDU.previewFrame:IsShown() then
        if MGDU.previewFrame:IsUserPlaced() then
             self:Debug("Mostrando frame que foi movido pelo usuário.")
        else
            self:Debug("Mostrando e recentralizando frame.")
            MGDU.previewFrame:ClearAllPoints()
            MGDU.previewFrame:SetPoint("CENTER", UIParent, "CENTER")
            MGDU.previewFrame:SetUserPlaced(false)
        end
        MGDU.previewFrame:Show()
        if not MGDU.previewFrame:IsShown() then self:Print("PreviewFrame não pôde ser mostrado."); return false end
    end
    self.dressUpAttempt.link = itemLink
    self.dressUpAttempt.frameDelay = self.dressUpAttempt.maxDelay
    self:Debug("Agendada tentativa de vestir '" .. itemName .. "' em " .. self.dressUpAttempt.maxDelay .. "f.")
    return true
end

function MGDU:IsControlKeyDown() 
    MGDU.isCtrlDown = IsControlKeyDown() 
    return MGDU.isCtrlDown
end

function MGDU:ProcessGossipWindow(forceProcess)
    -- (Esta função permanece a mesma da versão anterior 1.4.6)
    if not self.enabled then return end

    local itemLinkFoundInGossip = nil
    local foundInMouseOverOption = false
    local isGossipVisible = GossipFrame and GossipFrame:IsShown()

    if isGossipVisible then
        local numOptions = GetNumGossipOptions()
        for i = 1, numOptions do
            local button = _G["GossipTitleButton"..i]
            if button and button:IsShown() and button:IsMouseOver() then
                local buttonText = button:GetText()
                if not buttonText and button.text and type(button.text.GetText) == "function" then buttonText = button.text:GetText()
                elseif not buttonText and button.Text and type(button.Text.GetText) == "function" then buttonText = button.Text:GetText() end
                if buttonText and buttonText ~= "" then
                    local linkInOption = string.match(buttonText, "(|c%x+|Hitem:[^|]+|h[^|]+|h|r)")
                    if linkInOption then itemLinkFoundInGossip = linkInOption; foundInMouseOverOption = true; self:Debug("Link detectado na OPÇÃO " .. i .. " COM MOUSEOVER."); break end
                end
            end
        end
        if not itemLinkFoundInGossip then
            local gossipText = GetGossipText()
            if gossipText and gossipText ~= "" then
                itemLinkFoundInGossip = string.match(gossipText, "(|c%x+|Hitem:[^|]+|h[^|]+|h|r)")
                if itemLinkFoundInGossip then self:Debug("Link detectado no TEXTO PRINCIPAL.") end
            end
        end
        if not itemLinkFoundInGossip and not foundInMouseOverOption then
            local optionsTable = {GetGossipOptions()}
            if #optionsTable > 0 then
                for i = 1, #optionsTable, 2 do
                    local text = optionsTable[i]
                    if text and text ~= "" then
                        local tempLink = string.match(text, "(|c%x+|Hitem:[^|]+|h[^|]+|h|r)")
                        if tempLink then itemLinkFoundInGossip = tempLink; self:Debug("Link detectado como FALLBACK."); break end
                    end
                end
            end
        end
    end 

    if itemLinkFoundInGossip then
        if MGDU.isCtrlDown then
             if forceProcess or itemLinkFoundInGossip ~= MGDU.currentlyPreviewingLink or (MGDU.previewFrame and not MGDU.previewFrame:IsShown()) then
                MGDU.currentlyPreviewingLink = itemLinkFoundInGossip 
                self.lastItem = itemLinkFoundInGossip 
                if not self:PrepareDressUp(itemLinkFoundInGossip) then
                    MGDU.currentlyPreviewingLink = nil 
                end
            end
        end
    else
        if (MGDU.currentlyPreviewingLink or MGDU.dressUpAttempt.link) and not (MGDU.previewFrame and MGDU.previewFrame:IsUserPlaced()) then
            self:Debug("Nenhum link detectado e frame não movido. Limpando/escondendo.")
            MGDU:ClearPreviewState(true) 
        end
    end
end

function MGDU:ClearPreviewState(hideTheFrame)
   -- (Esta função permanece a mesma da versão anterior 1.4.6)
   local wasPreviewing = MGDU.currentlyPreviewingLink or MGDU.dressUpAttempt.link
    self:Debug("Limpando estado de preview. Esconder frame: " .. tostring(hideTheFrame))
    MGDU.currentlyPreviewingLink = nil
    self.dressUpAttempt.link = nil
    self.dressUpAttempt.frameDelay = 0
    MGDU.isRotating = false -- Para a animação de rotação se estiver ativa
    MGDU.targetFacing = nil
    if hideTheFrame and MGDU.previewFrame and MGDU.previewFrame:IsShown() then
        self:Debug("Escondendo PreviewFrame customizado.")
        MGDU.previewFrame:Hide()
        if MGDU.previewModel then MGDU.previewModel:ClearModel() end 
    elseif wasPreviewing and MGDU.previewFrame and not hideTheFrame then
         self:Debug("Limpando preview interno, mas mantendo frame visível (movido pelo usuário).")
         if MGDU.previewModel then MGDU.previewModel:ClearModel() end 
    end
end

-- NOVA função para lidar com a animação de rotação
function MGDU:OnUpdateRotation(elapsed)
    if not self.isRotating or not self.previewModel or not self.targetFacing then
        self.isRotating = false
        return
    end

    local currentFacing = self.previewModel:GetFacing()
    if not currentFacing then 
        self.isRotating = false 
        self:Debug("OnUpdateRotation: GetFacing() falhou.")
        return 
    end

    local diff = AngleDifference(self.targetFacing, currentFacing) 

    -- Define um limiar pequeno para parar (ex: 0.5 graus em radianos)
    local threshold = math.rad(0.5) 

    if math.abs(diff) < threshold then
        self:Debug("OnUpdateRotation: Rotação próxima o suficiente do alvo.")
        self.previewModel:SetFacing(self.targetFacing)
        self.isRotating = false
        self.targetFacing = nil
        return
    end

    local step = self.rotationSpeed * elapsed
    -- Garante que não ultrapasse o alvo neste passo
    if step > math.abs(diff) then
        step = math.abs(diff)
    end

    local direction = (diff > 0) and 1 or -1 -- 1 para direita (sentido horário), -1 para esquerda
    local newFacing = NormalizeAngle(currentFacing + (direction * step))

    -- self:Debug("Rot: Cur="..math.deg(currentFacing)..", Tgt="..math.deg(self.targetFacing)..", Diff="..math.deg(diff)..", Step="..math.deg(direction*step)..", New="..math.deg(newFacing)) -- Debug em Graus
    self.previewModel:SetFacing(newFacing)
end


onUpdateLoopFrame:SetScript("OnUpdate", function(self_updater, elapsed)
    if not MGDU.enabled then return end

    -- Processar animação de rotação PRIMEIRO
    MGDU:OnUpdateRotation(elapsed)

    -- Processar o delay para DressUpItem DEPOIS
    if MGDU.dressUpAttempt.link then
        if MGDU.dressUpAttempt.frameDelay > 0 then
            MGDU.dressUpAttempt.frameDelay = MGDU.dressUpAttempt.frameDelay - 1
        else
            if MGDU.dressUpAttempt.link then MGDU:AttemptToDressItem() end
        end
    end

    -- Lógica de interação com Gossip e Ctrl
    local ctrlDownNow = MGDU:IsControlKeyDown() 
    local gossipVisible = GossipFrame and GossipFrame:IsShown()

    if ctrlDownNow and gossipVisible then
        MGDU:ProcessGossipWindow(false)
    end

    -- Lógica de Fechamento Automático
    if not gossipVisible and MGDU.previewFrame and MGDU.previewFrame:IsShown() and not MGDU.previewFrame:IsUserPlaced() then
         self:Debug("Gossip fechado e frame não movido. Escondendo automaticamente.") -- Requer acesso a 'self' de MGDU, precisa ser MGDU:Debug
         MGDU:ClearPreviewState(true)
    end
end)

gameEventHandlerFrame:SetScript("OnEvent", function(self_event_handler_frame, event, ...)
    -- (Esta função permanece a mesma da versão anterior 1.4.6)
    if event == "ADDON_LOADED" then
        local addonArg = ...
        if addonArg == addonName then
            if MyGossipDressUpSettings then 
                MGDU.enabled = MyGossipDressUpSettings.enabled ~= nil and MyGossipDressUpSettings.enabled or true
                MGDU.debug = MyGossipDressUpSettings.debug or false
                MGDU.dressUpAttempt.maxDelay = MyGossipDressUpSettings.maxDelay or 3
            end
            MGDU:Print("ADDON_LOADED: Criando PreviewFrame...")
            MGDU:CreatePreviewFrame() 
            MGDU:Print("ADDON_LOADED: Criação Concluída.")
            MGDU:Print("Versão " .. MGDU.version .. " carregada. Delay: " .. MGDU.dressUpAttempt.maxDelay .. "f.")
            MGDU:Print("Segure CTRL e passe o mouse sobre um item no gossip para pré-visualizar.")
            SLASH_MGDRESSUP1 = "/mgdu"
            SLASH_MGDRESSUP2 = "/gossippreview"
            SlashCmdList["MGDRESSUP"] = function(msg) MGDU:ProcessSlashCommand(msg) end
        end
    elseif not MGDU.enabled then 
        return 
    elseif event == "GOSSIP_SHOW" then
        MGDU:Debug("Evento GOSSIP_SHOW recebido.")
        if MGDU:IsControlKeyDown() then
            MGDU:ProcessGossipWindow(true) 
        end
    elseif event == "GOSSIP_CLOSED" or event == "PLAYER_LEAVING_WORLD" then
        MGDU:Debug("Evento " .. event .. " recebido.")
        local shouldHide = true
        if event == "GOSSIP_CLOSED" and MGDU.previewFrame and MGDU.previewFrame:IsUserPlaced() then
            shouldHide = false
            MGDU:Debug("Gossip fechado, mas PreviewFrame foi movido. Mantendo visível.")
        end
        if shouldHide then
            MGDU:ClearPreviewState(true)
        end
    end
end)

function MGDU:SaveSettings()
    -- (Esta função permanece a mesma da versão anterior 1.4.6)
    MyGossipDressUpSettings = MyGossipDressUpSettings or {}
    MyGossipDressUpSettings.enabled = MGDU.enabled
    MyGossipDressUpSettings.debug = MGDU.debug
    MyGossipDressUpSettings.maxDelay = MGDU.dressUpAttempt.maxDelay
    self:Debug("Configurações salvas.")
end

function MGDU:ProcessSlashCommand(msg)
    -- (Esta função permanece a mesma da versão anterior 1.4.6)
    local cmd, arg1S = string.match(msg, "^(%S*)%s*(.*)$") 
    cmd = cmd and cmd:lower() or ""
    local arg1Num = tonumber(arg1S)

    if cmd == "toggle" or cmd == "" then
        self.enabled = not self.enabled
        self:Print(self.enabled and "Addon ativado." or "Addon desativado.")
        if not self.enabled then self:ClearPreviewState(true) end
    elseif cmd == "debug" then
        self.debug = not self.debug
        self:Print("Modo debug " .. (self.debug and "ativado." or "desativado."))
    elseif cmd == "last" then
        if self.lastItem then
            self:Print("Revestindo último item salvo: " .. self:ExtractNameFromLink(self.lastItem))
            MGDU.currentlyPreviewingLink = self.lastItem 
            self:PrepareDressUp(self.lastItem)
        else
            self:Print("Nenhum item foi salvo.")
        end
    elseif cmd == "clear" then
        self:Print("Limpando preview e fechando janela.")
        self:ClearPreviewState(true)
    elseif cmd == "delay" then
        if arg1Num and arg1Num >= 1 and arg1Num <= 10 then
            self.dressUpAttempt.maxDelay = arg1Num
            self:Print("Atraso de pré-visualização: " .. arg1Num .. "f.")
        else
            self:Print("Uso: /mgdu delay <1-10>. Atual: " .. self.dressUpAttempt.maxDelay .."f.")
        end
    elseif cmd == "resetframe" then
        if MGDU.previewFrame then
            MGDU.previewFrame:ClearAllPoints()
            MGDU.previewFrame:SetPoint("CENTER", UIParent, "CENTER")
            MGDU.previewFrame:SetUserPlaced(false) 
            self:Print("Posição da janela de preview resetada.")
            if not MGDU.previewFrame:IsShown() and (MGDU.currentlyPreviewingLink or MGDU.dressUpAttempt.link) then
                MGDU.previewFrame:Show() 
            end
        else
            self:Print("Janela de preview ainda não foi criada.")
        end
    elseif cmd == "testmodel" then
        self:Debug("Executando /mgdu testmodel...")
        if not MGDU.previewFrame then MGDU:CreatePreviewFrame() end
        if not MGDU.previewFrame then self:Print("Falha ao criar frame para teste."); return end
        if not MGDU.previewFrame:IsShown() then self:Print("Mostrando PreviewFrame customizado..."); MGDU.previewFrame:Show() end
        local tempFrameTest = CreateFrame("Frame") 
        local attemptsTest = 0
        tempFrameTest:SetScript("OnUpdate", function(s)
            attemptsTest = attemptsTest + 1
            if attemptsTest > 2 then 
                s:SetScript("OnUpdate", nil) 
                if MGDU.previewModel then
                    MGDU:Print("TESTMODEL: PreviewModel customizado encontrado.")
                    MGDU.previewModel:ClearModel(); MGDU.previewModel:SetUnit("player")
                    MGDU:Print("TESTMODEL: Modelo 'player' definido no PreviewModel customizado.")
                else
                    MGDU:Print("TESTMODEL: Falha ao encontrar/usar MGDU.previewModel no teste.")
                end
            end
        end)
    elseif cmd == "help" then
        self:Print("Comandos MyGossipDressUp:")
        self:Print("/mgdu toggle - Ativa/Desativa.")
        self:Print("/mgdu debug  - Ativa/Desativa msgs.")
        self:Print("/mgdu last   - Pré-visualiza último item.")
        self:Print("/mgdu clear  - Limpa e fecha janela.")
        self:Print("/mgdu delay N- Define atraso (1-10f). Atual: " .. self.dressUpAttempt.maxDelay)
        self:Print("/mgdu resetframe - Reseta posição janela.")
        self:Print("/mgdu testmodel - Testa modelo.")
        self:Print("/mgdu help   - Mostra esta ajuda.")
    else
        self:Print("Comando desconhecido: '"..msg .."'. Use /mgdu help.")
    end
    self:SaveSettings() 
end