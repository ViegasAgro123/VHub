--[[
    ============================================================================
    AOTR · Attack on Titan Revolution — Script Hub  ·  v1.0.0
    Interface em PT-BR. RightControl abre e fecha.

    Arquivo gerado por build/bundle.mjs — NÃO EDITE À MÃO.
    Edite os módulos em src/ e rode:  node build/bundle.mjs
    ============================================================================
--]]

-- ── Módulos ──────────────────────────────────────────────────────────────────
local MODULES = {}
local __cache = {}

local function __req(name)
    if __cache[name] ~= nil then return __cache[name] end
    local factory = MODULES[name]
    if not factory then error("[AOTR] módulo ausente: " .. tostring(name), 2) end
    local value = factory()
    __cache[name] = value == nil and true or value
    return value
end

-- ── core/game ─────────────────────────────────────────────────
MODULES["core/game"] = function()
local __src = [=[
--[[
    AOTR · Núcleo de Jogo
    Arquivo: src/core/game.lua

    NOMES INTERNOS — verificados contra duas fontes desobfuscadas (Tekkit Hub e
    Smooth Hub) e cruzados com as APIs oficiais da Roblox. Cada caminho aqui foi
    visto literalmente em pelo menos um script que funciona.

    A lição que moldou este arquivo: a versão anterior descobria a nuca por
    heurística de nome ("nape"/"nuca"/"weakpoint"). Isso NUNCA acharia o alvo
    real, porque o caminho é três níveis fundo e o nível do meio tem nome
    contraintuitivo:

        workspace.Titans.<Model>.Hitboxes.Hit.Nape
                                          ^^^ singular, não "Hits"

    Heurística parecia robusta e era pior que o caminho fixo: falhava em
    silêncio. Agora o caminho exato vem primeiro e a heurística é só reserva.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Game = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- LocalPlayer resolvido tardiamente: executores que injetam antes do DataModel
-- terminar de montar encontram Players.LocalPlayer == nil.
local _lp
local function getLocalPlayer()
    if _lp and _lp.Parent then return _lp end
    _lp = Players.LocalPlayer
    return _lp
end
Game.getLocalPlayer = getLocalPlayer

-- ── Identidade e lugares ─────────────────────────────────────────────────────
-- O AOTR NÃO é um lugar só. O universo 4658598196 tem 14 places distintos:
-- o lugar-raiz (vitrine pública), o lobby social onde ficam lojas e a entrada
-- das missões, e os campos de batalha onde os Titãs aparecem.
--
-- GUARD EM DUAS CAMADAS — e a razão de um teste só não bastar:
--
--   IDENTIDADE ("é o AOTR?")     -> game.GameId == 4658598196
--                                   Estável nos 14 lugares. Diz que estamos
--                                   no jogo certo, e só isso.
--
--   CAPACIDADE ("dá pra caçar?") -> workspace.Titans existe?
--                                   O GameId NÃO distingue lobby de campo.
--                                   Indexar workspace.Titans no lobby levanta
--                                   erro. É a existência da pasta que autoriza.
--
-- Um guard só de GameId parece mais elegante e é uma armadilha: ele passa nos
-- 14 lugares, inclusive nos 4 onde o combate não tem o que fazer.
Game.UNIVERSE_ID    = 4658598196
Game.ROOT_PLACE_ID  = 13379208636   -- lugar-raiz (vitrine), NÃO é o lobby
Game.LOBBY_PLACE_ID = 14916516914   -- Town Central: o lobby de verdade
Game.CREATOR_ID     = 17347863      -- grupo "AoTR [PI]"

-- Lugares conhecidos, agrupados por papel. Descobertos via
-- develop.roblox.com/v1/universes/4658598196/places e conferidos contra a
-- ALLOWED_PLACES de um script público — as duas fontes batem.
Game.PLACES = {
    -- Vitrine / raiz
    [13379208636] = "principal",

    -- Lobby social: lojas, comércio, treino. Sem Titãs.
    [14916516914] = "lobby",       -- Town Central
    [14932214603] = "lobby",       -- Trade Central
    [112374853034490] = "lobby",   -- Training Grounds
    [126678335159530] = "lobby",   -- Chapel

    -- Campos de batalha — aqui existem Titãs
    [13379349730] = "campo",       -- Shiganshina
    [13904204676] = "campo",       -- Outskirts
    [14012874501] = "campo",       -- Trost
    [14638336319] = "campo",       -- Forest
    [15030367419] = "campo",       -- Outside the Walls 1
    [15220308770] = "campo",       -- Utgard
    [15374465998] = "campo",       -- Outside the Walls 2
    [15824912319] = "campo",       -- Stohess
    [17688739434] = "campo",       -- Docks
}

-- Tipo do lugar atual: "principal" | "lobby" | "campo" | "desconhecido"
function Game.placeKind()
    return Game.PLACES[game.PlaceId] or "desconhecido"
end

-- Camada 1 — identidade. Estamos em algum lugar do AOTR?
function Game.isAOTR()
    if game.GameId == Game.UNIVERSE_ID then return true end
    -- Fallback: os dois remotes são a impressão digital que os scripts usam,
    -- e existem nos 14 lugares.
    return Game.getRemotes().ok
end

-- Camada 2 — capacidade. Aqui há Titãs para caçar?
-- Usa FindFirstChild, nunca indexação direta: no lobby a pasta não existe, e
-- `workspace.Titans` seria erro em vez de nil.
function Game.hasTitans()
    return Game.getTitanFolder() ~= nil
end

-- Podemos operar em modo combate? Junta as duas camadas.
function Game.canFight()
    return Game.hasTitans()
end

-- Aviso legível, com o motivo exato. nil quando não há nada a avisar.
function Game.placeAdvice()
    if Game.hasTitans() then return nil end

    local kind = Game.placeKind()
    if kind == "campo" then
        return "Campo de missão sem Titãs ativos. Aguarde a onda começar."
    end
    if kind == "lobby" or kind == "principal" then
        return "Você está no lobby. Aqui não há Titãs — entre numa missão para usar o combate."
    end
    if Game.isAOTR() then
        return "Este lugar do AOTR não tem Titãs. Entre numa missão."
    end
    return "Este não parece ser o AOTR. O script vai tentar mesmo assim."
end

-- ── Remotes ──────────────────────────────────────────────────────────────────
-- Superfície COMPLETA: dois objetos. Não existem RemoteEvents por ação.
-- Todo o jogo multiplexa sobre pares de verbos (namespace, ação, args...).

local remoteCache = { ok = false, GET = nil, POST = nil, at = 0 }

function Game.getRemotes()
    local now = os.clock()
    if remoteCache.ok and (now - remoteCache.at) < 30 then return remoteCache end

    local container = ReplicatedStorage:FindFirstChild("Assets")
    container = container and container:FindFirstChild("Remotes")

    if container then
        remoteCache.GET = container:FindFirstChild("GET")
        remoteCache.POST = container:FindFirstChild("POST")
        remoteCache.ok = (remoteCache.GET ~= nil and remoteCache.POST ~= nil)
        remoteCache.at = now
    end
    return remoteCache
end

-- Envia um POST. Verbos conhecidos: Attacks/Slash, Attacks/Slash_Escape,
-- Attacks/Reload. Nunca lança: um remote ausente não pode derrubar o loop.
--
-- Nota sobre o `...`: uma closure interna NÃO herda o vararg da função que a
-- contém — `function() r.POST:FireServer(ns, action, ...) end` é erro de
-- sintaxe. Por isso table.pack aqui e table.unpack lá dentro.
function Game.post(ns, action, ...)
    local r = Game.getRemotes()
    if not r.POST then return false end
    local args = table.pack(...)
    return (pcall(function()
        r.POST:FireServer(ns, action, table.unpack(args, 1, args.n))
    end))
end

-- Chama um GET e devolve o retorno. Verbos conhecidos: Hitboxes/Register,
-- Blades/Reload, Blades/Full_Reload, S_Skills/Usage, Family/Store, Data/Get,
-- Functions/Retry|Teleport|Quest, Spears/S_Fire.
function Game.get(ns, action, ...)
    local r = Game.getRemotes()
    if not r.GET then return nil end
    local args = table.pack(...)
    local ok, result = pcall(function()
        return r.GET:InvokeServer(ns, action, table.unpack(args, 1, args.n))
    end)
    return ok and result or nil
end

-- ── Titãs ────────────────────────────────────────────────────────────────────

function Game.getTitanFolder()
    return Workspace:FindFirstChild("Titans")
end

local function napeOf(model)
    -- Caminho exato, três níveis. Sem heurística.
    local hitboxes = model:FindFirstChild("Hitboxes")
    local hit = hitboxes and hitboxes:FindFirstChild("Hit")
    local nape = hit and hit:FindFirstChild("Nape")
    if nape and nape:IsA("BasePart") then return nape end
    return nil
end
Game.napeOf = napeOf

-- Outros alvos válidos: o script de referência troca a nuca por estes conforme
-- o que o Marker aponta. Útil para "Nape Multi".
function Game.hitParts(model)
    local hitboxes = model:FindFirstChild("Hitboxes")
    local hit = hitboxes and hitboxes:FindFirstChild("Hit")
    if not hit then return {} end

    local out = {}
    for _, name in ipairs({ "Nape", "LeftLeg", "RightLeg", "LeftArm", "RightArm", "Eyes" }) do
        local p = hit:FindFirstChild(name)
        if p and p:IsA("BasePart") then table.insert(out, { name = name, part = p }) end
    end
    return out
end

-- Classificação por NOME. Não existe tag no modelo: nem StringValue, nem
-- atributo, nem ValueObject. O nome é o único identificador de variante.
function Game.classify(model)
    local n = string.lower(model.Name)
    if string.find(n, "colossal", 1, true) then return "Colossal", true end
    if string.find(n, "attack", 1, true)   then return "Attack", true end
    if string.find(n, "armored", 1, true)  then return "Armored", true end
    if string.find(n, "female", 1, true)   then return "Female", true end
    if string.find(n, "beast", 1, true)    then return "Beast", true end
    return "Pure", false
end

local cache = { list = {}, at = 0 }
local TTL = 0.1

function Game.getTitans(force)
    local now = os.clock()
    if not force and (now - cache.at) < TTL and #cache.list > 0 then
        return cache.list
    end

    local folder = Game.getTitanFolder()
    if not folder then
        cache.list, cache.at = {}, now
        return cache.list
    end

    local lp = getLocalPlayer()
    local myChar = lp and lp.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position

    local list = {}
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") then
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local nape = napeOf(model)
                if nape then
                    local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
                    if root then
                        local kind, isBoss = Game.classify(model)
                        table.insert(list, {
                            model = model,
                            humanoid = hum,
                            nape = nape,
                            root = root,
                            kind = kind,
                            isBoss = isBoss,
                            dist = myPos and (root.Position - myPos).Magnitude or math.huge,
                            hp = hum.Health,
                            maxHp = hum.MaxHealth,
                            name = model.Name,
                        })
                    end
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.dist < b.dist end)
    cache.list, cache.at = list, now
    return list
end

function Game.getNearestTitan()
    return Game.getTitans()[1]
end

-- ── Estado do jogador ────────────────────────────────────────────────────────
-- Tudo aqui é atributo. Não existe leaderstats neste jogo.

function Game.getCharacter() local lp = getLocalPlayer(); return lp and lp.Character end
function Game.getRoot()
    local c = Game.getCharacter()
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end
function Game.getHumanoid()
    local c = Game.getCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- "Gás" NÃO existe como valor no cliente. O que existe é Refills: uma contagem
-- de cargas de reabastecimento. Qualquer script que escreva num campo Gas/Fuel
-- está escrevendo no vazio.
function Game.getRefills()
    local lp = getLocalPlayer()
    return lp and lp:GetAttribute("Refills") or nil
end

function Game.getLevel()
    local lp = getLocalPlayer()
    return lp and lp:GetAttribute("Level") or nil
end

function Game.getPrestige()
    local lp = getLocalPlayer()
    return lp and lp:GetAttribute("Prestige") or nil
end

function Game.getSpears()
    local c = Game.getCharacter()
    return c and c:GetAttribute("Spears") or nil
end

-- Durabilidade da lâmina é o atributo booleano `Broken` na parte da lâmina.
function Game.getBlade()
    local c = Game.getCharacter()
    if not c then return nil end
    local rig = c:FindFirstChild("Rig_" .. (getLocalPlayer().Name))
    if not rig then
        -- fallback: qualquer filho que comece com Rig_
        for _, d in ipairs(c:GetChildren()) do
            if string.sub(d.Name, 1, 4) == "Rig_" then rig = d break end
        end
    end
    local hand = rig and rig:FindFirstChild("LeftHand")
    return hand and hand:FindFirstChild("Blade_1") or nil
end

function Game.isBladeBroken()
    local b = Game.getBlade()
    return b and b:GetAttribute("Broken") or false
end

-- Estação física de reabastecimento. Usada como argumento dos remotes de
-- reload e como alvo do TP-To-Refill.
function Game.getRefillStation()
    local unclimbable = Workspace:FindFirstChild("Unclimbable")
    local reloads = unclimbable and unclimbable:FindFirstChild("Reloads")
    local tanks = reloads and reloads:FindFirstChild("GasTanks")
    return tanks and tanks:FindFirstChild("Refill") or nil
end

-- ── Bandeiras de anti-cheat ──────────────────────────────────────────────────
-- A validação é server-side, mas o resultado replica de volta para o cliente.
-- Ou seja: dá para saber se você foi marcado, e é isso que permite que um
-- script pare antes de piorar.

function Game.isFlagged()
    local lp = getLocalPlayer()
    if not lp then return false, false end
    local exploiter = lp:GetAttribute("Exploiter")
    local blacklisted = lp:GetAttribute("Blacklisted")
    return exploiter == true, blacklisted == true
end

-- ── Diagnóstico ──────────────────────────────────────────────────────────────

function Game.diagnose()
    local titans = Game.getTitans(true)
    local r = Game.getRemotes()
    local flagged, blacklisted = Game.isFlagged()
    local folder = Game.getTitanFolder()

    local report = {
        placeId = game.PlaceId,
        placeKind = Game.placeKind(),
        gameId = game.GameId,
        isAOTR = Game.isAOTR(),
        hasTitanFolder = folder ~= nil,
        remotesFound = r.ok,
        titanCount = #titans,
        sampleTitan = nil,
        sampleNape = nil,
        sampleKind = nil,
        sampleParts = nil,
        refills = Game.getRefills(),
        level = Game.getLevel(),
        prestige = Game.getPrestige(),
        spears = Game.getSpears(),
        bladeBroken = Game.isBladeBroken(),
        refillStation = Game.getRefillStation() ~= nil,
        flagged = flagged,
        blacklisted = blacklisted,
    }

    if titans[1] then
        local t = titans[1]
        report.sampleTitan = t.name
        report.sampleNape = t.nape and t.nape.Name or nil
        report.sampleKind = t.kind
        local parts = {}
        local hitboxes = t.model:FindFirstChild("Hitboxes")
        local hit = hitboxes and hitboxes:FindFirstChild("Hit")
        if hit then
            for _, d in ipairs(hit:GetChildren()) do
                if #parts < 10 then table.insert(parts, d.Name) end
            end
        end
        report.sampleParts = parts
    end

    return report
end

return Game

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar core/game")
return __chunk(__req)
end

-- ── core/layout ───────────────────────────────────────────────
MODULES["core/layout"] = function()
local __src = [=[
--[[
    VHub · Layout
    Arquivo: src/core/layout.lua

    O Roblox não tem `grid-template-columns: repeat(auto-fill, minmax(...))`.
    O UIGridLayout exige CellSize fixo — e foi exatamente por isso que os cinco
    cartões da Home ficaram maiores que o container e se sobrepuseram.

    Este módulo reproduz o comportamento do CSS do AirFlow:

        repeat(auto-fill, minmax(196px, 1fr))
        gap: 16px

    Traduzindo: dado o espaço disponível, quantas colunas de no mínimo N cabem?
    O resto do espaço é dividido igualmente entre elas. Se o container muda de
    largura, tudo se recalcula — em vez de estourar.

    Uso:
        Layout.autoGrid(container, { minCell = 140, cellHeight = 74, gap = 8 })
        -- depois de adicionar os filhos, chame :refresh()
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Layout = {}

-- ── Utilitário ───────────────────────────────────────────────────────────────

-- Quantas colunas de largura `minCell` cabem em `total`, com `gap` entre elas.
-- Devolve colunas e a largura exata de cada uma, já dividindo a sobra.
--
-- A conta: n colunas ocupam n*cel + (n-1)*gap. Resolvendo para n:
--   n = floor((total + gap) / (minCell + gap))
-- E a largura de cada uma vira (total - (n-1)*gap) / n, que é o `1fr` do CSS.
local function fit(total, minCell, gap)
    if total <= 0 or minCell <= 0 then return 1, minCell end

    local n = math.floor((total + gap) / (minCell + gap))
    n = math.max(1, n)

    local cell = math.floor((total - (n - 1) * gap) / n)
    return n, cell
end
Layout.fit = fit

-- ── Grade automática ─────────────────────────────────────────────────────────

-- Cria um Frame com UIGridLayout que se comporta como o auto-fill do CSS.
--
-- opts:
--   parent     : onde montar
--   minCell    : largura mínima de cada célula (padrão 140)
--   cellHeight : altura de cada célula
--   gap        : espaço entre células
--   order      : LayoutOrder
--
-- Devolve { instance, grid, refresh(), setCells() }
function Layout.autoGrid(opts)
    local minCell = opts.minCell or 140
    local gap = opts.gap or 8
    local cellHeight = opts.cellHeight or 74

    local container = Instance.new("Frame")
    container.Name = opts.name or "AutoGrid"
    container.Size = UDim2.new(1, 0, 0, cellHeight)
    container.BackgroundTransparency = 1
    container.LayoutOrder = opts.order or 0
    container.Parent = opts.parent

    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, minCell, 0, cellHeight)
    grid.CellPadding = UDim2.new(0, gap, 0, gap)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
    grid.Parent = container

    local lastWidth, lastCount = -1, -1

    local function countCells()
        local n = 0
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("GuiObject") and child.Visible then n = n + 1 end
        end
        return n
    end

    -- Recalcula colunas, largura e altura. Idempotente: se nada mudou, sai.
    -- A altura é o ponto crítico: com UIGridLayout a grade quebra linha, mas o
    -- Frame não cresce sozinho — era isso que fazia os cartões vazarem por cima
    -- da seção seguinte.
    local function refresh()
        local total = container.AbsoluteSize.X
        local cells = countCells()
        if total <= 0 or (total == lastWidth and cells == lastCount) then return end
        lastWidth, lastCount = total, cells

        local cols, cell = fit(total, minCell, gap)
        grid.CellSize = UDim2.new(0, cell, 0, cellHeight)

        local rows = math.max(1, math.ceil(cells / cols))
        local height = rows * cellHeight + (rows - 1) * gap
        if math.abs(container.Size.Y.Offset - height) >= 1 then
            container.Size = UDim2.new(1, 0, 0, height)
        end
    end

    container:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)

    -- Recalcula também quando um filho entra, porque a primeira medição pode
    -- ter acontecido antes do container existir de fato.
    container.ChildAdded:Connect(function()
        task.defer(refresh)
    end)

    task.defer(refresh)

    return {
        instance = container,
        grid = grid,
        refresh = refresh,
        setCells = function(n, h)
            if n then minCell = n end
            if h then cellHeight = h; grid.CellSize = UDim2.new(0, grid.CellSize.X.Offset, 0, h) end
            lastWidth = -1
            refresh()
        end,
    }
end

-- ── Lista vertical ───────────────────────────────────────────────────────────

-- Lista empilhada com espaçamento consistente e altura automática.
function Layout.list(parent, padding, name)
    local f = Instance.new("Frame")
    f.Name = name or "List"
    f.Size = UDim2.new(1, 0, 0, 0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.BackgroundTransparency = 1
    f.Parent = parent

    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, padding or 3)
    l.Parent = f

    return f
end

-- ── Barra de rolagem ─────────────────────────────────────────────────────────

function Layout.scroll(parent, padH, padV)
    local s = Instance.new("ScrollingFrame")
    s.Name = "Scroll"
    s.Size = UDim2.fromScale(1, 1)
    s.BackgroundTransparency = 1
    s.BorderSizePixel = 0
    s.ScrollBarThickness = 5
    s.ScrollBarImageColor3 = Color3.fromRGB(70, 72, 78)
    s.ScrollBarImageTransparency = 0.3
    s.CanvasSize = UDim2.new()
    s.AutomaticCanvasSize = Enum.AutomaticSize.Y
    s.ScrollingDirection = Enum.ScrollingDirection.Y
    s.Parent = parent

    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, padV or 14)
    p.PaddingBottom = UDim.new(0, padV or 14)
    p.PaddingLeft = UDim.new(0, padH or 16)
    p.PaddingRight = UDim.new(0, padH or 16)
    p.Parent = s

    return s
end

-- ── Divisão em colunas iguais ────────────────────────────────────────────────
-- Para grades de largura fixa conhecida (2 ou 3 colunas), onde auto-fill não é
-- o comportamento desejado.

function Layout.columns(parent, count, gap, cellHeight, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, cellHeight)
    f.BackgroundTransparency = 1
    f.LayoutOrder = order or 0
    f.Parent = parent

    local g = Instance.new("UIGridLayout")
    local width = math.floor((1 / count) * 1000) / 10   -- escala em %
    g.CellSize = UDim2.new(width / 100, -gap * (count - 1) / count, 0, cellHeight)
    g.CellPadding = UDim2.new(0, gap, 0, gap)
    g.SortOrder = Enum.SortOrder.LayoutOrder
    g.Parent = f

    return f, g
end

return Layout

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar core/layout")
return __chunk(__req)
end

-- ── core/state ────────────────────────────────────────────────
MODULES["core/state"] = function()
local __src = [=[
--[[
    VHub · Barramento de Estado
    Arquivo: src/core/state.lua

    Cada feature declara seu estado aqui. A UI lê e escreve só neste objeto;
    nenhuma feature conhece a UI, nenhuma UI conhece a implementação de uma
    feature. É o que permite ligar e desligar tudo sem dependência circular.

    `flags` são booleanos (ligado/desligado), `config` são parâmetros.
    Salvar e carregar mexe só nesses dois.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local State = {}

-- ── Flags ────────────────────────────────────────────────────────────────────
State.flags = {
    -- ── Missões · Titãs
    autoKill        = false,   -- mata Titãs automaticamente
    killNape        = true,    -- mira a nuca (crítico)
    autoReload      = false,   -- recarrega lâminas quebradas
    autoEscape      = false,   -- escapa de agarrões
    autoTPToTitan   = false,   -- teleporta ao Titã mais próximo

    -- ── Missões · Movimento
    safeSpot        = false,   -- recua quando um Titã chega perto
    tpObjective     = false,   -- teleporta ao objetivo

    -- ── Missões · Nuca
    napeExpander    = false,
    showNape        = false,   -- deixa a nuca visível

    -- ── Missões · Pós-missão
    autoRetry       = false,
    autoReturnLobby = false,
    openFreeChest   = false,
    openPremiumChest= false,   -- gasta recurso: nunca liga sozinho
    rejoinOnTeleport= false,

    -- ── Lobby · Missões
    autoStart       = false,
    preferBoosted   = true,

    -- ── Lobby · Melhorias
    autoUpgrade     = false,
    autoSkills      = false,

    -- ── Segurança
    safeFarm        = true,    -- trava anti-shadow-ban

    -- ── Visual
    esp             = false,
    espBox          = true,
    espLine         = true,
    espText         = true,
    espHealth       = true,
    espNape         = true,
    espBossOnly     = false,

    -- ── Sistema
    antiAfk         = true,
    watermark       = true,
    notifications   = true,
}

-- ── Config ───────────────────────────────────────────────────────────────────
State.config = {
    -- Combate
    killRange       = 25,
    strikeDelay     = 0.12,
    tpRange         = 120,
    tpOffset        = 4,
    tpCooldown      = 0.4,

    -- Magnitude declarada em Hitboxes/Register.
    -- 12 é o comprimento aproximado da lâmina. Fontes usam 143+ e até 215-230,
    -- o que é fisicamente impossível e o sinal mais fácil de auditar.
    hitMagnitude    = 12,
    hitOffset       = 0,

    -- Nuca (tamanho de fábrica: Vector3.new(15, 9, 11))
    napeScale       = 1.5,
    napeTransparency= 0.35,

    -- Local seguro
    safeRange       = 40,
    safeDistance    = 30,

    -- Anti-shadow-ban
    safeTime        = 32,

    -- Lobby · missão
    missionType     = "Missions",
    mapName         = "Shiganshina",
    difficulty      = "Normal",
    objective       = "Skirmish",
    raid            = "Attack Titan",
    modifiers       = {},

    -- Lobby · habilidades
    skillLeft       = "Regen VI",
    skillMiddle     = "Damage V",
    skillRight      = "Tank VIII",

    -- Visual
    espMaxDist      = 900,
    espColor        = "Vermelho",
    espThickness    = 1.4,
}

-- ── Cores do ESP ─────────────────────────────────────────────────────────────
State.ESP_COLORS = {
    ["Vermelho"] = Color3.fromRGB(224, 45, 45),
    ["Branco"]   = Color3.fromRGB(242, 243, 247),
    ["Verde"]    = Color3.fromRGB(98, 194, 142),
    ["Azul"]     = Color3.fromRGB(110, 152, 222),
    ["Amarelo"]  = Color3.fromRGB(230, 172, 76),
    ["Rosa"]     = Color3.fromRGB(232, 122, 182),
    ["Ciano"]    = Color3.fromRGB(92, 202, 212),
}

function State.espColor()
    return State.ESP_COLORS[State.config.espColor] or State.ESP_COLORS["Vermelho"]
end

-- ── Observadores ─────────────────────────────────────────────────────────────

local watchers = {}

function State.on(flag, fn)
    watchers[flag] = watchers[flag] or {}
    table.insert(watchers[flag], fn)
    fn(State.flags[flag])
end

function State.set(flag, value)
    if State.flags[flag] == value then return end
    State.flags[flag] = value
    for _, fn in ipairs(watchers[flag] or {}) do
        local ok, err = pcall(fn, value)
        if not ok then
            warn(("[VHub] observador de '%s' falhou: %s"):format(flag, tostring(err)))
        end
    end
end

function State.toggle(flag)
    State.set(flag, not State.flags[flag])
end

function State.get(flag)
    return State.flags[flag]
end

-- Quantos itens estão ligados, dentro de um grupo de flags. A UI usa para o
-- contador de cada seção.
function State.countActive(flags)
    local n = 0
    for _, f in ipairs(flags) do
        if State.flags[f] then n = n + 1 end
    end
    return n
end

-- ── Persistência ─────────────────────────────────────────────────────────────

local CONFIG_PATH = "vhub_config.json"

function State.save()
    local ok = pcall(function()
        if not writefile then return end
        local payload = {
            flags = State.flags,
            config = State.config,
        }
        writefile(CONFIG_PATH, game:GetService("HttpService"):JSONEncode(payload))
    end)
    return ok
end

function State.load()
    local ok, data = pcall(function()
        if not (isfile and isfile(CONFIG_PATH)) then return nil end
        return game:GetService("HttpService"):JSONDecode(readfile(CONFIG_PATH))
    end)
    if not ok or type(data) ~= "table" then return false end

    for k, v in pairs(data.flags or {}) do
        if State.flags[k] ~= nil and type(v) == "boolean" then
            State.flags[k] = v
        end
    end
    for k, v in pairs(data.config or {}) do
        if State.config[k] ~= nil and type(v) == type(State.config[k]) then
            State.config[k] = v
        end
    end
    return true
end

return State

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar core/state")
return __chunk(__req)
end

-- ── core/stats ────────────────────────────────────────────────
MODULES["core/stats"] = function()
local __src = [=[
--[[
    VHub · Estatísticas
    Arquivo: src/core/stats.lua

    Fornece os números que a Home mostra: jogadores, amigos no servidor, tempo
    de sessão, FPS e ping.

    MÉTODOS — verificados contra fontes reais, não deduzidos:

      Ping  : Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
              É a leitura padrão e funciona em executor.

      FPS   : contagem de frames sobre o tempo decorrido, numa janela de 0.5s.
              Mais fiel que inverter 1/dt, que oscila demais para exibir.
              Stats.PerformanceStats NÃO é usado — é instável entre executores.

      Sessão: os.time() no carregamento, diferença a cada leitura.

      Jogadores no servidor: #Players:GetPlayers()
      Jogadores na experiência: requer chamada HTTP à API pública da Roblox.
              Nem todo executor libera request(), então o valor é opcional —
              quando indisponível mostramos apenas o do servidor.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Stats = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local _LP_cache
local function LP()
    if _LP_cache and _LP_cache.Parent then return _LP_cache end
    _LP_cache = Players.LocalPlayer
    return _LP_cache
end

-- ── Tempo de sessão ──────────────────────────────────────────────────────────

local SESSION_START = os.time()

function Stats.sessionSeconds()
    return os.time() - SESSION_START
end

-- Formata como "2h 14m" ou "14m 03s".
function Stats.sessionText()
    local s = Stats.sessionSeconds()
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    if h > 0 then return ("%dh %02dm"):format(h, m) end
    return ("%dm %02ds"):format(m, s % 60)
end

-- ── FPS ──────────────────────────────────────────────────────────────────────
-- Conta frames numa janela deslizante. Atualizar a cada 0.5s evita o número
-- piscando entre 58 e 62 sem parar.

local fps = 60
local frameCount = 0
local windowStart = os.clock()

task.spawn(function()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local elapsed = os.clock() - windowStart
        if elapsed >= 0.5 then
            fps = math.floor(frameCount / elapsed + 0.5)
            frameCount = 0
            windowStart = os.clock()
        end
        -- A conexão fica viva enquanto o script rodar; nada a desconectar.
    end)
end)

function Stats.fps()
    return fps
end

-- ── Ping ─────────────────────────────────────────────────────────────────────

function Stats.ping()
    local ok, value = pcall(function()
        local stats = game:GetService("Stats")
        local item = stats.Network.ServerStatsItem["Data Ping"]
        return item:GetValue()
    end)
    if ok and type(value) == "number" then
        return math.floor(value + 0.5)
    end
    return nil
end

-- ── Jogadores ────────────────────────────────────────────────────────────────

-- No servidor atual — sempre disponível, é local.
function Stats.serverPlayers()
    return #Players:GetPlayers()
end

function Stats.maxPlayers()
    return Players.MaxPlayers
end

-- ── Amigos no servidor ───────────────────────────────────────────────────────
-- IsFriendsWith é uma chamada de rede; fazer para 30 jogadores a cada frame
-- seria absurdo. Cacheamos por 20 segundos.

local friendsCache = { list = {}, at = 0 }

function Stats.friendsHere(force)
    local now = os.clock()
    if not force and (now - friendsCache.at) < 20 then
        return friendsCache.list
    end

    local found = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            -- userId ou Player: a API aceita ambos nas versões atuais.
            local ok, isFriend = pcall(function()
                return LP():IsFriendsWith(p.UserId)
            end)
            if ok and isFriend then
                table.insert(found, p)
            end
        end
    end

    friendsCache.list = found
    friendsCache.at = now
    return found
end

-- ── Jogadores na experiência (opcional) ──────────────────────────────────────
-- Requer HTTP. Nem todo executor libera, então falha em silêncio e a UI
-- simplesmente não mostra o campo.

local UNIVERSE_ID = 4658598196
local universeCache = { count = nil, max = nil, at = 0 }

function Stats.universePlayers()
    local now = os.clock()
    if (now - universeCache.at) < 60 then
        return universeCache.count, universeCache.max
    end

    local req = request or http_request or (syn and syn.request)
    if not req then return nil, nil end

    universeCache.at = now

    task.spawn(function()
        local ok, result = pcall(function()
            local url = ("https://games.roblox.com/v1/games?universeIds=%d"):format(UNIVERSE_ID)
            local res = req({ Url = url, Method = "GET" })
            if not res or not res.Body then return nil end
            local data = HttpService:JSONDecode(res.Body)
            local entry = data and data.data and data.data[1]
            if entry then
                return entry.playing, entry.maxPlayers
            end
            return nil
        end)
        if ok and result then
            universeCache.count = result
        end
    end)

    return universeCache.count, universeCache.max
end

-- ── Jogador local ────────────────────────────────────────────────────────────

function Stats.playerInfo()
    local lp = LocalPlayer
    if not lp then return nil end

    local ok, thumb = pcall(function()
        return Players:GetUserThumbnailAsync(
            lp.UserId,
            Enum.ThumbnailType.HeadShot,
            Enum.ThumbnailSize.Size150x150
        )
    end)

    return {
        name = lp.Name,
        display = lp.DisplayName,
        userId = lp.UserId,
        avatar = ok and thumb or nil,
        accountAge = lp.AccountAge,
    }
end

-- ── Instantâneo completo ─────────────────────────────────────────────────────
-- Uma leitura só, para a Home não chamar cinco funções por frame.

function Stats.snapshot()
    local friends = Stats.friendsHere()
    local uniCount = Stats.universePlayers()

    return {
        serverPlayers = Stats.serverPlayers(),
        maxPlayers = Stats.maxPlayers(),
        friends = #friends,
        friendsList = friends,
        session = Stats.sessionText(),
        sessionSec = Stats.sessionSeconds(),
        fps = Stats.fps(),
        ping = Stats.ping(),
        universe = uniCount,
    }
end

return Stats

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar core/stats")
return __chunk(__req)
end

-- ── core/theme ────────────────────────────────────────────────
MODULES["core/theme"] = function()
local __src = [=[
--[[
    VHub · Núcleo de Tema
    Arquivo: src/core/theme.lua

    Identidade: preto e vermelho, com o vermelho em GRADIENTE.
    O logo do VHub (preto, branco e vermelho) define a paleta — a interface
    inteira é construída para parecer parte da mesma peça.

    Como funciona a escala de elevação: cada superfície é uma mistura do preto
    com o cinza, em passos pequenos e regulares. É o degrau entre um painel e
    outro que cria profundidade, não a cor em si. Sem isso a janela achata.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Theme = {}

-- ── Âncoras ──────────────────────────────────────────────────────────────────
-- Tinta  : preto de trabalho. Não é #000 — preto absoluto não deixa espaço
--          para sombra abaixo e a interface perde relevo.
-- Brasa  : o vermelho da marca. 0xE0202 0 é o tom exato amostrado do logo.
--          D7263D é mais quente; E02D2D é o que aparece na arte.
-- Cinza  : neutro levemente quente, para não brigar com o vermelho.
local TINTA = Color3.fromRGB(8, 8, 10)
local BRASA = Color3.fromRGB(224, 45, 45)
local CINZA = Color3.fromRGB(148, 150, 158)

local function mix(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

local function lighten(c, t) return mix(c, Color3.new(1, 1, 1), t) end
local function darken(c, t) return mix(c, Color3.new(0, 0, 0), t) end

-- ── Superfícies ──────────────────────────────────────────────────────────────
Theme.color = {
    void       = TINTA,
    base       = mix(TINTA, CINZA, 0.055),
    surface    = mix(TINTA, CINZA, 0.085),
    surfaceHi  = mix(TINTA, CINZA, 0.120),
    surfaceTop = mix(TINTA, CINZA, 0.150),
    card       = mix(TINTA, CINZA, 0.100),

    line       = mix(TINTA, CINZA, 0.170),
    lineSoft   = mix(TINTA, CINZA, 0.105),
    lineHot    = mix(BRASA, TINTA, 0.40),

    text       = Color3.fromRGB(242, 243, 247),
    textDim    = mix(CINZA, TINTA, 0.18),
    textMute   = mix(CINZA, TINTA, 0.50),

    accent     = BRASA,
    accentHi   = lighten(BRASA, 0.30),
    accentLo   = darken(BRASA, 0.36),
    accentDeep = darken(BRASA, 0.62),
    accentGhost= mix(BRASA, TINTA, 0.88),

    on         = Color3.fromRGB(200, 68, 80),
    off        = mix(TINTA, CINZA, 0.22),
    warn       = Color3.fromRGB(230, 172, 76),
    danger     = Color3.fromRGB(238, 62, 62),
    ok         = Color3.fromRGB(98, 194, 142),
    info       = Color3.fromRGB(110, 152, 222),
}

-- ── Gradiente ────────────────────────────────────────────────────────────────
-- LIMITE: ColorSequence e NumberSequence aceitam NO MÁXIMO 20 keypoints.
-- Com 21 o construtor levanta "table is too long" e derruba o script antes da
-- UI montar — janela branca e nada funciona. Já aconteceu uma vez.
Theme.SEQUENCE_LIMIT = 20

-- Aplica um gradiente de cor a um Frame.
--   stops  : tabela de {posicao, Color3}
--   rotacao: 90 = topo->base, 0 = esquerda->direita
function Theme.gradient(frame, stops, rotacao)
    local g = Instance.new("UIGradient")
    g.Rotation = rotacao or 90

    local seq = {}
    local n = math.min(#stops, Theme.SEQUENCE_LIMIT)
    for i = 1, n do
        local s = stops[i]
        table.insert(seq, ColorSequenceKeypoint.new(s[1], s[2]))
    end
    g.Color = ColorSequence.new(seq)
    g.Parent = frame
    return g
end

-- Gradiente de transparência, útil para fade de bordas.
function Theme.fade(frame, rotacao, alphaInicio, alphaFim)
    local g = Instance.new("UIGradient")
    g.Rotation = rotacao or 90
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, alphaInicio or 0),
        NumberSequenceKeypoint.new(1, alphaFim or 1),
    })
    g.Parent = frame
    return g
end

-- Os dois gradientes da identidade, prontos.

-- Escuro, para corpos de painel. Quase imperceptível — é textura, não enfeite.
function Theme.gradientBase(frame)
    return Theme.gradient(frame, {
        { 0.0, mix(TINTA, CINZA, 0.085) },
        { 0.5, mix(TINTA, CINZA, 0.055) },
        { 1.0, darken(TINTA, 0.30) },
    })
end

-- Vermelho, para a marca e os elementos de destaque.
function Theme.gradientBrand(frame)
    return Theme.gradient(frame, {
        { 0.0, lighten(BRASA, 0.14) },
        { 0.5, BRASA },
        { 1.0, darken(BRASA, 0.30) },
    })
end

-- Brilho vermelho que some para o escuro: usado atrás do logo e no cabeçalho.
function Theme.gradientGlow(frame)
    return Theme.gradient(frame, {
        { 0.0, mix(BRASA, TINTA, 0.55) },
        { 0.6, mix(BRASA, TINTA, 0.88) },
        { 1.0, TINTA },
    })
end

-- ── Tipografia ───────────────────────────────────────────────────────────────
-- Tamanhos levemente maiores que a primeira versão: a janela cresceu, e texto
-- apertado em janela grande lê como descuido.
Theme.font = {
    regular = Enum.Font.Gotham,
    medium  = Enum.Font.GothamMedium,
    bold    = Enum.Font.GothamBold,
    black   = Enum.Font.GothamBlack,
    mono    = Enum.Font.Code,
}

Theme.text = {
    heroName = 26,   -- nome do usuário na Home
    heroSub  = 13,   -- subtítulo da Home
    title    = 16,   -- nome da janela
    section  = 13,   -- cabeçalho de grupo
    label    = 14,   -- rótulo de toggle
    sub      = 12,   -- descrição
    tiny     = 11,   -- rodapé
    stat     = 17,   -- número grande de estatística
    statLbl  = 11,   -- rótulo sob o número
    value    = 13,
}

-- ── Métrica ──────────────────────────────────────────────────────────────────
-- Janela maior, conforme pedido. 640x460 cabe em 1080p com folga e acomoda a
-- Home com dashboard sem rolagem excessiva.
Theme.metric = {
    pad      = 14,
    padSm    = 8,
    radius   = 9,
    radiusSm = 6,
    rowH     = 38,
    headH    = 58,
    stroke   = 1,
    scrollW  = 5,
    winW     = 640,
    winH     = 460,
    sidebarW = 148,
    statCardH = 74,
    avatar   = 64,
}

-- ── Animação ─────────────────────────────────────────────────────────────────
Theme.ease = {
    out   = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    inOut = TweenInfo.new(0.30, Enum.EasingStyle.Quad,  Enum.EasingDirection.InOut),
    fast  = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
    pop   = TweenInfo.new(0.38, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
    slow  = TweenInfo.new(0.55, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
}

-- ── Helpers ──────────────────────────────────────────────────────────────────

function Theme.stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.color.line
    s.Thickness = thickness or Theme.metric.stroke
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

function Theme.corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or Theme.metric.radius)
    c.Parent = parent
    return c
end

function Theme.pad(parent, all, h, v)
    local p = Instance.new("UIPadding")
    local a = all or Theme.metric.pad
    p.PaddingTop = UDim.new(0, v or a)
    p.PaddingBottom = UDim.new(0, v or a)
    p.PaddingLeft = UDim.new(0, h or a)
    p.PaddingRight = UDim.new(0, h or a)
    p.Parent = parent
    return p
end

-- Cor do texto por faixa de valor. Usada nas estatísticas da Home.
function Theme.healthColor(ratio)
    if ratio > 0.6 then return Theme.color.ok end
    if ratio > 0.3 then return Theme.color.warn end
    return Theme.color.danger
end

return Theme

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar core/theme")
return __chunk(__req)
end

-- ── core/util ─────────────────────────────────────────────────
MODULES["core/util"] = function()
local __src = [=[
--[[
    AOTR · Utilitários
    Arquivo: src/core/util.lua
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Util = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local _LP_cache
local function LP()
    if _LP_cache and _LP_cache.Parent then return _LP_cache end
    _LP_cache = Players.LocalPlayer
    return _LP_cache
end

-- ── Matemática ───────────────────────────────────────────────────────────────

function Util.dist(a, b)
    if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
        return (a - b).Magnitude
    end
    if typeof(a) == "Instance" and typeof(b) == "Instance" then
        return (a.Position - b.Position).Magnitude
    end
    return math.huge
end

-- Suavização independente de framerate. Sem o expoente dt, a suavização fica
-- mais rápida em máquinas com FPS alto — bug clássico.
function Util.damp(current, goal, speed, dt)
    return current + (goal - current) * (1 - math.exp(-speed * dt))
end

function Util.round(n, places)
    local m = 10 ^ (places or 0)
    return math.floor(n * m + 0.5) / m
end

-- ── Executor ─────────────────────────────────────────────────────────────────
-- Compatibilidade entre Synapse, Script-Ware, Solara, Xeno, Wave, Delta.
-- Cada um nomeia a mesma função de forma diferente.

local function pick(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then return v end
    end
    return nil
end

Util.getGenv      = pick(getgenv, getfenv)
Util.setClipboard = pick(setclipboard, toclipboard, syn and syn.write_clipboard)
Util.identify     = pick(identifyexecutor, getexecutorname)

function Util.executorName()
    local ok, name = pcall(function() return Util.identify() end)
    return ok and name or "Desconhecido"
end

-- ── Notificação ──────────────────────────────────────────────────────────────
-- Tenta a notificação nativa do executor primeiro (mais bonita e não colide com
-- a nossa UI); cai para um toast próprio se não existir.

function Util.notify(title, text, duration)
    local native = pick(
        syn and syn.notify,
        Fluxus and Fluxus.notify,
        secure_call and nil,
        notification
    )
    if native then
        local ok = pcall(native, { Title = title, Text = text, Duration = duration or 3 })
        if ok then return end
    end
    if Util._onNotify then Util._onNotify(title, text, duration) end
end

-- ── Loop seguro ──────────────────────────────────────────────────────────────
-- Todo loop de feature passa por aqui. Um erro dentro de um loop de RenderStep
-- derruba a conexão inteira e a feature morre em silêncio; embrulhar em pcall e
-- reportar uma vez é o que mantém o script vivo durante a noite.

function Util.loop(name, interval, fn)
    local acc = 0
    local errored = false
    return RunService.RenderStepped:Connect(function(dt)
        acc = acc + dt
        if acc < interval then return end
        acc = 0
        local ok, err = pcall(fn, dt)
        if not ok and not errored then
            errored = true
            warn(("[AOTR] '%s' falhou: %s"):format(name, tostring(err)))
            Util.notify("AOTR · Erro", ("'%s' parou. Veja o console (F9)."):format(name), 6)
        end
    end)
end

-- ── Ações no personagem ──────────────────────────────────────────────────────

function Util.getChar()
    return LP().Character
end

function Util.getRoot()
    local c = LP().Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
end

-- Teleporte via CFrame. O CFrame precisa incluir a rotação, senão o personagem
-- chega de lado e a mira da nuca erra.
function Util.teleportTo(cf)
    local root = Util.getRoot()
    if not root then return false end
    root.CFrame = cf
    return true
end

-- Rotaciona para encarar um ponto, preservando a posição.
function Util.faceTowards(root, target)
    if not root then return end
    local from = root.Position
    local dir = (target - from)
    if dir.Magnitude < 0.01 then return end
    root.CFrame = CFrame.lookAt(from, from + dir)
end

-- ── Tabelas ──────────────────────────────────────────────────────────────────

function Util.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function Util.map(t, fn)
    local out = {}
    for i, v in ipairs(t) do out[i] = fn(v, i) end
    return out
end

function Util.filter(t, fn)
    local out = {}
    for _, v in ipairs(t) do
        if fn(v) then table.insert(out, v) end
    end
    return out
end

function Util.find(t, fn)
    for _, v in ipairs(t) do
        if fn(v) then return v end
    end
    return nil
end

-- ── Formatação ───────────────────────────────────────────────────────────────

function Util.comma(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

function Util.abbrev(n)
    if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
    return tostring(math.floor(n))
end

-- ── Instância ────────────────────────────────────────────────────────────────

function Util.destroyAll(container)
    if not container then return end
    for _, c in ipairs(container:GetChildren()) do
        if c:GetAttribute("AOTR") then c:Destroy() end
    end
end

function Util.tag(inst, tag)
    inst:SetAttribute("AOTR", tag or true)
    return inst
end

-- ── Debounce ─────────────────────────────────────────────────────────────────

function Util.debounce(interval)
    local last = 0
    return function()
        local now = os.clock()
        if now - last < interval then return false end
        last = now
        return true
    end
end

return Util

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar core/util")
return __chunk(__req)
end

-- ── core/widget ───────────────────────────────────────────────
MODULES["core/widget"] = function()
local __src = [=[
--[[
    VHub · Fábrica de Widgets
    Arquivo: src/core/widget.lua

    Cada widget devolve {instance, set, get, destroy}. O contrato é sempre o
    mesmo, para que a camada de UI nunca precise saber como um controle
    funciona por dentro.

    Novidades desta versão: cartão de estatística, avatar circular, chip de
    seleção múltipla (para os modificadores de missão) e grupo de botões.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Theme = __req("core/theme")

local Widget = {}

-- ── Utilidades ───────────────────────────────────────────────────────────────

local function new(class, props, children)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then o[k] = v end
    end
    for _, c in ipairs(children or {}) do
        c.Parent = o
    end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end
Widget.new = new

local function tween(obj, info, goal)
    local t = game:GetService("TweenService"):Create(obj, info, goal)
    t:Play()
    return t
end
Widget.tween = tween

function Widget.label(props)
    return new("TextLabel", {
        Name = props.name or "Label",
        Size = props.size or UDim2.new(1, 0, 0, 16),
        Position = props.position,
        BackgroundTransparency = 1,
        Text = props.text or "",
        TextColor3 = props.color or Theme.color.text,
        TextSize = props.textSize or Theme.text.label,
        Font = props.font or Theme.font.regular,
        TextXAlignment = props.align or Enum.TextXAlignment.Left,
        TextYAlignment = props.valign or Enum.TextYAlignment.Center,
        TextWrapped = props.wrapped or false,
        RichText = props.rich or false,
        ZIndex = props.zindex or 1,
        Parent = props.parent,
    })
end

-- ── Botão ────────────────────────────────────────────────────────────────────

function Widget.button(props)
    local variant = props.variant or "ghost"

    local base = new("TextButton", {
        Name = props.name or "Btn",
        Size = props.size or UDim2.new(0, 110, 0, 32),
        Position = props.position,
        BackgroundColor3 = variant == "solid" and Theme.color.accent
            or variant == "danger" and Theme.color.danger
            or Theme.color.surface,
        BackgroundTransparency = variant == "ghost" and 1 or 0,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = props.zindex or 2,
        Parent = props.parent,
    })
    Theme.corner(base, Theme.metric.radiusSm)

    local stroke = Theme.stroke(base,
        variant == "ghost" and Theme.color.line or Theme.color.lineHot)

    local label = new("TextLabel", {
        Name = "Label",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = props.text or "Botão",
        TextColor3 = variant == "solid" and Color3.new(1, 1, 1) or Theme.color.text,
        TextSize = props.textSize or Theme.text.label,
        Font = Theme.font.medium,
        ZIndex = 3,
        Parent = base,
    })

    local icon
    if props.icon then
        label.Position = UDim2.new(0, 22, 0, 0)
        label.Size = UDim2.new(1, -28, 1, 0)
        label.TextXAlignment = Enum.TextXAlignment.Left
        icon = new("ImageLabel", {
            Size = UDim2.fromOffset(14, 14),
            Position = UDim2.new(0, 9, 0.5, -7),
            BackgroundTransparency = 1,
            Image = props.icon,
            ImageColor3 = label.TextColor3,
            ZIndex = 3,
            Parent = base,
        })
    end

    base.MouseEnter:Connect(function()
        tween(base, Theme.ease.fast, {
            BackgroundColor3 = variant == "ghost" and Theme.color.surfaceHi
                or (variant == "solid" and Theme.color.accentHi or Theme.color.danger),
            BackgroundTransparency = 0,
        })
        stroke.Color = Theme.color.accentHi
        if icon then tween(icon, Theme.ease.fast, { ImageColor3 = Theme.color.accentHi }) end
        if variant == "ghost" then
            tween(label, Theme.ease.fast, { TextColor3 = Theme.color.accentHi })
        end
    end)

    base.MouseLeave:Connect(function()
        tween(base, Theme.ease.fast, {
            BackgroundColor3 = variant == "solid" and Theme.color.accent
                or variant == "danger" and Theme.color.danger
                or Theme.color.surface,
            BackgroundTransparency = variant == "ghost" and 1 or 0,
        })
        stroke.Color = variant == "ghost" and Theme.color.line or Theme.color.lineHot
        if icon then
            tween(icon, Theme.ease.fast, {
                ImageColor3 = variant == "solid" and Color3.new(1, 1, 1) or Theme.color.text })
        end
        if variant == "ghost" then
            tween(label, Theme.ease.fast, { TextColor3 = Theme.color.text })
        end
    end)

    base.MouseButton1Click:Connect(function()
        if props.onClick then props.onClick() end
    end)

    return {
        instance = base,
        set = function(_, text) label.Text = text end,
        get = function() return label.Text end,
    }
end

-- ── Toggle ───────────────────────────────────────────────────────────────────

function Widget.toggle(props)
    local row = new("TextButton", {
        Name = props.name or "Toggle",
        Size = props.size or UDim2.new(1, 0, 0, props.sub and 42 or 34),
        BackgroundColor3 = Theme.color.surface,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = props.parent,
    })
    Theme.corner(row, Theme.metric.radiusSm)
    Theme.pad(row, 0, 11, 0)

    local label = new("TextLabel", {
        Size = UDim2.new(1, -50, 0, 16),
        Position = UDim2.new(0, 0, 0, props.sub and 5 or 9),
        BackgroundTransparency = 1,
        Text = props.text or "Opção",
        TextColor3 = Theme.color.text,
        TextSize = Theme.text.label,
        Font = Theme.font.medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
        Parent = row,
    })

    if props.sub then
        new("TextLabel", {
            Size = UDim2.new(1, -50, 0, 13),
            Position = UDim2.new(0, 0, 0, 21),
            BackgroundTransparency = 1,
            Text = props.sub,
            TextColor3 = Theme.color.textMute,
            TextSize = Theme.text.sub,
            Font = Theme.font.regular,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
            Parent = row,
        })
    end

    local track = new("Frame", {
        Name = "Track",
        Size = UDim2.fromOffset(36, 19),
        Position = UDim2.new(1, -36, 0.5, -9.5),
        BackgroundColor3 = Theme.color.off,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = row,
    })
    Theme.corner(track, 10)
    local tstroke = Theme.stroke(track, Theme.color.line)

    local knob = new("Frame", {
        Name = "Knob",
        Size = UDim2.fromOffset(13, 13),
        Position = UDim2.new(0, 3, 0.5, -6.5),
        BackgroundColor3 = Theme.color.textMute,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = track,
    })
    Theme.corner(knob, 7)

    local state = props.default or false

    local function render(animate)
        local info = animate and Theme.ease.out or TweenInfo.new(0)
        tween(track, info, {
            BackgroundColor3 = state and Theme.color.accentLo or Theme.color.off,
        })
        tstroke.Color = state and Theme.color.accent or Theme.color.line
        tween(knob, info, {
            Position = state and UDim2.new(0, 20, 0.5, -6.5) or UDim2.new(0, 3, 0.5, -6.5),
            BackgroundColor3 = state and Theme.color.accentHi or Theme.color.textMute,
        })
        tween(label, info, {
            TextColor3 = state and Theme.color.text or Theme.color.textDim,
        })
    end

    render(false)

    local function flip()
        state = not state
        render(true)
        if props.onChange then props.onChange(state) end
    end

    row.MouseButton1Click:Connect(flip)
    row.MouseEnter:Connect(function()
        tween(row, Theme.ease.fast, { BackgroundTransparency = 0, BackgroundColor3 = Theme.color.surface })
    end)
    row.MouseLeave:Connect(function()
        tween(row, Theme.ease.fast, { BackgroundTransparency = 1 })
    end)

    return {
        instance = row,
        get = function() return state end,
        set = function(_, v)
            state = v; render(true)
            if props.onChange then props.onChange(v) end
        end,
    }
end

-- ── Slider ───────────────────────────────────────────────────────────────────

function Widget.slider(props)
    local min = props.min or 0
    local max = props.max or 100
    local value = props.default or min
    local suffix = props.suffix or ""
    local decimals = props.decimals or 0

    local wrap = new("Frame", {
        Name = props.name or "Slider",
        Size = props.size or UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        Parent = props.parent,
    })

    local label = new("TextLabel", {
        Size = UDim2.new(1, -70, 0, 15),
        BackgroundTransparency = 1,
        Text = props.text or "Valor",
        TextColor3 = Theme.color.text,
        TextSize = Theme.text.label,
        Font = Theme.font.medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 2,
        Parent = wrap,
    })

    local readout = new("TextLabel", {
        Size = UDim2.fromOffset(70, 15),
        Position = UDim2.new(1, -70, 0, 0),
        BackgroundTransparency = 1,
        Text = string.format("%." .. decimals .. "f%s", value, suffix),
        TextColor3 = Theme.color.accentHi,
        TextSize = Theme.text.value,
        Font = Theme.font.mono,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 2,
        Parent = wrap,
    })

    local track = new("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.new(0, 0, 0, 28),
        BackgroundColor3 = Theme.color.off,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = wrap,
    })
    Theme.corner(track, 3)

    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.color.accent,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = track,
    })
    Theme.corner(fill, 3)
    Theme.gradientBrand(fill)
    local fg = fill:FindFirstChildOfClass("UIGradient")
    if fg then fg.Rotation = 0 end

    local thumb = new("Frame", {
        Size = UDim2.fromOffset(13, 13),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Theme.color.accentHi,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = track,
    })
    Theme.corner(thumb, 7)
    Theme.stroke(thumb, Theme.color.void, 2)

    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.new(0, 0, 0, 19),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 5,
        Parent = wrap,
    })

    local function apply(v, fire)
        value = math.clamp(v, min, max)
        local t = (value - min) / (max - min)
        fill.Size = UDim2.new(t, 0, 1, 0)
        thumb.Position = UDim2.new(t, 0, 0.5, 0)
        readout.Text = string.format("%." .. decimals .. "f%s", value, suffix)
        if fire and props.onChange then props.onChange(value) end
    end
    apply(value, false)

    local dragging = false
    local function fromX(x)
        local rel = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
        return min + (max - min) * math.clamp(rel, 0, 1)
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            apply(fromX(input.Position.X), true)
        end
    end)
    hit.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            apply(fromX(input.Position.X), true)
        end
    end)

    return {
        instance = wrap,
        get = function() return value end,
        set = function(_, v) apply(v, true) end,
    }
end

-- ── Dropdown ─────────────────────────────────────────────────────────────────

function Widget.dropdown(props)
    local options = props.options or {}
    local value = props.default or options[1]
    local open = false

    local wrap = new("Frame", {
        Name = props.name or "Dropdown",
        Size = props.size or UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        ZIndex = 5,
        Parent = props.parent,
    })

    if props.text then
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 15),
            BackgroundTransparency = 1,
            Text = props.text,
            TextColor3 = Theme.color.text,
            TextSize = Theme.text.label,
            Font = Theme.font.medium,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 6,
            Parent = wrap,
        })
    end

    local head = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.new(0, 0, 0, 19),
        BackgroundColor3 = Theme.color.surface,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = wrap,
    })
    Theme.corner(head, Theme.metric.radiusSm)
    local hstroke = Theme.stroke(head, Theme.color.line)
    Theme.pad(head, 0, 10, 0)

    local headLabel = new("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0),
        BackgroundTransparency = 1,
        Text = tostring(value),
        TextColor3 = Theme.color.text,
        TextSize = Theme.text.label,
        Font = Theme.font.regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
        Parent = head,
    })

    local caret = new("TextLabel", {
        Size = UDim2.fromOffset(14, 14),
        Position = UDim2.new(1, -20, 0.5, -7),
        BackgroundTransparency = 1,
        Text = "▾",
        TextColor3 = Theme.color.textMute,
        TextSize = 13,
        ZIndex = 7,
        Parent = head,
    })

    local list = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 4),
        BackgroundColor3 = Theme.color.surfaceTop,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 30,
        Parent = wrap,
    })
    Theme.corner(list, Theme.metric.radiusSm)
    Theme.stroke(list, Theme.color.line)
    Theme.pad(list, 4)

    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = list,
    })

    local rows = {}
    for i, opt in ipairs(options) do
        local r = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Theme.color.surface,
            BackgroundTransparency = 1,
            Text = tostring(opt),
            TextColor3 = Theme.color.textDim,
            TextSize = Theme.text.label,
            Font = Theme.font.regular,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
            LayoutOrder = i,
            ZIndex = 31,
            Parent = list,
        })
        Theme.corner(r, 4)
        Theme.pad(r, 0, 9, 0)
        r.MouseEnter:Connect(function()
            tween(r, Theme.ease.fast, { BackgroundTransparency = 0, TextColor3 = Theme.color.accentHi })
        end)
        r.MouseLeave:Connect(function()
            tween(r, Theme.ease.fast, { BackgroundTransparency = 1, TextColor3 = Theme.color.textDim })
        end)
        r.MouseButton1Click:Connect(function()
            value = opt
            headLabel.Text = tostring(opt)
            open = false
            tween(caret, Theme.ease.fast, { Rotation = 0 })
            tween(list, Theme.ease.fast, { Size = UDim2.new(1, 0, 0, 0) })
            task.delay(0.1, function() if not open then list.Visible = false end end)
            hstroke.Color = Theme.color.line
            if props.onChange then props.onChange(opt) end
        end)
        rows[opt] = r
    end

    head.MouseButton1Click:Connect(function()
        if open then
            open = false
            tween(caret, Theme.ease.fast, { Rotation = 0 })
            tween(list, Theme.ease.fast, { Size = UDim2.new(1, 0, 0, 0) })
            task.delay(0.1, function() if not open then list.Visible = false end end)
            hstroke.Color = Theme.color.line
        else
            open = true
            list.Visible = true
            tween(list, Theme.ease.out, { Size = UDim2.new(1, 0, 0, #options * 28 + 8) })
            tween(caret, Theme.ease.fast, { Rotation = 180 })
            hstroke.Color = Theme.color.accent
        end
    end)

    game:GetService("UserInputService").InputBegan:Connect(function(input)
        if open and input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mp = input.Position
            local ap, sz = wrap.AbsolutePosition, wrap.AbsoluteSize
            local inHead = mp.X >= ap.X and mp.X <= ap.X + sz.X
                and mp.Y >= ap.Y and mp.Y <= ap.Y + 50
            if not inHead then
                open = false
                tween(caret, Theme.ease.fast, { Rotation = 0 })
                tween(list, Theme.ease.fast, { Size = UDim2.new(1, 0, 0, 0) })
                task.delay(0.1, function() if not open then list.Visible = false end end)
                hstroke.Color = Theme.color.line
            end
        end
    end)

    return {
        instance = wrap,
        get = function() return value end,
        set = function(_, v)
            if rows[v] then
                value = v
                headLabel.Text = tostring(v)
                if props.onChange then props.onChange(v) end
            end
        end,
    }
end

-- ── Chips (seleção múltipla) ──────────────────────────────────────────────────
-- Usado nos modificadores de missão: uma grade de botões que ligam e desligam.

function Widget.chips(props)
    local options = props.options or {}
    local selected = {}
    for _, v in ipairs(props.default or {}) do selected[v] = true end

    local wrap = new("Frame", {
        Name = props.name or "Chips",
        Size = props.size or UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = props.parent,
    })

    if props.text then
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 15),
            BackgroundTransparency = 1,
            Text = props.text,
            TextColor3 = Theme.color.text,
            TextSize = Theme.text.label,
            Font = Theme.font.medium,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = wrap,
        })
    end

    local grid = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, props.text and 19 or 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = wrap,
    })
    new("UIGridLayout", {
        CellSize = UDim2.new(0, 132, 0, 26),
        CellPadding = UDim2.new(0, 5, 0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = grid,
    })

    local buttons = {}

    local function refresh()
        local list = {}
        for _, opt in ipairs(options) do
            if selected[opt] then table.insert(list, opt) end
        end
        if props.onChange then props.onChange(list) end
    end

    for i, opt in ipairs(options) do
        local b = new("TextButton", {
            Size = UDim2.new(0, 132, 0, 26),
            BackgroundColor3 = Theme.color.surface,
            Text = opt,
            TextColor3 = Theme.color.textDim,
            TextSize = Theme.text.sub,
            Font = Theme.font.medium,
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = i,
            Parent = grid,
        })
        Theme.corner(b, Theme.metric.radiusSm)
        local s = Theme.stroke(b, Theme.color.line)
        Theme.pad(b, 0, 6, 0)

        local function render(animate)
            local on = selected[opt] == true
            local info = animate and Theme.ease.fast or TweenInfo.new(0)
            tween(b, info, {
                BackgroundColor3 = on and Theme.color.accentLo or Theme.color.surface,
            })
            s.Color = on and Theme.color.accent or Theme.color.line
            tween(b, info, { TextColor3 = on and Color3.new(1, 1, 1) or Theme.color.textDim })
        end
        render(false)

        b.MouseButton1Click:Connect(function()
            selected[opt] = not selected[opt] or nil
            render(true)
            refresh()
        end)

        buttons[opt] = b
    end

    return {
        instance = wrap,
        get = function()
            local list = {}
            for _, opt in ipairs(options) do
                if selected[opt] then table.insert(list, opt) end
            end
            return list
        end,
        set = function(_, list)
            selected = {}
            for _, v in ipairs(list or {}) do selected[v] = true end
            for opt, b in pairs(buttons) do
                local on = selected[opt] == true
                b.BackgroundColor3 = on and Theme.color.accentLo or Theme.color.surface
                b.TextColor3 = on and Color3.new(1, 1, 1) or Theme.color.textDim
            end
            refresh()
        end,
    }
end

-- ── Cartão de estatística ────────────────────────────────────────────────────
-- O número grande em cima, o rótulo embaixo. É o que dá peso ao dashboard.

function Widget.statCard(props)
    local card = new("Frame", {
        Name = props.name or "Stat",
        Size = props.size or UDim2.new(0, 128, 0, Theme.metric.statCardH),
        BackgroundColor3 = Theme.color.card,
        BorderSizePixel = 0,
        Parent = props.parent,
    })
    Theme.corner(card, Theme.metric.radiusSm)
    local s = Theme.stroke(card, Theme.color.lineSoft)
    Theme.pad(card, 0, 11, 9)

    -- fio de destaque no topo, em gradiente — detalhe que amarra ao tema
    local accent = new("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = card,
    })
    Theme.corner(accent, 1)
    Theme.gradientBrand(accent)
    local ag = accent:FindFirstChildOfClass("UIGradient")
    if ag then ag.Rotation = 0 end

    local value = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.new(0, 0, 0, 8),
        BackgroundTransparency = 1,
        Text = props.value or "—",
        TextColor3 = Theme.color.text,
        TextSize = Theme.text.stat,
        Font = Theme.font.bold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = card,
    })

    local caption = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        Position = UDim2.new(0, 0, 1, -18),
        BackgroundTransparency = 1,
        Text = string.upper(props.caption or ""),
        TextColor3 = Theme.color.textMute,
        TextSize = Theme.text.statLbl,
        Font = Theme.font.medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = card,
    })

    return {
        instance = card,
        set = function(_, v, color)
            value.Text = tostring(v)
            if color then value.TextColor3 = color end
        end,
        setCaption = function(_, c) caption.Text = string.upper(tostring(c)) end,
        get = function() return value.Text end,
    }
end

-- ── Avatar circular ──────────────────────────────────────────────────────────

function Widget.avatar(props)
    local size = props.size or Theme.metric.avatar

    local wrap = new("Frame", {
        Name = "Avatar",
        Size = UDim2.fromOffset(size, size),
        Position = props.position,
        BackgroundColor3 = Theme.color.surfaceTop,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = props.parent,
    })
    Theme.corner(wrap, size / 2)
    local s = Theme.stroke(wrap, Theme.color.accent, 2)

    local img = new("ImageLabel", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Image = props.image or "",
        ZIndex = 4,
        Parent = wrap,
    })
    Theme.corner(img, size / 2)

    return {
        instance = wrap,
        set = function(_, url)
            if url and url ~= "" then img.Image = url end
        end,
    }
end

-- ── Seção ────────────────────────────────────────────────────────────────────

function Widget.section(props)
    local wrap = new("Frame", {
        Name = props.name or "Section",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = props.parent,
    })

    local head = new("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Parent = wrap,
    })

    -- barrinha vermelha ao lado do título: âncora visual repetida em toda a UI
    local tick = new("Frame", {
        Size = UDim2.fromOffset(3, 12),
        Position = UDim2.new(0, 0, 0.5, -6),
        BackgroundColor3 = Theme.color.accent,
        BorderSizePixel = 0,
        Parent = head,
    })
    Theme.corner(tick, 2)

    new("TextLabel", {
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.new(0, 11, 0, 0),
        BackgroundTransparency = 1,
        Text = string.upper(props.text or "SEÇÃO"),
        TextColor3 = Theme.color.textDim,
        TextSize = Theme.text.section,
        Font = Theme.font.bold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = head,
    })

    local count = new("TextLabel", {
        Size = UDim2.fromOffset(72, 18),
        Position = UDim2.new(1, -72, 0.5, -9),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.color.accent,
        TextSize = Theme.text.tiny,
        Font = Theme.font.mono,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = head,
    })

    local rule = new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, 23),
        BackgroundColor3 = Theme.color.lineSoft,
        BorderSizePixel = 0,
        Parent = wrap,
    })

    local body = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 30),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = wrap,
    })
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
        Parent = body,
    })

    return {
        instance = wrap,
        body = body,
        setCount = function(n)
            count.Text = n > 0 and (n .. " ATIVO" .. (n > 1 and "S" or "")) or ""
        end,
        add = function(child) child.instance.Parent = body end,
    }
end

-- ── Diversos ─────────────────────────────────────────────────────────────────

function Widget.divider(parent)
    local d = new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.color.lineSoft,
        BorderSizePixel = 0,
        Parent = parent,
    })
    return d
end

function Widget.input(props)
    local wrap = new("Frame", {
        Size = props.size or UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        Parent = props.parent,
    })

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 15),
        BackgroundTransparency = 1,
        Text = props.text or "Campo",
        TextColor3 = Theme.color.text,
        TextSize = Theme.text.label,
        Font = Theme.font.medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = wrap,
    })

    local box = new("TextBox", {
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.new(0, 0, 0, 19),
        BackgroundColor3 = Theme.color.surface,
        Text = props.default or "",
        PlaceholderText = props.placeholder or "",
        PlaceholderColor3 = Theme.color.textMute,
        TextColor3 = Theme.color.text,
        TextSize = Theme.text.label,
        Font = Theme.font.regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        BorderSizePixel = 0,
        Parent = wrap,
    })
    Theme.corner(box, Theme.metric.radiusSm)
    local bstroke = Theme.stroke(box, Theme.color.line)
    Theme.pad(box, 0, 10, 0)

    box.Focused:Connect(function() tween(bstroke, Theme.ease.fast, { Color = Theme.color.accent }) end)
    box.FocusLost:Connect(function()
        tween(bstroke, Theme.ease.fast, { Color = Theme.color.line })
        if props.onSubmit then props.onSubmit(box.Text) end
    end)

    return {
        instance = wrap,
        get = function() return box.Text end,
        set = function(_, v) box.Text = v end,
    }
end

function Widget.info(props)
    local box = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = props.danger and Theme.color.accentGhost or Theme.color.surface,
        BorderSizePixel = 0,
        LayoutOrder = props.order or 0,
        Parent = props.parent,
    })
    Theme.corner(box, Theme.metric.radiusSm)
    Theme.stroke(box, props.danger and Theme.color.lineHot or Theme.color.lineSoft)
    Theme.pad(box, 0, 11, 8)

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = props.text or "",
        TextColor3 = props.danger and Theme.color.textDim or Theme.color.textMute,
        TextSize = Theme.text.sub,
        Font = Theme.font.regular,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = box,
    })

    return { instance = box }
end

return Widget

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar core/widget")
return __chunk(__req)
end

-- ── features/combat ───────────────────────────────────────────
MODULES["features/combat"] = function()
local __src = [=[
--[[
    AOTR · Combate
    Arquivo: src/features/combat.lua

    COMO O DANO REALMENTE ACONTECE
    ------------------------------
    Não existe RemoteEvent de ataque por ação. O jogo inteiro multiplexa sobre
    dois objetos:

        ReplicatedStorage.Assets.Remotes.POST  (RemoteEvent)
        ReplicatedStorage.Assets.Remotes.GET   (RemoteFunction)

    O ataque é um par de chamadas:

        POST:FireServer("Attacks", "Slash", true)
        GET:InvokeServer("Hitboxes", "Register", <part>, <magnitude>, <offset>)

    A segunda é a DECLARAÇÃO DE DANO. O cliente diz ao servidor "acertei esta
    parte, a esta distância". O servidor valida.

    POR QUE O ALCANCE IMPORTA TANTO
    -------------------------------
    O script de referência usa `math.random(215, 230)` como magnitude. Isso é
    fisicamente impossível — o alcance real da lâmina neste jogo é o
    comprimento da arma. Um valor desses é o sinal mais óbvio que o servidor
    pode checar, e é o candidato número um a gatilho de marcação.

    Aqui a magnitude fica no padrão da lâmina (configurável até 40), e o
    "alcance estendido" é opt-in com aviso claro. Preferimos um kill aura que
    funciona e não marca a conta a um que mata de 200 studs por dois dias.

    ANTI-SHADOW-BAN
    ---------------
    O gatilho confirmado é VELOCIDADE. Um kill aura que limpa missões em 8
    segundos bate exatamente na assinatura. O script de referência embarca um
    limitador chamado "Bypass Farm (No Shadow Ban)" travado em 32 s.

    Este módulo implementa o mesmo princípio: segura o ÚLTIMO titã vivo até
    que o tempo mínimo da missão tenha decorrido.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Game = __req("core/game")
local State = __req("core/state")
local Util = __req("core/util")
local Theme = __req("core/theme")

local Combat = {}

local RunService = game:GetService("RunService")

Combat.target = nil
Combat.kills = 0
Combat._lastAttack = 0
Combat._lastSlash = 0
Combat._missionStart = os.clock()
Combat._heldTitan = nil

-- ── Pose de ataque ───────────────────────────────────────────────────────────
-- A nuca fica na face posterior do Titã. Posicionar-se atrás e acima é o que
-- faz o golpe registrar na parte certa.

function Combat.napePose(titan, offset, height)
    local nape, root = titan.nape, titan.root
    if not (nape and root) then return nil end

    local away = nape.Position - root.Position
    away = Vector3.new(away.X, 0, away.Z)
    if away.Magnitude < 0.01 then
        local back = -root.CFrame.LookVector
        away = Vector3.new(back.X, 0, back.Z)
    end
    away = away.Unit

    local stand = nape.Position + away * (offset or 4) + Vector3.new(0, height or 2, 0)
    return CFrame.lookAt(stand, nape.Position)
end

-- ── Ataque ───────────────────────────────────────────────────────────────────

-- Dispara o par de remotes. `part` é o alvo real: passar a nuca é o que
-- caracteriza um acerto crítico — não existe remote separado para isso.
function Combat.strike(titan, magnitude, offset)
    magnitude = magnitude or State.config.hitMagnitude
    offset = offset or State.config.hitOffset

    -- POST: o swing em si.
    Game.post("Attacks", "Slash", true)

    -- GET: a declaração de dano. É esta que o servidor valida.
    local ok = Game.get("Hitboxes", "Register", titan.nape, magnitude, offset)
    return ok
end

-- ── Auto TP ──────────────────────────────────────────────────────────────────

function Combat.autoTP()
    if os.clock() - (Combat._lastTP or 0) < State.config.tpCooldown then return end

    local titan = Game.getNearestTitan()
    if not titan or titan.dist > State.config.tpRange then return end

    local cf = Combat.napePose(titan, State.config.tpOffset, 2.2)
    local root = Game.getRoot()
    if cf and root then
        root.CFrame = cf
        Combat._lastTP = os.clock()
        Combat.target = titan
    end
end

-- ── Kill Aura ────────────────────────────────────────────────────────────────

-- O limitador de velocidade. Conta quantos titãs vivos existem; quando sobra
-- só um E a missão ainda é recente, ele não ataca. É o que evita a assinatura
-- de "limpou em 6 segundos".
function Combat.shouldHold()
    if not State.flags.safeFarm then return false end

    local safeTime = State.config.safeTime
    if safeTime <= 0 then return false end

    local titans = Game.getTitans()
    if #titans > 1 then
        -- Ainda há trabalho: o tempo corre normalmente.
        Combat._missionStart = Combat._missionStart or os.clock()
        return false
    end

    -- Último titã: só ataca depois do tempo mínimo.
    local elapsed = os.clock() - (Combat._missionStart or os.clock())
    if elapsed < safeTime then
        Combat._heldTitan = titans[1] and titans[1].model or nil
        return true
    end
    return false
end

function Combat.killAuraTick()
    local titans = Game.getTitans()
    if #titans == 0 then return end

    local range = State.config.killAuraRange
    local target
    for _, t in ipairs(titans) do
        if t.dist <= range then target = t break end
    end

    -- Sem alvo no alcance: se o Auto TP está ligado, aproxima.
    if not target then
        if State.flags.autoTP then Combat.autoTP() end
        return
    end

    Combat.target = target

    -- Trava de segurança: segura o ultimo titã para não fechar a missão cedo.
    if Combat.shouldHold() then return end

    if os.clock() - Combat._lastAttack < State.config.killAuraDelay then return end
    Combat._lastAttack = os.clock()

    -- Reposiciona antes de bater, para o golpe sair na nuca.
    if State.flags.killAuraNape then
        local cf = Combat.napePose(target, State.config.tpOffset, 2.2)
        local root = Game.getRoot()
        if cf and root then root.CFrame = cf end
    end

    Combat.strike(target)
end

-- ── Nape Expander ────────────────────────────────────────────────────────────
-- Aumenta a parte da nuca localmente. A nuca é invisível por padrão; deixá-la
-- visível e maior ajuda muito na mira manual.
-- Efeito é client-side: o servidor tem a própria cópia.

local expanded = {}

function Combat.expandNapes()
    local scale = State.config.napeScale
    for _, t in ipairs(Game.getTitans()) do
        local nape = t.nape
        if nape and not expanded[nape] then
            expanded[nape] = {
                size = nape.Size,
                transparency = nape.Transparency,
                color = nape.Color,
                material = nape.Material,
            }
            nape.Size = nape.Size * scale
            nape.Transparency = State.config.napeTransparency
            nape.Color = Theme.color.accent
            nape.Material = Enum.Material.Neon
        end
    end
end

function Combat.restoreNapes()
    for part, saved in pairs(expanded) do
        if part and part.Parent then
            pcall(function()
                part.Size = saved.size
                part.Transparency = saved.transparency
                part.Color = saved.color
                part.Material = saved.material
            end)
        end
        expanded[part] = nil
    end
end

-- ── Reabastecimento ──────────────────────────────────────────────────────────
-- "Gás infinito" neste jogo significa spammar os remotes de reload, não
-- escrever num valor — não existe valor de gás no cliente.
--   GET("Blades","Reload")
--   GET("Blades","Full_Reload", "Left"|"Right", <estação>)
--   POST("Attacks","Reload", <estação>)

function Combat.resupply()
    local station = Game.getRefillStation()

    if State.flags.autoRefill then
        if Game.isBladeBroken() then
            Game.get("Blades", "Full_Reload", "Left", station)
            Game.get("Blades", "Full_Reload", "Right", station)
        end
        Game.get("Blades", "Reload")
    end

    if State.flags.infiniteGas and station then
        Game.post("Attacks", "Reload", station)
    end
end

-- ── Contagem de abates ───────────────────────────────────────────────────────

Combat._tracked = {}

function Combat.trackKills()
    local now = os.clock()
    local seen = {}
    for _, t in ipairs(Game.getTitans()) do
        seen[t.model] = true
        local rec = Combat._tracked[t.model]
        if rec then
            rec.hp = t.hp
            rec.seen = now
        else
            Combat._tracked[t.model] = { hp = t.hp, seen = now }
        end
    end
    for model, rec in pairs(Combat._tracked) do
        if not seen[model] then
            if (now - rec.seen) < 2 and State.flags.killAura then
                Combat.kills = Combat.kills + 1
            end
            Combat._tracked[model] = nil
        end
    end
end

-- ── Ciclo ────────────────────────────────────────────────────────────────────

function Combat.start()
    if Combat._conn then return end
    Combat._missionStart = os.clock()

    Combat._conn = RunService.RenderStepped:Connect(function()
        local ok, err = pcall(function()
            if State.flags.killAura then
                Combat.killAuraTick()
            elseif State.flags.autoTP then
                Combat.autoTP()
            end

            if State.flags.napeExpander then
                Combat.expandNapes()
            end

            if State.flags.autoRefill or State.flags.infiniteGas then
                if os.clock() - (Combat._lastResupply or 0) > 1 then
                    Combat._lastResupply = os.clock()
                    Combat.resupply()
                end
            end

            Combat.trackKills()
        end)
        if not ok then warn("[AOTR] combate: " .. tostring(err)) end
    end)
end

function Combat.stop()
    if Combat._conn then Combat._conn:Disconnect(); Combat._conn = nil end
    Combat.restoreNapes()
end

-- Recomeça a janela de segurança. Chamado quando uma missão nova é detectada.
function Combat.newMission()
    Combat._missionStart = os.clock()
    Combat._heldTitan = nil
end

return Combat

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar features/combat")
return __chunk(__req)
end

-- ── features/lobby ────────────────────────────────────────────
MODULES["features/lobby"] = function()
local __src = [=[
--[[
    VHub · Lobby
    Arquivo: src/features/lobby.lua

    Tudo aqui roda no lobby, onde se cria a missão e se gasta progressão.

    IDENTIFICADORES — verificados em fontes desobfuscadas:

      Criar missão:   GET("S_Missions", "Create", {
                          Difficulty = <valor>, Type = <tipo>,
                          Objective = <objetivo>, Name = <mapa> })
      Modificar:      GET("S_Missions", "Modify", <modificador>)
      Iniciar:        GET("S_Missions", "Start")
      Sair:           GET("S_Missions", "Leave")

      Ordem correta: Leave → espera → Create → Modify×N → Start

      Progressão:     GET("S_Equipment", "Upgrade", { <nomes de stat> })
                      GET("S_Equipment", "Unlock", { <ids de skill> })
                      GET("S_Equipment", "Weapon", "Blades"|"Spears")

    VALORES VÁLIDOS (listas completas das fontes)
      Mapas        : Shiganshina, Trost, Outskirts, Forest, Utgard, Docks,
                     Stohess, Chapel
      Dificuldade  : Easy, Normal, Hard, Severe, Aberrant
      Tipo         : Missions | Raids | Waves
      Objetivo     : Skirmish (só em Missions) | Waves (só em Waves)
      Modificadores: 12 opções, ver MODIFIERS abaixo

      Raids: Attack Titan→Trost, Armored Titan→Shiganshina,
             Female Titan→Stohess, Colossal Titan→Shiganshina (só Aberrant)

    Mapa com bônus: workspace:GetAttribute("Boosted_Map") traz o NOME do mapa
    (validado contra a lista) e "Boosted_Timer" os segundos restantes.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Game = __req("core/game")
local State = __req("core/state")
local Util = __req("core/util")

local Lobby = {}

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- ── Listas de valores válidos ────────────────────────────────────────────────

Lobby.MAPS = {
    "Shiganshina", "Trost", "Outskirts", "Forest",
    "Utgard", "Docks", "Stohess", "Chapel",
}

Lobby.DIFFICULTIES = { "Easy", "Normal", "Hard", "Severe", "Aberrant" }

Lobby.TYPES = { "Missions", "Raids", "Waves" }

Lobby.OBJECTIVES = { "Skirmish" }

Lobby.MODIFIERS = {
    "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball",
    "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon",
    "Time Trial", "Boring", "Simple",
}

Lobby.RAIDS = {
    ["Attack Titan"]   = "Trost",
    ["Armored Titan"]  = "Shiganshina",
    ["Female Titan"]   = "Stohess",
    ["Colossal Titan"] = "Shiganshina",
}

-- Mapa com bônus ativo, ou nil.
function Lobby.boostedMap()
    local name = Workspace:GetAttribute("Boosted_Map")
    local timer = Workspace:GetAttribute("Boosted_Timer")
    if not name or not timer or timer <= 3 then return nil end
    if not table.find(Lobby.MAPS, name) then return nil end
    return name, timer
end

-- ── Criação de missão ────────────────────────────────────────────────────────

Lobby.status = "Ocioso"
Lobby._lastCreate = 0
Lobby._lastStart = 0
Lobby._lastLeave = 0

local function setStatus(s)
    Lobby.status = s
end

-- Escolhe o mapa: o bônus tem prioridade quando a opção está ligada.
function Lobby.pickMap()
    if State.flags.preferBoosted then
        local boosted = Lobby.boostedMap()
        if boosted then return boosted end
    end
    local chosen = State.config.mapName
    if chosen == "Automático" or not table.find(Lobby.MAPS, chosen) then
        return Lobby.MAPS[math.random(1, #Lobby.MAPS)]
    end
    return chosen
end

function Lobby.createMission()
    local now = os.clock()
    if now - Lobby._lastCreate < 8 then return false, "aguarde" end
    Lobby._lastCreate = now

    local map = Lobby.pickMap()
    local difficulty = State.config.difficulty
    local missionType = State.config.missionType
    local objective = State.config.objective

    -- Objective só é aceito em Missions/Waves; em Raids o servidor usa o nome
    -- do Titã. Mandar o campo errado faz o Create falhar em silêncio.
    local args = {
        Difficulty = difficulty,
        Type = missionType,
        Name = map,
    }
    if missionType == "Missions" then
        args.Objective = "Skirmish"
    elseif missionType == "Waves" then
        args.Objective = "Waves"
        args.Name = "Trost"          -- Waves só existe em Trost
        args.Difficulty = "Easy"     -- e só na dificuldade mais baixa
    elseif missionType == "Raids" then
        args.Name = Lobby.RAIDS[State.config.raid] or "Trost"
        if State.config.raid == "Colossal Titan" then
            args.Difficulty = "Aberrant"
            args.Minimum = 3          -- exigido para o Colossal
        end
    end

    local result = Game.get("S_Missions", "Create", args)
    if result then
        setStatus(("Sala criada · %s · %s"):format(map, difficulty))
        return true, result
    end

    setStatus("Falha ao criar a sala")
    return false
end

function Lobby.modifyModifiers()
    local mods = State.config.modifiers
    if type(mods) ~= "table" or #mods == 0 then return end
    for _, m in ipairs(mods) do
        Game.get("S_Missions", "Modify", m)
        task.wait(0.17)   -- espaçamento observado nas fontes
    end
end

function Lobby.startMission()
    local now = os.clock()
    if now - Lobby._lastStart < 15 then return false end
    Lobby._lastStart = now

    local ok, result = Game.get("S_Missions", "Start")
    setStatus(ok and "Missão iniciada" or "Falha ao iniciar")
    return ok, result
end

function Lobby.leaveMission()
    if os.clock() - Lobby._lastLeave < 3 then return end
    Lobby._lastLeave = os.clock()
    Game.get("S_Missions", "Leave")
end

-- Ciclo completo: sair da sala atual, criar, aplicar modificadores, iniciar.
function Lobby.autoStartTick()
    local now = os.clock()

    -- Só age no lobby — em missão não há o que criar.
    if Game.hasTitans() then return end
    if now - Lobby._lastLeave < 12 then return end

    Game.get("S_Missions", "Leave")
    Lobby._lastLeave = now
    setStatus("Preparando sala…")

    task.spawn(function()
        task.wait(0.6)

        local ok = Lobby.createMission()
        if not ok then return end

        task.wait(0.6)
        Lobby.modifyModifiers()

        task.wait(0.6)
        Lobby.startMission()
    end)
end

-- ── Melhorar atributos ───────────────────────────────────────────────────────
-- S_Equipment/Upgrade recebe uma LISTA de nomes de stat. Os nomes precisam
-- bater com os internos do jogo — os que as fontes usam estão em STATS abaixo.

Lobby.STATS = { "Health", "Damage", "Speed", "Gas", "Blade" }

Lobby.upgradesDone = 0
local lastUpgrade = 0

function Lobby.upgradeAttributes()
    if os.clock() - lastUpgrade < 3 then return end
    lastUpgrade = os.clock()

    local ok = Game.get("S_Equipment", "Upgrade", Lobby.STATS)
    if ok then
        Lobby.upgradesDone = Lobby.upgradesDone + 1
        setStatus(("Atributos melhorados (%d)"):format(Lobby.upgradesDone))
    end
end

-- ── Árvore de habilidades ────────────────────────────────────────────────────
-- S_Equipment/Unlock recebe um ARRAY de ids, na ordem raiz→folha.
-- Os ids abaixo vêm do mapa SKILL_PATHS de uma fonte desobfuscada.
--
-- Três trilhas: Left, Middle, Right. Duas builds por trilha.

Lobby.SKILL_PATHS = {
    Left = {
        ["Regen VI"] = {
            "89","88","87","86","85","84","83","82","81","80",
            "79","78","77","76","75","154","73","72","71","70",
        },
        ["Injury III"] = {
            "98","97","96","95","94","93","92","91","90","80",
            "79","78","77","76","75","154","73","72","71","70",
        },
    },
    Middle = {
        ["Damage V"] = {
            "149","148","147","146","145","144","143","142","141","140",
            "139","138","125","124","123","122","121","120","119","118",
            "117","116","115","114","113",
        },
        ["Crit Damage V"] = {
            "137","136","135","134","133","132","131","130","129","128",
            "127","126","125","124","123","122","121","120","119","118",
            "117","116","115","114","113",
        },
    },
    Right = {
        ["Tank VIII"] = {
            "69","68","67","66","65","64","63","62","61","60",
            "151","58","45","44","43","42","41","150","39","38",
        },
        ["Health XI"] = {
            "57","56","55","54","53","52","51","50","49","48",
            "47","46","45","44","43","42","41","150","39","38",
        },
    },
}

-- Trilha -> build escolhida na config
function Lobby.skillIdsFor(lane)
    local build = State.config["skill" .. lane]
    local paths = Lobby.SKILL_PATHS[lane]
    if not paths then return nil end
    return paths[build]
end

Lobby.skillsUnlocked = 0
local lastSkill = 0

function Lobby.unlockSkills()
    if os.clock() - lastSkill < 4 then return end
    lastSkill = os.clock()

    local any = false
    for _, lane in ipairs({ "Left", "Middle", "Right" }) do
        local ids = Lobby.skillIdsFor(lane)
        if ids then
            local ok = Game.get("S_Equipment", "Unlock", table.clone(ids))
            if ok then
                any = true
                Lobby.skillsUnlocked = Lobby.skillsUnlocked + 1
            end
            task.wait(0.3)   -- espaço entre trilhas, para não saturar o remote
        end
    end

    if any then
        setStatus(("Habilidades desbloqueadas (%d)"):format(Lobby.skillsUnlocked))
    end
end

-- ── Ciclo ────────────────────────────────────────────────────────────────────

function Lobby.start()
    if Lobby._conn then return end

    Lobby._conn = RunService.Heartbeat:Connect(function()
        local ok, err = pcall(function()
            if State.flags.autoStart then
                Lobby.autoStartTick()
            end
            if State.flags.autoUpgrade then
                Lobby.upgradeAttributes()
            end
            if State.flags.autoSkills then
                Lobby.unlockSkills()
            end
        end)
        if not ok then warn("[VHub] lobby: " .. tostring(err)) end
    end)
end

function Lobby.stop()
    if Lobby._conn then Lobby._conn:Disconnect(); Lobby._conn = nil end
end

return Lobby

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar features/lobby")
return __chunk(__req)
end

-- ── features/mission ──────────────────────────────────────────
MODULES["features/mission"] = function()
local __src = [=[
--[[
    VHub · Missões (combate)
    Arquivo: src/features/mission.lua

    IDENTIFICADORES — todos verificados em fontes desobfuscadas:

      Ataque (bracketed):
        POST("Attacks", "Slash", true)      abre o golpe
        GET("Hitboxes", "Register", part, magnitude, offset)
        POST("Attacks", "Slash", false)     fecha o golpe

        O par abrir/fechar importa: o servidor valida a JANELA do golpe, não
        um disparo isolado. Mandar só o Register não registra dano.

      Escapar de agarrão:
        POST("Attacks", "Slash_Escape")
        O gatilho é o aparecimento de um filho em PlayerGui.Interface.Buttons.
        Não existe ChangeState nem PlatformStand — o prompt É o sinal.

      Recarregar lâminas:
        GET("Blades", "Full_Reload", "Left"|"Right", estação)
        GET("Blades", "Reload")
        Sinal de lâmina gasta: atributo "Broken" na parte da lâmina.

      Invulnerabilidade: Character:GetAttribute("IFrames")

    MAGNITUDE — a decisão de risco
    ---------------------------------
    Fontes usam 143+rand(10) e até rand(215,230). A segunda é fisicamente
    impossível: o alcance real da lâmina é o comprimento da arma. É o dado mais
    fácil do servidor auditar. O padrão aqui é BAIXO e o valor alto é opt-in.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Game = __req("core/game")
local State = __req("core/state")
local Util = __req("core/util")
local Theme = __req("core/theme")

local Mission = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

Mission.kills = 0
Mission.target = nil
Mission._lastStrike = 0
Mission._slashOpen = false
Mission._tracked = {}
Mission._missionStart = os.clock()

-- ── Pose de ataque ───────────────────────────────────────────────────────────

function Mission.napePose(titan, offset, height)
    local nape, root = titan.nape, titan.root
    if not (nape and root) then return nil end

    local away = nape.Position - root.Position
    away = Vector3.new(away.X, 0, away.Z)
    if away.Magnitude < 0.01 then
        local back = -root.CFrame.LookVector
        away = Vector3.new(back.X, 0, back.Z)
    end
    away = away.Unit

    local stand = nape.Position + away * (offset or 4) + Vector3.new(0, height or 2, 0)
    return CFrame.lookAt(stand, nape.Position)
end

-- ── Ataque ───────────────────────────────────────────────────────────────────
-- Abre, registra e fecha. Os três passos no mesmo frame, porque o servidor
-- valida a janela do golpe.

function Mission.strike(titan)
    if not titan or not titan.nape then return false end

    Game.post("Attacks", "Slash", true)
    local ok = Game.get("Hitboxes", "Register",
        titan.nape, State.config.hitMagnitude, State.config.hitOffset)
    Game.post("Attacks", "Slash", false)

    return ok
end

-- ── Escape de agarrão ────────────────────────────────────────────────────────
-- O prompt de agarrão aparece como filho novo em PlayerGui.Interface.Buttons.
-- O sinal é observado, não adivinhado.

local escapeConn = nil
Mission.grabbed = false
Mission.escapes = 0

function Mission.watchGrabs()
    if escapeConn then return end

    local lp = Game.getLocalPlayer()
    local pg = lp and lp:FindFirstChild("PlayerGui")
    local iface = pg and pg:FindFirstChild("Interface")
    local buttons = iface and iface:FindFirstChild("Buttons")

    if not buttons then
        -- Ainda não montou: tenta de novo em instantes.
        task.delay(3, Mission.watchGrabs)
        return
    end

    escapeConn = buttons.ChildAdded:Connect(function(child)
        if not State.flags.autoEscape then return end
        if not child:IsA("GuiObject") then return end

        Mission.grabbed = true
        Util.notify("Agarrão detectado", "Escapando…", 2)

        Game.post("Attacks", "Slash_Escape")
        Mission.escapes = Mission.escapes + 1

        -- O script de referência remove o prompt depois de escapar. Sem isso o
        -- elemento fica na tela e o evento dispara de novo em loop.
        task.delay(0.3, function()
            pcall(function() child:Destroy() end)
            Mission.grabbed = false
        end)
    end)
end

-- ── Auto recarregar ──────────────────────────────────────────────────────────
-- Lâmina quebrada é o atributo "Broken". É a leitura mais robusta entre as
-- opções (as outras seriam o texto do HUD ou Transparency, ambas frágeis).

local lastReload = 0

function Mission.bladeNeedsReload()
    local char = Game.getCharacter()
    if not char then return false end

    local lp = Game.getLocalPlayer()
    local rig = char:FindFirstChild("Rig_" .. (lp and lp.Name or ""))
    if not rig then
        -- Fallback: qualquer filho que comece com Rig_
        for _, d in ipairs(char:GetChildren()) do
            if string.sub(d.Name, 1, 4) == "Rig_" then rig = d break end
        end
    end
    if not rig then return false end

    for _, handName in ipairs({ "LeftHand", "RightHand" }) do
        local hand = rig:FindFirstChild(handName)
        if hand then
            for _, blade in ipairs(hand:GetChildren()) do
                if blade:IsA("BasePart") and blade:GetAttribute("Broken") then
                    return true
                end
            end
        end
    end
    return false
end

function Mission.reloadBlades()
    if os.clock() - lastReload < 1.5 then return end
    lastReload = os.clock()

    local station = Game.getRefillStation()
    Game.get("Blades", "Full_Reload", "Left", station)
    Game.get("Blades", "Full_Reload", "Right", station)
    Game.get("Blades", "Reload")
end

-- ── Local seguro ─────────────────────────────────────────────────────────────
-- NÃO existe conceito de zona segura no jogo. A pesquisa confirmou: nenhum
-- remote, atributo ou região. O que existe são políticas de farm escritas por
-- scripts (o SafeTime do Smooth Hub).
--
-- Aqui o "Local Seguro" é honesto sobre o que faz: mantém o personagem fora do
-- alcance dos Titãs, recuando quando um chega perto. É posicional, não mágico.

local lastRetreat = 0

function Mission.safeSpotTick()
    if os.clock() - lastRetreat < 0.5 then return end

    local range = State.config.safeRange
    local titans = Game.getTitans()
    local root = Game.getRoot()
    if not (root and titans[1]) then return end

    -- Já estamos longe o bastante?
    local nearest = titans[1]
    if nearest.dist > range then return end

    lastRetreat = os.clock()

    -- Recua no eixo oposto ao Titã, mantendo a altura.
    local away = root.Position - nearest.root.Position
    away = Vector3.new(away.X, 0, away.Z)
    if away.Magnitude < 0.1 then
        away = Vector3.new(1, 0, 0)
    end
    away = away.Unit

    local destination = root.Position + away * State.config.safeDistance
    root.CFrame = CFrame.new(destination) * (root.CFrame - root.CFrame.Position)
end

-- ── Teleporte ao objetivo ────────────────────────────────────────────────────
-- Objetivo lido de ReplicatedStorage.Objectives: cada filho tem .Value (número)
-- e o atributo "Requirement". Não existe remote; o deslocamento é escrito
-- direto no CFrame — Humanoid:MoveTo não é usado por nenhuma fonte.

local lastObjectiveTP = 0

function Mission.findObjective()
    local rs = game:GetService("ReplicatedStorage")
    local objectives = rs:FindFirstChild("Objectives")
    if not objectives then return nil end

    local best, bestProgress = nil, -1
    for _, obj in ipairs(objectives:GetChildren()) do
        local value = obj:IsA("ValueBase") and obj.Value or nil
        local req = obj:GetAttribute("Requirement")
        if type(value) == "number" and type(req) == "number" and req > 0 then
            local progress = value / req
            if progress < 1 and progress > bestProgress then
                best, bestProgress = obj, progress
            end
        end
    end
    return best
end

function Mission.tpToObjective()
    if os.clock() - lastObjectiveTP < 1.0 then return end

    local obj = Mission.findObjective()
    if not obj then return end

    -- O ValueObject pode estar no ReplicatedStorage; a posição alvo fica no
    -- mapa. Procuramos uma parte cujo nome contenha o nome do objetivo.
    local mapName = game.PlaceId
    local root = Game.getRoot()
    if not root then return end

    local target = nil
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and string.find(string.lower(d.Name),
            string.lower(obj.Name), 1, true) then
            target = d
            break
        end
    end
    if not target then return end

    lastObjectiveTP = os.clock()
    root.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
end

-- ── Auto matar ───────────────────────────────────────────────────────────────

function Mission.shouldHold()
    if not State.flags.safeFarm then return false end
    local safeTime = State.config.safeTime
    if safeTime <= 0 then return false end

    local titans = Game.getTitans()
    if #titans > 1 then
        Mission._missionStart = Mission._missionStart or os.clock()
        return false
    end

    local elapsed = os.clock() - (Mission._missionStart or os.clock())
    return elapsed < safeTime
end

function Mission.autoKillTick()
    local titans = Game.getTitans()
    if #titans == 0 then return end

    local range = State.config.killRange
    local target
    for _, t in ipairs(titans) do
        if t.dist <= range then target = t break end
    end

    if not target then
        if State.flags.autoTPToTitan then Mission.tpToTitan() end
        return
    end

    Mission.target = target
    if Mission.shouldHold() then return end

    if os.clock() - Mission._lastStrike < State.config.strikeDelay then return end
    Mission._lastStrike = os.clock()

    if State.flags.killNape then
        local cf = Mission.napePose(target, State.config.tpOffset, 2.2)
        local root = Game.getRoot()
        if cf and root then root.CFrame = cf end
    end

    Mission.strike(target)
end

function Mission.tpToTitan()
    if os.clock() - (Mission._lastTP or 0) < State.config.tpCooldown then return end

    local titan = Game.getNearestTitan()
    if not titan or titan.dist > State.config.tpRange then return end

    local cf = Mission.napePose(titan, State.config.tpOffset, 2.2)
    local root = Game.getRoot()
    if cf and root then
        root.CFrame = cf
        Mission._lastTP = os.clock()
        Mission.target = titan
    end
end

-- ── Hitbox da nuca ───────────────────────────────────────────────────────────
-- Tamanho de fábrica confirmado: Vector3.new(15, 9, 11). Guardar o original
-- permite restaurar com precisão em vez de chutar.
-- Multiplicador validado nas fontes: 0 a 2 (máximo 120 studs).

local NAPE_FACTORY_SIZE = Vector3.new(15, 9, 11)
local expanded = {}

function Mission.expandNapes()
    local mult = State.config.napeScale
    for _, t in ipairs(Game.getTitans()) do
        local nape = t.nape
        if nape and not expanded[nape] then
            expanded[nape] = {
                size = nape.Size,
                transparency = nape.Transparency,
                color = nape.Color,
                material = nape.Material,
            }
            nape.Size = NAPE_FACTORY_SIZE * mult
            nape.Transparency = State.config.napeTransparency
            nape.Color = Theme.color.accent
            nape.Material = Enum.Material.Neon
            nape.CanCollide = false
        end
    end
end

function Mission.restoreNapes()
    for part, saved in pairs(expanded) do
        if part and part.Parent then
            pcall(function()
                part.Size = saved.size
                part.Transparency = saved.transparency
                part.Color = saved.color
                part.Material = saved.material
            end)
        end
        expanded[part] = nil
    end
end

-- Uma nuca que sai do mapa e volta deve ser re-expandida. Sem isso, o Titã
-- seguinte nasce com hitbox normal e o usuário acha que a feature parou.
function Mission.refreshExpanded()
    local live = {}
    for _, t in ipairs(Game.getTitans()) do live[t.nape] = true end

    for part in pairs(expanded) do
        if not live[part] or not part.Parent then
            expanded[part] = nil
        end
    end
    Mission.expandNapes()
end

-- ── Contagem de abates ───────────────────────────────────────────────────────

function Mission.trackKills()
    local now = os.clock()
    local seen = {}
    for _, t in ipairs(Game.getTitans()) do
        seen[t.model] = true
        local rec = Mission._tracked[t.model]
        if rec then rec.hp = t.hp; rec.seen = now
        else Mission._tracked[t.model] = { hp = t.hp, seen = now } end
    end
    for model, rec in pairs(Mission._tracked) do
        if not seen[model] then
            if (now - rec.seen) < 2 and State.flags.autoKill then
                Mission.kills = Mission.kills + 1
            end
            Mission._tracked[model] = nil
        end
    end
end

-- ── Ciclo ────────────────────────────────────────────────────────────────────

function Mission.start()
    if Mission._conn then return end
    Mission.watchGrabs()

    Mission._conn = RunService.RenderStepped:Connect(function()
        local ok, err = pcall(function()
            if State.flags.autoKill then
                Mission.autoKillTick()
            elseif State.flags.autoTPToTitan then
                Mission.tpToTitan()
            end

            if State.flags.autoReload then
                if Mission.bladeNeedsReload() then Mission.reloadBlades() end
            end

            if State.flags.safeSpot then
                Mission.safeSpotTick()
            end

            if State.flags.tpObjective then
                Mission.tpToObjective()
            end

            if State.flags.napeExpander then
                Mission.refreshExpanded()
            end

            Mission.trackKills()
        end)
        if not ok then warn("[VHub] missão: " .. tostring(err)) end
    end)
end

function Mission.stop()
    if Mission._conn then Mission._conn:Disconnect(); Mission._conn = nil end
    if escapeConn then escapeConn:Disconnect(); escapeConn = nil end
    Mission.restoreNapes()
end

function Mission.newMission()
    Mission._missionStart = os.clock()
    Mission.kills = 0
    Mission._tracked = {}
end

return Mission

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar features/mission")
return __chunk(__req)
end

-- ── features/postmission ──────────────────────────────────────
MODULES["features/postmission"] = function()
local __src = [=[
--[[
    VHub · Pós-Missão
    Arquivo: src/features/postmission.lua

    O que acontece quando a missão acaba.

    IDENTIFICADORES verificados:
      Tentar de novo : GET("Functions", "Retry", "Add")
      Voltar ao lobby: GET("Functions", "Teleport", "Lobby", nil)
                       (o nil final é um argumento posicional real, não enfeite)
      Sair em missão : POST("Functions", "Teleport")

    BAÚ DE RAID — não existe remote
    ---------------------------------
    A pesquisa foi conclusiva: não há função de rede para abrir baú. A distinção
    entre gratuito e premium é feita pelo CAMINHO do elemento na interface, e o
    botão se chama "OPEN". Portanto:

      1. procuramos um TextButton cujo texto seja "OPEN"
      2. subimos a árvore e checamos se algum ancestral tem "free" no nome
      3. acionamos esse botão

    É automação de interface — frágil por natureza. Se o jogo renomear o botão,
    para de funcionar, e o diagnóstico existe justamente para isso.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Game = __req("core/game")
local State = __req("core/state")
local Util = __req("core/util")

local Post = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

Post.lastAction = "Ocioso"
Post._lastRetry = 0
Post._lastLeave = 0
Post._lastChest = 0

-- ── Detecção de fim de missão ────────────────────────────────────────────────
-- Três sinais, em ordem de confiabilidade:
--   1. Humanoid morto — objetivo, local
--   2. GUI de resultado — a tela que o jogo mostra ao terminar
--   3. Nenhum Titã vivo com a pasta presente — fim por conclusão

local function guiShowsResult()
    local lp = Game.getLocalPlayer()
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if not pg then return nil end

    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local ok, visible = pcall(function()
                return d.Visible and (d.AbsoluteSize.X > 0 or d.AbsoluteSize.Y > 0)
            end)
            if ok and visible then
                local t = string.lower(d.Text or "")
                if string.find(t, "mission complete", 1, true)
                    or string.find(t, "missão concluída", 1, true)
                    or string.find(t, "victory", 1, true)
                    or string.find(t, "defeat", 1, true)
                    or string.find(t, "results", 1, true) then
                    return d
                end
            end
        end
    end
    return nil
end

function Post.missionEnded()
    local hum = Game.getHumanoid()
    if hum and hum.Health <= 0 then return "morto" end

    local gui = guiShowsResult()
    if gui then return "resultado" end

    if Game.hasTitans() then
        local titans = Game.getTitans()
        if #titans == 0 then return "sem_titas" end
    end

    return nil
end

-- ── Retry ────────────────────────────────────────────────────────────────────

function Post.retry()
    if os.clock() - Post._lastRetry < 4 then return end
    Post._lastRetry = os.clock()

    Game.get("Functions", "Retry", "Add")
    Post.lastAction = "Retry enviado"
end

-- ── Voltar ao lobby ──────────────────────────────────────────────────────────
-- Duas formas conforme o contexto. Em missão o POST funciona; no resultado o
-- GET com "Lobby" é o caminho.

function Post.returnToLobby()
    if os.clock() - Post._lastLeave < 5 then return end
    Post._lastLeave = os.clock()

    Game.post("Functions", "Teleport")
    task.wait(0.3)
    Game.get("Functions", "Teleport", "Lobby", nil)

    Post.lastAction = "Voltando ao lobby"
end

-- ── Baú de raid ──────────────────────────────────────────────────────────────

-- Procura um botão "OPEN" e classifica pelo caminho na interface.
local function findChestButton()
    local lp = Game.getLocalPlayer()
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if not pg then return nil end

    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("TextButton") then
            local ok, visible = pcall(function()
                return d.Visible and (d.AbsoluteSize.X > 0 or d.AbsoluteSize.Y > 0)
            end)
            if ok and visible then
                local t = string.upper(d.Text or "")
                if t == "OPEN" or t == "ABRIR" then
                    -- Sobe a árvore procurando "free" ou "premium" no caminho.
                    local path = string.lower(d:GetFullName())
                    local isFree = string.find(path, "free", 1, true) ~= nil
                    local isPremium = string.find(path, "premium", 1, true) ~= nil
                    return d, isFree, isPremium
                end
            end
        end
    end
    return nil
end

function Post.openChest()
    if os.clock() - Post._lastChest < 2 then return end

    local btn, isFree, isPremium = findChestButton()
    if not btn then return false end

    -- Só abre o que o usuário autorizou. O premium gasta recurso do jogador,
    -- então nunca é tocado sem a flag explícita.
    if isPremium and not State.flags.openPremiumChest then return false end
    if isFree and not State.flags.openFreeChest then return false end
    if not isFree and not isPremium then return false end

    Post._lastChest = os.clock()
    pcall(function() btn:Activate() end)
    Post.lastAction = "Baú aberto"
    return true
end

-- ── Reexecutar ao teleportar ─────────────────────────────────────────────────
-- Quando o jogador troca de lugar, o script morre com a sessão. Para voltar
-- sozinho é preciso re-executar o loader — o que exige que o executor suporte
-- re-injeção. Guardamos o estado e tentamos.

function Post.setupRejoin()
    local lp = Game.getLocalPlayer()
    if not lp then return end

    lp.OnTeleport:Connect(function()
        Post.lastAction = "Teleportando…"
    end)

    -- Detecta troca de lugar por mudança de PlaceId entre leituras.
    task.spawn(function()
        local lastPlace = game.PlaceId
        while true do
            task.wait(2)
            if game.PlaceId ~= lastPlace then
                lastPlace = game.PlaceId
                Post.lastAction = "Lugar mudou"
            end
        end
    end)
end

-- ── Ciclo ────────────────────────────────────────────────────────────────────

local lastCheck = 0

function Post.tick()
    if os.clock() - lastCheck < 1.5 then return end
    lastCheck = os.clock()

    -- O baú pode aparecer a qualquer momento, então é checado sempre.
    if State.flags.openFreeChest or State.flags.openPremiumChest then
        Post.openChest()
    end

    if not State.flags.autoRetry and not State.flags.autoReturnLobby then return end

    local ended = Post.missionEnded()
    if not ended then return end

    if State.flags.autoRetry then
        Post.retry()
    elseif State.flags.autoReturnLobby then
        Post.returnToLobby()
    end
end

function Post.start()
    if Post._conn then return end

    Post.setupRejoin()

    Post._conn = RunService.Heartbeat:Connect(function()
        local ok, err = pcall(Post.tick)
        if not ok then warn("[VHub] pós-missão: " .. tostring(err)) end
    end)
end

function Post.stop()
    if Post._conn then Post._conn:Disconnect(); Post._conn = nil end
end

return Post

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar features/postmission")
return __chunk(__req)
end

-- ── features/utility ──────────────────────────────────────────
MODULES["features/utility"] = function()
local __src = [=[
--[[
    VHub · Utilidades de sistema
    Arquivo: src/features/utility.lua

    O que sobra depois que combate, lobby e pós-missão foram para os próprios
    módulos: manter a sessão viva e oferecer as ações manuais avulsas.

    Mudança em relação à versão anterior: recarregar lâminas, retry e farms
    saíram daqui. Cada um foi para o módulo dono do assunto — mission, post.
    Este arquivo cuida só do que é transversal.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Game = __req("core/game")
local State = __req("core/state")
local Util = __req("core/util")

local Utility = {}

local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

-- ── Anti-AFK ─────────────────────────────────────────────────────────────────
-- O Roblox desconecta após 20 minutos de inatividade. O Idled é o gatilho
-- oficial do cliente; capturamos nele e simulamos um clique.

function Utility.setupAntiAfk()
    local lp = Game.getLocalPlayer()
    if not lp or Utility._afkConn then return end

    Utility._afkConn = lp.Idled:Connect(function()
        if not State.flags.antiAfk then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(0.1)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end)
end

-- Reforço periódico: o Idled às vezes não dispara quando o cliente acha que
-- houve input recente.
local afkAcc = 0

function Utility.antiAfkPulse()
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(0.05)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)
end

-- ── Ações manuais ────────────────────────────────────────────────────────────
-- Atalhos que o usuário dispara pelo painel, sem precisar de um ciclo ligado.

function Utility.retryNow()
    Game.get("Functions", "Retry", "Add")
    Util.notify("Missão", "Retry enviado.")
end

function Utility.leaveToLobby()
    Game.post("Functions", "Teleport")
    task.wait(0.3)
    Game.get("Functions", "Teleport", "Lobby", nil)
    Util.notify("Missão", "Voltando ao lobby.")
end

function Utility.reloadBladesNow()
    local station = Game.getRefillStation()
    Game.get("Blades", "Full_Reload", "Left", station)
    Game.get("Blades", "Full_Reload", "Right", station)
    Game.get("Blades", "Reload")
    Util.notify("Lâminas", "Recarga enviada.")
end

-- ── Informações do executor ──────────────────────────────────────────────────

function Utility.envInfo()
    return {
        executor = Util.executorName(),
        placeId = game.PlaceId,
        gameId = game.GameId,
        jobId = game.JobId,
        kind = Game.placeKind(),
        hasTitans = Game.hasTitans(),
    }
end

-- ── Ciclo ────────────────────────────────────────────────────────────────────

function Utility.start()
    Utility.setupAntiAfk()
    if Utility._conn then return end

    afkAcc = 0
    Utility._conn = RunService.Heartbeat:Connect(function(dt)
        local ok, err = pcall(function()
            if not State.flags.antiAfk then return end
            afkAcc = afkAcc + dt
            if afkAcc >= 60 then
                afkAcc = 0
                Utility.antiAfkPulse()
            end
        end)
        if not ok then warn("[VHub] utilidades: " .. tostring(err)) end
    end)
end

function Utility.stop()
    if Utility._conn then Utility._conn:Disconnect(); Utility._conn = nil end
    if Utility._afkConn then Utility._afkConn:Disconnect(); Utility._afkConn = nil end
end

return Utility

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar features/utility")
return __chunk(__req)
end

-- ── features/visuals ──────────────────────────────────────────
MODULES["features/visuals"] = function()
local __src = [=[
--[[
    AOTR · ESP (Visuals)
    Arquivo: src/features/visuals.lua

    Caixas 2D, linhas e texto projetados do espaço 3D para a tela via
    Camera:WorldToViewportPoint. Nada é parentado no Workspace, então o ESP
    não aparece para outros jogadores nem colide com nada.

    DESEMPENHO — a decisão central
    ------------------------------
    O jeito ingênuo é criar Instance novas a cada frame. Com 30 Titãs e 4
    elementos cada, isso são 120 instâncias destruídas e recriadas por frame:
    o coletor de lixo do Roblox engasga e o FPS cai.

    Aqui as instâncias são criadas UMA vez por Titã e depois só têm suas
    propriedades atualizadas. Um pool reutiliza os desenhos de Titãs que
    saíram da tela. É a diferença entre 200 FPS e 40.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Game = __req("core/game")
local State = __req("core/state")
local Util = __req("core/util")
local Theme = __req("core/theme")

local Visuals = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local _LP_cache
local function LP()
    if _LP_cache and _LP_cache.Parent then return _LP_cache end
    _LP_cache = Players.LocalPlayer
    return _LP_cache
end

local screen = nil      -- ScreenGui
local container = nil   -- Frame que segura tudo
local drawings = {}     -- [model] = { box, line, label, healthBg, healthFill, napeDot }
local pool = {}         -- desenhos livres para reuso

-- ── Construção do desenho ────────────────────────────────────────────────────
-- Cada Titã recebe um conjunto de Frames. Todos são filhos de `container` para
-- que um único Destroy limpe tudo.

local function buildDrawing()
    local d = {}

    if State.flags.espBox then
        d.box = Util.tag(Instance.new("Frame"))
        d.box.BackgroundTransparency = 1
        d.box.BorderSizePixel = 0
        d.box.ZIndex = 2
        local s = Instance.new("UIStroke")
        s.Thickness = State.config.espThickness
        s.Color = State.espColor()
        s.Parent = d.box
        d.boxStroke = s
    end

    if State.flags.espLine then
        -- linha da base da tela até o Titã: um Frame fino rotacionado.
        -- Rotation em GuiObject é barato e evita refazer o cálculo com math.atan2
        -- em coordenadas de tela já rotacionadas.
        d.line = Util.tag(Instance.new("Frame"))
        d.line.AnchorPoint = Vector2.new(0, 0.5)
        d.line.BorderSizePixel = 0
        d.line.BackgroundColor3 = State.espColor()
        d.line.ZIndex = 1
    end

    if State.flags.espText then
        d.label = Util.tag(Instance.new("TextLabel"))
        d.label.BackgroundTransparency = 1
        d.label.Font = Theme.font.bold
        d.label.TextSize = 11
        d.label.TextColor3 = Theme.color.text
        d.label.TextStrokeTransparency = 0
        d.label.TextStrokeColor3 = Color3.new(0, 0, 0)
        d.label.TextXAlignment = Enum.TextXAlignment.Center
        d.label.ZIndex = 3
    end

    if State.flags.espHealth then
        d.hpBg = Util.tag(Instance.new("Frame"))
        d.hpBg.BorderSizePixel = 0
        d.hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
        d.hpBg.ZIndex = 3

        d.hpFill = Util.tag(Instance.new("Frame"))
        d.hpFill.BorderSizePixel = 0
        d.hpFill.BackgroundColor3 = Theme.color.ok
        d.hpFill.ZIndex = 4

        d.hpText = Util.tag(Instance.new("TextLabel"))
        d.hpText.BackgroundTransparency = 1
        d.hpText.Font = Theme.font.mono
        d.hpText.TextSize = 9
        d.hpText.TextColor3 = Theme.color.text
        d.hpText.TextStrokeTransparency = 0.3
        d.hpText.ZIndex = 5
    end

    if State.flags.espNape then
        -- marcador da nuca: o alvo exato, em cor de destaque
        d.napeDot = Util.tag(Instance.new("Frame"))
        d.napeDot.BorderSizePixel = 0
        d.napeDot.BackgroundColor3 = Theme.color.accent
        d.napeDot.ZIndex = 6
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = d.napeDot
        local s = Instance.new("UIStroke")
        s.Thickness = 1.5
        s.Color = Color3.new(1, 1, 1)
        s.Transparency = 0.4
        s.Parent = d.napeDot
    end

    return d
end

local function parentDrawing(d)
    for _, k in ipairs({ "box", "line", "label", "hpBg", "hpFill", "hpText", "napeDot" }) do
        if d[k] then d[k].Parent = container end
    end
end

local function hideDrawing(d)
    for _, k in ipairs({ "box", "line", "label", "hpBg", "hpFill", "hpText", "napeDot" }) do
        if d[k] then d[k].Visible = false end
    end
end

local function acquire(model)
    if drawings[model] then
        -- reconstrói se as opções mudaram de forma incompatível
        local needsBox = State.flags.espBox
        local hasBox = drawings[model].box ~= nil
        if needsBox ~= hasBox then
            Visuals.destroyDrawing(model)
        else
            return drawings[model]
        end
    end

    local d = table.remove(pool) or buildDrawing()
    parentDrawing(d)
    drawings[model] = d
    return d
end

function Visuals.destroyDrawing(model)
    local d = drawings[model]
    if not d then return end
    hideDrawing(d)
    table.insert(pool, d)
    drawings[model] = nil
end

-- ── Projeção ─────────────────────────────────────────────────────────────────
-- Converte um ponto 3D para pixels. WorldToViewportPoint devolve (Vector3, bool):
-- o bool é false quando o ponto está ATRÁS da câmera — sem checar isso, o ESP
-- desenha caixas espelhadas de Titãs que estão nas suas costas.

local function project(pos)
    local cam = Workspace.CurrentCamera
    local v, onScreen = cam:WorldToViewportPoint(pos)
    if not onScreen or v.Z <= 0 then return nil end
    return Vector2.new(v.X, v.Y), v.Z
end

-- ── Cálculo da caixa ─────────────────────────────────────────────────────────
-- Estima a caixa 2D a partir do tamanho real do modelo, projetando os cantos.
-- Usar a altura do modelo em vez de um valor fixo faz a caixa acompanhar Titãs
-- de tamanhos diferentes — e no AOTR eles variam muito (Puro vs Colossal).

local function computeBox(titan, cam)
    local model = titan.model
    local ok, cf, size = pcall(function()
        return model:GetBoundingBox()
    end)

    if not ok then
        -- fallback: caixa em torno da raiz com tamanho padrão
        local p = titan.root.Position
        local top = project(p + Vector3.new(0, 3, 0))
        local bot = project(p - Vector3.new(0, 3, 0))
        if not (top and bot) then return nil end
        local h = math.abs(bot.Y - top.Y)
        return { x = top.X - h * 0.3, y = top.Y, w = h * 0.6, h = h }
    end

    -- os 8 cantos da bounding box em espaço de mundo
    local corners = {}
    for xi = -1, 1, 2 do
        for yi = -1, 1, 2 do
            for zi = -1, 1, 2 do
                local world = cf * Vector3.new(
                    size.X / 2 * xi, size.Y / 2 * yi, size.Z / 2 * zi)
                local scr = project(world)
                if scr then table.insert(corners, scr) end
            end
        end
    end
    if #corners < 2 then return nil end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for _, c in ipairs(corners) do
        minX = math.min(minX, c.X); maxX = math.max(maxX, c.X)
        minY = math.min(minY, c.Y); maxY = math.max(maxY, c.Y)
    end

    return { x = minX, y = minY, w = maxX - minX, h = maxY - minY }
end

-- ── Tick ─────────────────────────────────────────────────────────────────────

local cam = Workspace.CurrentCamera

function Visuals.tick()
    if not (screen and screen.Parent) then return end

    cam = Workspace.CurrentCamera
    local viewport = cam.ViewportSize
    local originX, originY = viewport.X / 2, viewport.Y

    local titans = Game.getTitans()
    local live = {}

    local color = State.espColor()
    local maxDist = State.config.espMaxDist

    for _, titan in ipairs(titans) do
        live[titan.model] = true

        -- Filtro de chefe: puros e anormais ficam de fora.
        local skip = State.flags.espBossOnly and not titan.isBoss

        if not skip and titan.dist <= maxDist then
            local box = computeBox(titan, cam)
            if box and box.w > 1 and box.h > 1 then
                local d = acquire(titan.model)

                if d.box then
                    d.box.Visible = true
                    d.box.Position = UDim2.fromOffset(box.x, box.y)
                    d.box.Size = UDim2.fromOffset(box.w, box.h)
                    d.boxStroke.Color = color
                    d.boxStroke.Thickness = State.config.espThickness
                end

                if d.line then
                    d.line.Visible = true
                    local fx, fy = box.x + box.w / 2, box.y + box.h
                    local dx, dy = fx - originX, fy - originY
                    local len = math.sqrt(dx * dx + dy * dy)
                    local ang = math.deg(math.atan2(dy, dx))
                    d.line.Position = UDim2.fromOffset(originX, originY)
                    d.line.Size = UDim2.fromOffset(len, 1)
                    d.line.Rotation = ang
                    d.line.BackgroundColor3 = color
                    d.line.BackgroundTransparency = 0.35
                end

                if d.label then
                    d.label.Visible = true
                    -- O tipo do Titã existe SÓ no nome do modelo — não há
                    -- StringValue nem atributo de variante no rig.
                    local parts = { titan.name }
                    if State.flags.espText then
                        table.insert(parts, string.format("%dm", math.floor(titan.dist)))
                    end
                    d.label.Text = table.concat(parts, "  ·  ")
                    -- Chefes em destaque; puros em tom discreto.
                    d.label.TextColor3 = titan.isBoss and Theme.color.accentHi or Theme.color.text
                    d.label.Position = UDim2.fromOffset(box.x - 30, box.y - 16)
                    d.label.Size = UDim2.fromOffset(box.w + 60, 14)
                end

                if d.hpBg and d.hpFill then
                    d.hpBg.Visible = true
                    d.hpFill.Visible = true
                    local ratio = math.clamp(titan.hp / math.max(titan.maxHp, 1), 0, 1)
                    local barW, barH = 3, box.h

                    d.hpBg.Position = UDim2.fromOffset(box.x - 7, box.y)
                    d.hpBg.Size = UDim2.fromOffset(barW, barH)
                    d.hpFill.Position = UDim2.fromOffset(box.x - 7, box.y + barH * (1 - ratio))
                    d.hpFill.Size = UDim2.fromOffset(barW, barH * ratio)

                    -- cor por faixa de vida: verde -> amarelo -> vermelho
                    local c
                    if ratio > 0.6 then c = Theme.color.ok
                    elseif ratio > 0.3 then c = Theme.color.warn
                    else c = Theme.color.danger end
                    d.hpFill.BackgroundColor3 = c

                    if d.hpText then
                        d.hpText.Visible = true
                        d.hpText.Text = Util.abbrev(titan.hp)
                        d.hpText.Position = UDim2.fromOffset(box.x - 42, box.y + box.h / 2 - 6)
                        d.hpText.Size = UDim2.fromOffset(34, 12)
                        d.hpText.TextXAlignment = Enum.TextXAlignment.Right
                    end
                end

                if d.napeDot then
                    local np = project(titan.nape.Position)
                    if np then
                        d.napeDot.Visible = true
                        d.napeDot.Position = UDim2.fromOffset(np.X - 3, np.Y - 3)
                        d.napeDot.Size = UDim2.fromOffset(6, 6)
                    else
                        d.napeDot.Visible = false
                    end
                end
            else
                local d = drawings[titan.model]
                if d then hideDrawing(d) end
            end
        else
            local d = drawings[titan.model]
            if d then hideDrawing(d) end
        end
    end

    -- Recicla desenhos de Titãs que sumiram.
    for model in pairs(drawings) do
        if not live[model] then Visuals.destroyDrawing(model) end
    end
end

-- ── Ciclo de vida ────────────────────────────────────────────────────────────

function Visuals.mount(gui)
    if not gui then
        warn("[VHub] ESP: nenhum ScreenGui recebido; o ESP ficará inativo.")
        return false
    end
    screen = gui

    container = Util.tag(Instance.new("Frame"))
    container.Name = "VHub_ESP"
    container.Size = UDim2.fromScale(1, 1)
    container.BackgroundTransparency = 1
    container.ZIndex = 0
    container.Parent = screen

    Visuals._conn = RunService.RenderStepped:Connect(function()
        if not State.flags.esp then return end
        local ok, err = pcall(Visuals.tick)
        if not ok then warn("[VHub] ESP: " .. tostring(err)) end
    end)
    return true
end

function Visuals.clear()
    for model in pairs(drawings) do Visuals.destroyDrawing(model) end
    for _, d in ipairs(pool) do
        for _, k in ipairs({ "box", "line", "label", "hpBg", "hpFill", "hpText", "napeDot" }) do
            if d[k] then d[k]:Destroy() end
        end
    end
    pool = {}
end

function Visuals.unmount()
    if Visuals._conn then Visuals._conn:Disconnect(); Visuals._conn = nil end
    Visuals.clear()
    if container then container:Destroy(); container = nil end
    screen = nil
end

return Visuals

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar features/visuals")
return __chunk(__req)
end

-- ── ui/interface ──────────────────────────────────────────────
MODULES["ui/interface"] = function()
local __src = [=[
--[[
    VHub · Interface
    Arquivo: src/ui/interface.lua

    Estrutura de abas:
      Home     — dashboard: identidade, estatísticas ao vivo, jogo atual
      Missões  — combate (só faz sentido em campo)
      Lobby    — criação de missão e progressão (só no lobby)
      Visual   — ESP
      Config   — sistema, persistência, diagnóstico

    O logo do VHub aparece em dois lugares: pequeno no cabeçalho (marca) e
    grande na Home (destaque). O arquivo é hospedado junto ao script.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Theme = __req("core/theme")
local Widget = __req("core/widget")
local State = __req("core/state")
local Util = __req("core/util")
local Game = __req("core/game")
local Stats = __req("core/stats")
local Layout = __req("core/layout")

local UI = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- ── Assets ───────────────────────────────────────────────────────────────────
-- Hospedados no mesmo repositório do script. Se falharem, a UI funciona sem
-- eles — nenhum ImageLabel quebra a montagem.
local ASSET_BASE = "https://raw.githubusercontent.com/ViegasAgro123/VHub/main/assets"
UI.LOGO = ASSET_BASE .. "/vhub-logo.png"
UI.LOGO_LG = ASSET_BASE .. "/vhub-logo-lg.png"

local gui, root, sidebar, content, statusBar
local tabs = {}
local pages = {}
local activeTab = "home"
local minimized = false
local toasts = {}
local statCards = {}

-- Registro dos controles para o rebuild após carregar configuração.
-- Precisa existir ANTES dos builders rodarem — eles escrevem aqui.
UI.controls = {}
UI.VERSION = "2.0.0"

-- ── Definição das abas ───────────────────────────────────────────────────────

local TABS = {
    { key = "home",    label = "Home",    icon = "⌂" },
    { key = "missoes", label = "Missões", icon = "⚔" },
    { key = "lobby",   label = "Lobby",   icon = "⌸" },
    { key = "visual",  label = "Visual",  icon = "◉" },
    { key = "config",  label = "Config",  icon = "⚙" },
}

local GROUP = {
    missaoTitas = {
        "autoKill", "autoReload", "autoEscape", "autoTPToTitan",
    },
    missaoMov = {
        "safeSpot", "tpObjective",
    },
    missaoNuca = {
        "napeExpander", "showNape",
    },
    posMissao = {
        "autoRetry", "autoReturnLobby", "openFreeChest", "openPremiumChest",
    },
    lobbyMissao = {
        "autoStart", "preferBoosted",
    },
    lobbyMelhoria = {
        "autoUpgrade", "autoSkills",
    },
    visual = {
        "esp", "espBox", "espLine", "espText", "espHealth", "espNape", "espBossOnly",
    },
    sistema = {
        "antiAfk", "watermark", "notifications", "safeFarm",
    },
}

-- ── Construção da janela ─────────────────────────────────────────────────────

local function buildRoot()
    gui = Instance.new("ScreenGui")
    gui.Name = "VHub_UI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
    if not gui.Parent then
        gui.Parent = game:GetService("CoreGui")
    end

    root = Widget.new("Frame", {
        Name = "Root",
        Size = UDim2.fromOffset(Theme.metric.winW, Theme.metric.winH),
        Position = UDim2.new(0.5, -Theme.metric.winW / 2, 0.5, -Theme.metric.winH / 2),
        BackgroundColor3 = Theme.color.base,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = gui,
    })
    Theme.corner(root, Theme.metric.radius + 3)
    Theme.stroke(root, Theme.color.lineHot)

    local base = Widget.new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = root,
    })
    Theme.corner(base, Theme.metric.radius + 3)
    Theme.gradientBase(base)

    -- Brilho vermelho no topo: dá calor à identidade sem poluir o conteúdo.
    local glow = Widget.new("Frame", {
        Size = UDim2.new(1, 0, 0, 130),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = root,
    })
    Theme.corner(glow, Theme.metric.radius + 3)
    Theme.gradientGlow(glow)
end

local function buildHeader()
    local head = Widget.new("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, Theme.metric.headH),
        BackgroundColor3 = Theme.color.surfaceTop,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = root,
    })
    Theme.pad(head, 0, Theme.metric.pad + 2, 0)

    -- Logo pequeno: marca no canto, como um app.
    local logo = Widget.new("ImageLabel", {
        Name = "Logo",
        Size = UDim2.fromOffset(46, 46),
        Position = UDim2.new(0, 0, 0.5, -23),
        BackgroundTransparency = 1,
        Image = UI.LOGO,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 4,
        Parent = head,
    })
    UI.headerLogo = logo

    Widget.label({
        parent = head,
        text = "VHub",
        position = UDim2.new(0, 54, 0, 12),
        size = UDim2.fromOffset(120, 20),
        textSize = Theme.text.title,
        font = Theme.font.black,
        zindex = 4,
    })

    local subtitle = Widget.label({
        parent = head,
        text = "…",
        position = UDim2.new(0, 54, 0, 32),
        size = UDim2.fromOffset(280, 15),
        textSize = Theme.text.tiny,
        color = Theme.color.textMute,
        zindex = 4,
    })
    UI.headerSub = subtitle

    -- Estatísticas compactas no cabeçalho
    UI.headerStats = Widget.label({
        parent = head,
        text = "",
        position = UDim2.new(1, -300 - 76, 0.5, -8),
        size = UDim2.fromOffset(300, 16),
        textSize = Theme.text.tiny,
        font = Theme.font.mono,
        color = Theme.color.textMute,
        align = Enum.TextXAlignment.Right,
        zindex = 4,
    })

    -- Minimizar
    local min = Widget.new("TextButton", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -64, 0.5, -14),
        BackgroundColor3 = Theme.color.surface,
        BackgroundTransparency = 1,
        Text = "—",
        TextColor3 = Theme.color.textDim,
        TextSize = 15,
        Font = Theme.font.bold,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = head,
    })
    Theme.corner(min, 6)
    min.MouseEnter:Connect(function()
        Widget.tween(min, Theme.ease.fast, { BackgroundTransparency = 0, TextColor3 = Theme.color.accentHi })
    end)
    min.MouseLeave:Connect(function()
        Widget.tween(min, Theme.ease.fast, { BackgroundTransparency = 1, TextColor3 = Theme.color.textDim })
    end)
    min.MouseButton1Click:Connect(function() UI.setMinimized(not minimized) end)

    -- Fechar
    local close = Widget.new("TextButton", {
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -32, 0.5, -14),
        BackgroundColor3 = Theme.color.surface,
        BackgroundTransparency = 1,
        Text = "✕",
        TextColor3 = Theme.color.textDim,
        TextSize = 14,
        Font = Theme.font.bold,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = head,
    })
    Theme.corner(close, 6)
    close.MouseEnter:Connect(function()
        Widget.tween(close, Theme.ease.fast, {
            BackgroundTransparency = 0, BackgroundColor3 = Theme.color.danger,
            TextColor3 = Color3.new(1, 1, 1) })
    end)
    close.MouseLeave:Connect(function()
        Widget.tween(close, Theme.ease.fast, {
            BackgroundTransparency = 1, BackgroundColor3 = Theme.color.surface,
            TextColor3 = Theme.color.textDim })
    end)
    close.MouseButton1Click:Connect(function() UI.setVisible(false) end)

    -- Arrasto
    local dragging, dragStart, startPos
    head.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = root.Position
        end
    end)
    head.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            root.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local function buildSidebar()
    sidebar = Widget.new("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, Theme.metric.sidebarW, 1, -(Theme.metric.headH + 26)),
        Position = UDim2.new(0, 0, 0, Theme.metric.headH),
        BackgroundColor3 = Theme.color.void,
        BackgroundTransparency = 0.42,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = root,
    })
    Widget.new("UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = sidebar,
    })
    Theme.pad(sidebar, 0, 9, 9)

    for i, def in ipairs(TABS) do
        local btn = Widget.new("TextButton", {
            Name = def.key,
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Theme.color.surface,
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = i,
            ZIndex = 4,
            Parent = sidebar,
        })
        Theme.corner(btn, Theme.metric.radiusSm)

        local bar = Widget.new("Frame", {
            Size = UDim2.new(0, 3, 0, 0),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Theme.color.accent,
            BorderSizePixel = 0,
            ZIndex = 6,
            Parent = btn,
        })
        Theme.corner(bar, 2)

        local ic = Widget.label({
            parent = btn,
            text = def.icon,
            position = UDim2.new(0, 12, 0.5, -10),
            size = UDim2.fromOffset(20, 20),
            textSize = 15,
            color = Theme.color.textMute,
            zindex = 5,
        })

        local lb = Widget.label({
            parent = btn,
            text = def.label,
            position = UDim2.new(0, 38, 0, 0),
            size = UDim2.new(1, -44, 1, 0),
            textSize = Theme.text.label,
            font = Theme.font.medium,
            color = Theme.color.textMute,
            zindex = 5,
        })

        tabs[def.key] = { btn = btn, bar = bar, icon = ic, label = lb }

        btn.MouseEnter:Connect(function()
            if activeTab ~= def.key then
                Widget.tween(btn, Theme.ease.fast, { BackgroundTransparency = 0.35 })
                Widget.tween(lb, Theme.ease.fast, { TextColor3 = Theme.color.textDim })
            end
        end)
        btn.MouseLeave:Connect(function()
            if activeTab ~= def.key then
                Widget.tween(btn, Theme.ease.fast, { BackgroundTransparency = 1 })
                Widget.tween(lb, Theme.ease.fast, { TextColor3 = Theme.color.textMute })
            end
        end)
        btn.MouseButton1Click:Connect(function() UI.selectTab(def.key) end)
    end
end

local function buildContent()
    content = Widget.new("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -Theme.metric.sidebarW - 1, 1, -(Theme.metric.headH + 26)),
        Position = UDim2.new(0, Theme.metric.sidebarW, 0, Theme.metric.headH),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 3,
        Parent = root,
    })

    UI.scroll = Widget.new("ScrollingFrame", {
        Name = "Scroll",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = Theme.metric.scrollW,
        ScrollBarImageColor3 = Theme.color.line,
        ScrollBarImageTransparency = 0.25,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 3,
        Parent = content,
    })
    Theme.pad(UI.scroll, 0, Theme.metric.pad + 2, Theme.metric.pad)

    Widget.new("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = UI.scroll,
    })
end

local function buildStatusBar()
    statusBar = Widget.new("Frame", {
        Name = "StatusBar",
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.new(0, 0, 1, -26),
        BackgroundColor3 = Theme.color.surfaceTop,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = root,
    })
    Theme.pad(statusBar, 0, Theme.metric.pad + 2, 0)

    local dot = Widget.new("Frame", {
        Size = UDim2.fromOffset(7, 7),
        Position = UDim2.new(0, 0, 0.5, -3.5),
        BackgroundColor3 = Theme.color.ok,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = statusBar,
    })
    Theme.corner(dot, 4)
    UI.statusDot = dot

    UI.statusText = Widget.label({
        parent = statusBar,
        text = "Pronto",
        position = UDim2.new(0, 14, 0, 0),
        size = UDim2.new(1, -160, 1, 0),
        textSize = Theme.text.tiny,
        color = Theme.color.textMute,
        zindex = 5,
    })

    Widget.label({
        parent = statusBar,
        text = "RightCtrl · ocultar",
        position = UDim2.new(1, -140, 0, 0),
        size = UDim2.fromOffset(140, 26),
        textSize = Theme.text.tiny,
        font = Theme.font.mono,
        color = Theme.color.textMute,
        align = Enum.TextXAlignment.Right,
        zindex = 5,
    })
end

-- ── Construtores de linha ────────────────────────────────────────────────────
-- Encurtam a declaração das páginas e garantem que todo controle novo entre
-- registrado em UI.controls para o rebuild.

local function addToggle(section, order, flag, text, sub, onChange)
    local w = Widget.toggle({
        parent = section.body,
        text = text,
        sub = sub,
        default = State.flags[flag],
        size = UDim2.new(1, 0, 0, sub and 42 or 34),
        onChange = function(v)
            State.set(flag, v)
            if onChange then onChange(v) end
        end,
    })
    w.instance.LayoutOrder = order
    UI.controls[flag] = w
    return w
end

local function addSlider(section, order, key, text, min, max, suffix, decimals, onChange)
    local w = Widget.slider({
        parent = section.body,
        text = text,
        min = min, max = max,
        default = State.config[key],
        suffix = suffix, decimals = decimals,
        onChange = function(v)
            State.config[key] = v
            if onChange then onChange(v) end
        end,
    })
    w.instance.LayoutOrder = order
    UI.controls[key] = w
    return w
end

local function addDropdown(section, order, key, text, options, onChange)
    local w = Widget.dropdown({
        parent = section.body,
        text = text,
        options = options,
        default = State.config[key],
        onChange = function(v)
            State.config[key] = v
            if onChange then onChange(v) end
        end,
    })
    w.instance.LayoutOrder = order
    UI.controls[key] = w
    return w
end

local function addButton(section, order, text, variant, onClick)
    local w = Widget.button({
        parent = section.body,
        text = text,
        variant = variant or "ghost",
        size = UDim2.new(1, 0, 0, 32),
        onClick = onClick,
    })
    w.instance.LayoutOrder = order
    return w
end

local function addInfo(section, order, text, danger)
    local w = Widget.info({ parent = section.body, text = text, order = order, danger = danger })
    return w
end

-- ── Página: Home ─────────────────────────────────────────────────────────────

local function buildHome()
    local page = Widget.new("Frame", {
        Name = "home",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = UI.scroll,
    })
    Widget.new("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page,
    })

    -- ── Cartão de identidade
    local id = Widget.new("Frame", {
        Size = UDim2.new(1, 0, 0, 108),
        BackgroundColor3 = Theme.color.card,
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Parent = page,
    })
    Theme.corner(id, Theme.metric.radius)
    Theme.stroke(id, Theme.color.lineSoft)
    Theme.pad(id, 0, 16, 14)

    -- gradiente sutil no cartão, para diferenciá-lo das seções abaixo
    local idBg = Widget.new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.86,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = id,
    })
    Theme.corner(idBg, Theme.metric.radius)
    Theme.gradientGlow(idBg)

    local av = Widget.avatar({ parent = id, image = "", size = Theme.metric.avatar, position = UDim2.new(0, 0, 0, 8) })
    av.instance.ZIndex = 4
    av.instance.Position = UDim2.new(0, 0, 0.5, -Theme.metric.avatar / 2)
    UI.avatar = av

    UI.heroName = Widget.label({
        parent = id,
        text = "Carregando…",
        position = UDim2.new(0, Theme.metric.avatar + 16, 0, 20),
        size = UDim2.new(1, -(Theme.metric.avatar + 30), 0, 32),
        textSize = Theme.text.heroName,
        font = Theme.font.black,
        zindex = 4,
    })

    UI.heroSub = Widget.label({
        parent = id,
        text = "",
        position = UDim2.new(0, Theme.metric.avatar + 17, 0, 52),
        size = UDim2.new(1, -(Theme.metric.avatar + 30), 0, 18),
        textSize = Theme.text.heroSub,
        color = Theme.color.textMute,
        zindex = 4,
    })

    UI.heroPlace = Widget.label({
        parent = id,
        text = "",
        position = UDim2.new(0, Theme.metric.avatar + 17, 0, 72),
        size = UDim2.new(1, -(Theme.metric.avatar + 30), 0, 16),
        textSize = Theme.text.tiny,
        color = Theme.color.accentHi,
        font = Theme.font.medium,
        zindex = 4,
    })

    -- ── Estatísticas ao vivo
    local statsSec = Widget.section({ parent = page, text = "Ao vivo" })
    statsSec.instance.LayoutOrder = 2

    -- Grade automática: 5 cartões em 143px fixos somavam 747px dentro de ~460px
    -- úteis. Agora quebram em linhas e o container cresce junto.
    local grid = Layout.autoGrid({
        parent = statsSec.body,
        minCell = 140,
        cellHeight = Theme.metric.statCardH,
        gap = 8,
        name = "StatGrid",
    })

    local defs = {
        { key = "players",  caption = "Jogadores" },
        { key = "friends",  caption = "Amigos aqui" },
        { key = "session",  caption = "Na sessão" },
        { key = "fps",      caption = "FPS" },
        { key = "ping",     caption = "Ping" },
    }
    for i, d in ipairs(defs) do
        local card = Widget.statCard({
            parent = grid.instance,
            caption = d.caption,
            value = "—",
        })
        card.instance.LayoutOrder = i
        statCards[d.key] = card
    end

    -- ── Jogo atual
    local gameSec = Widget.section({ parent = page, text = "Jogo" })
    gameSec.instance.LayoutOrder = 3

    local gameCard = Widget.new("Frame", {
        Size = UDim2.new(1, 0, 0, 76),
        BackgroundColor3 = Theme.color.card,
        BorderSizePixel = 0,
        Parent = gameSec.body,
    })
    Theme.corner(gameCard, Theme.metric.radius)
    Theme.stroke(gameCard, Theme.color.lineSoft)
    Theme.pad(gameCard, 0, 14, 12)

    UI.gameLogo = Widget.new("ImageLabel", {
        Size = UDim2.fromOffset(52, 52),
        Position = UDim2.new(0, 0, 0.5, -26),
        BackgroundTransparency = 1,
        Image = UI.LOGO,
        ScaleType = Enum.ScaleType.Fit,
        Parent = gameCard,
    })

    UI.gameName = Widget.label({
        parent = gameCard,
        text = "Attack on Titan Revolution",
        position = UDim2.new(0, 64, 0, 6),
        size = UDim2.new(1, -74, 0, 22),
        textSize = 18,
        font = Theme.font.bold,
    })

    UI.gameMeta = Widget.label({
        parent = gameCard,
        text = "",
        position = UDim2.new(0, 64, 0, 30),
        size = UDim2.new(1, -74, 0, 16),
        textSize = Theme.text.sub,
        color = Theme.color.textMute,
    })

    UI.gamePlace = Widget.label({
        parent = gameCard,
        text = "",
        position = UDim2.new(0, 64, 0, 46),
        size = UDim2.new(1, -74, 0, 15),
        textSize = Theme.text.tiny,
        color = Theme.color.accentHi,
        font = Theme.font.mono,
    })

    -- ── Comunidade
    local commSec = Widget.section({ parent = page, text = "Comunidade" })
    commSec.instance.LayoutOrder = 4
    addInfo(commSec, 1,
        "Comunidade do VHub em breve. Aqui vai ficar o convite, o status do serviço e as novidades.")

    pages.home = { frame = page }
end

-- ── Página: Missões ──────────────────────────────────────────────────────────

local function buildMissoes()
    local page = Widget.new("Frame", {
        Name = "missoes",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = UI.scroll,
    })
    Widget.new("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page,
    })

    -- ── Titãs
    local titas = Widget.section({ parent = page, text = "Titãs" })
    titas.instance.LayoutOrder = 1
    addToggle(titas, 1, "autoKill", "Matar Titãs automaticamente",
        "Ataca sozinho os Titãs no alcance")
    addToggle(titas, 2, "killNape", "Mirar na nuca",
        "Registra o golpe na hitbox crítica")
    addToggle(titas, 3, "autoReload", "Recarregar lâminas automaticamente",
        "Troca a lâmina quando quebra")
    addToggle(titas, 4, "autoEscape", "Escapar de agarrões automaticamente",
        "Sai do agarrão assim que o Titã pega")
    addToggle(titas, 5, "autoTPToTitan", "Teleportar ao Titã mais próximo")
    addSlider(titas, 6, "killRange", "Alcance do ataque", 5, 150, " studs")
    addSlider(titas, 7, "strikeDelay", "Intervalo entre golpes", 0.05, 1, "s", 2)
    addInfo(titas, 8,
        "O alcance real da lâmina é curto. Valores altos dependem da magnitude estendida em Config.")

    -- ── Movimento
    local mov = Widget.section({ parent = page, text = "Movimento" })
    mov.instance.LayoutOrder = 2
    addToggle(mov, 1, "safeSpot", "Local seguro",
        "Recua quando um Titã chega perto de você")
    addToggle(mov, 2, "tpObjective", "Teleportar ao objetivo",
        "Vai até o alvo da missão")
    addSlider(mov, 3, "safeRange", "Distância de alerta", 15, 120, " studs")
    addSlider(mov, 4, "safeDistance", "Recuo", 10, 80, " studs")
    addInfo(mov, 5,
        "O jogo não tem zona segura própria — este recuo é posicional, feito pelo script.")

    -- ── Nuca
    local nuca = Widget.section({ parent = page, text = "Hitbox da Nuca" })
    nuca.instance.LayoutOrder = 3
    addToggle(nuca, 1, "napeExpander", "Expansor de hitbox",
        "Aumenta a nuca para facilitar o acerto")
    addToggle(nuca, 2, "showNape", "Mostrar a nuca",
        "Deixa visível em vermelho")
    addSlider(nuca, 3, "napeScale", "Tamanho", 0, 2, "x", 1)
    addSlider(nuca, 4, "napeTransparency", "Transparência", 0, 1, "", 2)
    addInfo(nuca, 5,
        "Tamanho de fábrica da nuca: 15 × 9 × 11. O multiplicador é aplicado sobre ele e restaurado ao desligar.")

    -- ── Pós-missão
    local pos = Widget.section({ parent = page, text = "Painel de Pós-Missão" })
    pos.instance.LayoutOrder = 4
    addToggle(pos, 1, "autoRetry", "Tentar novamente automático",
        "Reinicia a missão assim que acaba")
    addToggle(pos, 2, "autoReturnLobby", "Retornar ao saguão automático")
    addToggle(pos, 3, "openFreeChest", "Abrir baú de raid grátis",
        "Aciona o botão OPEN do baú gratuito")
    addToggle(pos, 4, "openPremiumChest", "Abrir baú premium",
        "Gasta recurso da conta — deixe desligado se não tiver certeza")
    addInfo(pos, 5,
        "O baú é aberto por automação de interface: o jogo não expõe função de rede para isso.",
        true)

    -- ── Segurança
    local saf = Widget.section({ parent = page, text = "Segurança" })
    saf.instance.LayoutOrder = 5
    addToggle(saf, 1, "safeFarm", "Modo Seguro",
        "Segura a missão pelo tempo mínimo, evitando detecção por velocidade")
    addSlider(saf, 2, "safeTime", "Tempo mínimo", 0, 90, "s")
    addInfo(saf, 3,
        "O gatilho de shadow ban relatado é concluir missões rápido demais. Com o Modo Seguro ligado, o script não mata o último Titã antes do tempo.")

    pages.missoes = { frame = page }
end

-- ── Página: Lobby ────────────────────────────────────────────────────────────

local function buildLobby()
    local page = Widget.new("Frame", {
        Name = "lobby",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = UI.scroll,
    })
    Widget.new("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page,
    })

    -- ── Missões
    local mis = Widget.section({ parent = page, text = "Missões" })
    mis.instance.LayoutOrder = 1
    addToggle(mis, 1, "autoStart", "Iniciar automático",
        "Cria a sala com as opções abaixo e entra")
    addToggle(mis, 2, "preferBoosted", "Preferir mapa com bônus",
        "Escolhe o mapa com bônus ativo quando houver")
    addDropdown(mis, 3, "missionType", "Modo", { "Missions", "Raids", "Waves" })
    addDropdown(mis, 4, "mapName", "Mapa", {
        "Automático", "Shiganshina", "Trost", "Outskirts", "Forest",
        "Utgard", "Docks", "Stohess", "Chapel",
    })
    addDropdown(mis, 5, "objective", "Objetivo", { "Skirmish", "Waves" })
    addDropdown(mis, 6, "difficulty", "Dificuldade",
        { "Easy", "Normal", "Hard", "Severe", "Aberrant" })
    addDropdown(mis, 7, "raid", "Titã (modo Raids)",
        { "Attack Titan", "Armored Titan", "Female Titan", "Colossal Titan" })

    local modChips = Widget.chips({
        parent = mis.body,
        text = "Modificadores",
        options = {
            "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball",
            "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon",
            "Time Trial", "Boring", "Simple",
        },
        default = State.config.modifiers,
        onChange = function(list) State.config.modifiers = list end,
    })
    modChips.instance.LayoutOrder = 8
    UI.controls.modifiers = modChips

    addButton(mis, 9, "Criar e iniciar agora", "solid", function()
        if not Lobby_ref then
            UI.notify("Lobby", "Módulo de lobby ainda não carregou.", 4)
            return
        end
        Lobby_ref.leaveMission()
        task.spawn(function()
            task.wait(0.6)
            Lobby_ref.createMission()
            task.wait(0.6)
            Lobby_ref.modifyModifiers()
            task.wait(0.6)
            Lobby_ref.startMission()
        end)
    end)

    addInfo(mis, 10,
        "Alguns modos restringem as opções: Waves só existe em Trost na dificuldade Easy, e o Colossal Titan exige Aberrant com mínimo de 3 jogadores.")

    -- ── Melhorias
    local mel = Widget.section({ parent = page, text = "Melhorias" })
    mel.instance.LayoutOrder = 2
    addToggle(mel, 1, "autoUpgrade", "Melhorar atributos automaticamente",
        "Gasta os pontos disponíveis")
    addToggle(mel, 2, "autoSkills", "Desbloquear árvore de habilidades",
        "Sobe as três trilhas automaticamente")
    addDropdown(mel, 3, "skillLeft", "Trilha esquerda", { "Regen VI", "Injury III" })
    addDropdown(mel, 4, "skillMiddle", "Trilha central", { "Damage V", "Crit Damage V" })
    addDropdown(mel, 5, "skillRight", "Trilha direita", { "Tank VIII", "Health XI" })

    pages.lobby = { frame = page }
end

-- ── Página: Visual ───────────────────────────────────────────────────────────

local function buildVisual()
    local page = Widget.new("Frame", {
        Name = "visual",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = UI.scroll,
    })
    Widget.new("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page,
    })

    local esp = Widget.section({ parent = page, text = "Titan ESP" })
    esp.instance.LayoutOrder = 1
    addToggle(esp, 1, "esp", "Ativar ESP", "Mostra os Titãs através das paredes")
    addToggle(esp, 2, "espBox", "Caixa")
    addToggle(esp, 3, "espLine", "Linha de rastreio")
    addToggle(esp, 4, "espText", "Nome e distância")
    addToggle(esp, 5, "espHealth", "Barra de vida")
    addToggle(esp, 6, "espNape", "Marcar a nuca")
    addToggle(esp, 7, "espBossOnly", "Somente chefes", "Esconde os Titãs puros")
    addDropdown(esp, 8, "espColor", "Cor", {
        "Vermelho", "Branco", "Verde", "Azul", "Amarelo", "Rosa", "Ciano" })
    addSlider(esp, 9, "espMaxDist", "Distância máxima", 100, 2000, " studs")
    addSlider(esp, 10, "espThickness", "Espessura", 1, 4, "", 1)

    pages.visual = { frame = page }
end

-- ── Página: Config ───────────────────────────────────────────────────────────

local function buildConfig()
    local page = Widget.new("Frame", {
        Name = "config",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = UI.scroll,
    })
    Widget.new("UIListLayout", {
        Padding = UDim.new(0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page,
    })

    local sis = Widget.section({ parent = page, text = "Sistema" })
    sis.instance.LayoutOrder = 1
    addToggle(sis, 1, "antiAfk", "Anti-AFK", "Impede a desconexão por inatividade")
    addToggle(sis, 2, "watermark", "Marca d'água")
    addToggle(sis, 3, "notifications", "Notificações")

    local av = Widget.section({ parent = page, text = "Avançado" })
    av.instance.LayoutOrder = 2
    addSlider(av, 1, "hitMagnitude", "Magnitude do acerto", 5, 250, "", 0)
    addSlider(av, 2, "hitOffset", "Offset do acerto", 0, 100, "", 0)
    addInfo(av, 3,
        "A magnitude declara a distância do golpe em studs. O padrão 12 é o comprimento aproximado da lâmina. Valores acima de 150 são fisicamente impossíveis e o sinal mais fácil do servidor auditar.",
        true)

    local dados = Widget.section({ parent = page, text = "Dados" })
    dados.instance.LayoutOrder = 3
    addButton(dados, 1, "Salvar configuração", "ghost", function()
        if State.save() then UI.notify("Configuração", "Salvo com sucesso.")
        else UI.notify("Configuração", "Seu executor não permite salvar arquivos.", 4) end
    end)
    addButton(dados, 2, "Carregar configuração", "ghost", function()
        if State.load() then
            UI.rebuild()
            UI.notify("Configuração", "Carregada.")
        else
            UI.notify("Configuração", "Nenhum arquivo encontrado.", 4)
        end
    end)
    addButton(dados, 3, "Diagnóstico do jogo", "solid", function() UI.showDiagnostic() end)
    addButton(dados, 4, "Checar marcação da conta", "danger", function() UI.checkFlag() end)

    local sobre = Widget.section({ parent = page, text = "Sobre" })
    sobre.instance.LayoutOrder = 4
    -- game.GameId pode faltar em ambientes restritos; formatar com nil
    -- derrubaria a construção inteira da página.
    addInfo(sobre, 1,
        ("VHub v%s · Attack on Titan Revolution\nPlaceId %s · universo %s\nExecutor: %s"):format(
            tostring(UI.VERSION or "2.0.0"),
            tostring(game.PlaceId),
            tostring(game.GameId or "?"),
            tostring(Util.executorName())))

    pages.config = { frame = page }
end

-- ── Notificações ─────────────────────────────────────────────────────────────

local toastHolder

function UI.notify(title, text, duration)
    if not (State.flags.notifications and toastHolder) then return end
    duration = duration or 3

    local card = Widget.new("Frame", {
        Size = UDim2.fromOffset(280, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.color.surfaceTop,
        BorderSizePixel = 0,
        ZIndex = 60,
        Parent = toastHolder,
    })
    Theme.corner(card, Theme.metric.radiusSm)
    Theme.stroke(card, Theme.color.lineHot)
    Theme.pad(card, 0, 12, 9)

    local accent = Widget.new("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = Theme.color.accent,
        BorderSizePixel = 0,
        ZIndex = 61,
        Parent = card,
    })
    Theme.corner(accent, 2)

    local stack = Widget.new("Frame", {
        Size = UDim2.new(1, -8, 0, 0),
        Position = UDim2.new(0, 8, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = card,
    })
    Widget.new("UIListLayout", { Padding = UDim.new(0, 3), Parent = stack })

    Widget.label({
        parent = stack, text = title,
        size = UDim2.new(1, 0, 0, 15),
        textSize = Theme.text.label, font = Theme.font.bold,
        color = Theme.color.accentHi,
    })
    Widget.label({
        parent = stack, text = text,
        size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        textSize = Theme.text.sub, color = Theme.color.textDim,
        wrapped = true, valign = Enum.TextYAlignment.Top,
    })

    local life = Widget.new("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = Theme.color.accent,
        BorderSizePixel = 0,
        ZIndex = 61,
        Parent = card,
    })

    card.Position = UDim2.new(1, 24, 1, 0)
    Widget.tween(card, Theme.ease.out, { Position = UDim2.new(1, -292, 1, -10 - #toasts * 68) })
    Widget.tween(life, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })

    table.insert(toasts, card)
    task.delay(duration, function()
        Widget.tween(card, Theme.ease.fast, { Position = UDim2.new(1, 24, 1, 0) })
        task.wait(0.15)
        for i, c in ipairs(toasts) do if c == card then table.remove(toasts, i) break end end
        card:Destroy()
    end)
end

Util._onNotify = UI.notify

-- ── Diagnóstico ──────────────────────────────────────────────────────────────

local PLACE_NAMES = {
    principal = "Menu principal",
    lobby = "Lobby",
    campo = "Campo de missão",
    desconhecido = "Desconhecido",
}

function UI.showDiagnostic()
    local r = Game.diagnose()
    local lines = {
        ("Lugar: %s (%s)"):format(PLACE_NAMES[r.placeKind] or "?", tostring(r.placeId)),
        ("Universo: %s"):format(r.isAOTR and "AOTR confirmado" or "NÃO é o AOTR"),
        ("Remotes: %s"):format(r.remotesFound and "ok" or "AUSENTES"),
        ("Pasta de Titãs: %s"):format(r.hasTitanFolder and "presente" or "ausente aqui"),
        ("Titãs vivos: %s"):format(tostring(r.titanCount)),
    }
    if r.sampleTitan then
        table.insert(lines, ("Exemplo: %s [%s]"):format(r.sampleTitan, r.sampleKind or "?"))
        table.insert(lines, ("Nuca: %s"):format(r.sampleNape or "não encontrada"))
    end
    table.insert(lines, ("Nível: %s  Prestígio: %s  Refills: %s"):format(
        tostring(r.level), tostring(r.prestige), tostring(r.refills)))
    table.insert(lines, ("Exploiter: %s  Blacklisted: %s"):format(
        tostring(r.flagged), tostring(r.blacklisted)))

    UI.notify("Diagnóstico", table.concat(lines, "\n"), 12)
    print("[VHub] Diagnóstico:")
    for _, l in ipairs(lines) do print("  " .. l) end
end

function UI.checkFlag()
    local exploiter, blacklisted = Game.isFlagged()
    if blacklisted then
        UI.notify("Conta Marcada",
            "BLACKLISTED ativo nesta conta. Pare de usar o script.", 12)
    elseif exploiter then
        UI.notify("Atenção",
            "A bandeira EXPLOITER está ativa. Reduza o uso.", 10)
    else
        UI.notify("Conta Limpa", "Nenhuma marcação ativa.", 5)
    end
end

-- ── Abas e visibilidade ──────────────────────────────────────────────────────

function UI.selectTab(key)
    if not tabs[key] then return end
    activeTab = key

    for k, t in pairs(tabs) do
        local on = (k == key)
        Widget.tween(t.bar, Theme.ease.out, {
            Size = on and UDim2.new(0, 3, 0, 20) or UDim2.new(0, 3, 0, 0),
        })
        Widget.tween(t.btn, Theme.ease.fast, { BackgroundTransparency = on and 0 or 1 })
        Widget.tween(t.icon, Theme.ease.fast, {
            TextColor3 = on and Theme.color.accent or Theme.color.textMute })
        Widget.tween(t.label, Theme.ease.fast, {
            TextColor3 = on and Theme.color.text or Theme.color.textMute })
    end

    for k, p in pairs(pages) do p.frame.Visible = (k == key) end
    if UI.scroll then UI.scroll.CanvasPosition = Vector2.new(0, 0) end
end

function UI.setMinimized(v)
    minimized = v
    local target = v and 58 or Theme.metric.winH
    Widget.tween(root, Theme.ease.out, { Size = UDim2.fromOffset(Theme.metric.winW, target) })
    if sidebar then sidebar.Visible = not v end
    if content then content.Visible = not v end
    if statusBar then statusBar.Visible = not v end
end

function UI.setVisible(v)
    if gui then gui.Enabled = v end
end

function UI.isVisible()
    return gui and gui.Enabled
end

function UI.setStatus(text)
    if UI.statusText then UI.statusText.Text = text or "Pronto" end
end

function UI.rebuild()
    for key, w in pairs(UI.controls) do
        if w.set then
            local v = State.flags[key]
            if v == nil then v = State.config[key] end
            if v ~= nil then pcall(function() w:set(v) end) end
        end
    end
end

-- ── Atualização ao vivo ──────────────────────────────────────────────────────

local function refreshLoop()
    task.spawn(function()
        -- Identidade: uma vez só, não muda durante a sessão.
        local info = Stats.playerInfo()
        if info then
            UI.heroName.Text = info.display or info.name
            UI.heroSub.Text = ("@%s · conta de %d dias"):format(info.name, info.accountAge or 0)
            if info.avatar then UI.avatar:set(info.avatar) end
        end

        local last = os.clock()
        while gui and gui.Parent do
            local now = os.clock()
            local dt = now - last
            last = now

            pcall(function()
                local snap = Stats.snapshot()

                -- Cartões
                if statCards.players then
                    statCards.players:set(("%s/%s"):format(
                        tostring(snap.serverPlayers), tostring(snap.maxPlayers)))
                end
                if statCards.friends then
                    local color = snap.friends > 0 and Theme.color.accentHi or Theme.color.text
                    statCards.friends:set(snap.friends, color)
                end
                if statCards.session then statCards.session:set(snap.session) end
                if statCards.fps then
                    local c = snap.fps >= 50 and Theme.color.ok
                        or snap.fps >= 25 and Theme.color.warn
                        or Theme.color.danger
                    statCards.fps:set(snap.fps, c)
                end
                if statCards.ping then
                    local p = snap.ping
                    if p then
                        local c = p < 80 and Theme.color.ok
                            or p < 180 and Theme.color.warn
                            or Theme.color.danger
                        statCards.ping:set(p .. " ms", c)
                    else
                        statCards.ping:set("—")
                    end
                end

                -- Cabeçalho
                UI.headerStats.Text = ("%s jogadores  ·  %s FPS  ·  %s"):format(
                    tostring(snap.serverPlayers), tostring(snap.fps), tostring(snap.session))

                -- Jogo e lugar. tostring em tudo que vem do ambiente: um nil
                -- aqui derrubaria o loop de atualização inteiro a cada 500ms.
                local kind = Game.placeKind()
                UI.heroPlace.Text = PLACE_NAMES[kind] or kind
                UI.gameMeta.Text = ("%s jogadores no servidor  ·  %s na experiência"):format(
                    tostring(snap.serverPlayers),
                    tostring(snap.universe or snap.serverPlayers))
                UI.gamePlace.Text = ("PlaceId %s  ·  universo %s"):format(
                    tostring(game.PlaceId), tostring(game.GameId or "?"))
            end)

            task.wait(0.5)
        end
    end)
end

-- ── Montagem ─────────────────────────────────────────────────────────────────

-- Referência tardia ao módulo Lobby, para evitar dependência circular na carga.
local Lobby_ref = nil

function UI.bindLobby(mod)
    Lobby_ref = mod
end

function UI.mount()
    buildRoot()
    buildHeader()
    buildSidebar()
    buildContent()
    buildStatusBar()

    toastHolder = Widget.new("Frame", {
        Name = "Toasts",
        Size = UDim2.fromOffset(300, 340),
        Position = UDim2.new(0.5, Theme.metric.winW / 2 + 10, 0.5, Theme.metric.winH / 2 - 340),
        BackgroundTransparency = 1,
        ZIndex = 55,
        Parent = gui,
    })

    buildHome()
    buildMissoes()
    buildLobby()
    buildVisual()
    buildConfig()

    UI.selectTab("home")

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightControl then
            UI.setVisible(not UI.isVisible())
        end
    end)

    UI.setStatus(("Pronto · %s"):format(Util.executorName()))
    refreshLoop()
    return gui
end

function UI.unmount()
    if gui then gui:Destroy(); gui = nil end
    UI.controls = {}
    tabs, pages = {}, {}
    statCards = {}
end

return UI

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar ui/interface")
return __chunk(__req)
end

-- ── Entrada ──────────────────────────────────────────────────────────────────
-- O main roda dentro de um loadstring, que cria um escopo próprio. __req é um
-- local do chunk externo e não seria visível lá dentro, então ele é passado
-- como parâmetro — mais limpo que poluir _G.
local __src = [==[
local __req = ...
--[[
    ============================================================================
    VHub · Attack on Titan Revolution
    ============================================================================
    Versão   : 2.0.0
    Interface: PT-BR · preta e vermelha

    Estrutura de abas:
      Home    — identidade, estatísticas ao vivo, jogo atual
      Missões — combate, movimento, nuca, pós-missão
      Lobby   — criação de missão e progressão
      Visual  — ESP
      Config  — sistema, avançado, dados

    RightControl abre e fecha.
    ============================================================================
--]]

-- ── Serviços ─────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")

-- ── Módulos ──────────────────────────────────────────────────────────────────


local Theme     = __req("core/theme")
local Widget    = __req("core/widget")
local State     = __req("core/state")
local Util      = __req("core/util")
local Game_     = __req("core/game")
local Stats     = __req("core/stats")
local Mission   = __req("features/mission")
local Lobby     = __req("features/lobby")
local Post      = __req("features/postmission")
local Visuals   = __req("features/visuals")
local Utility   = __req("features/utility")
local Interface = __req("ui/interface")

-- ── Verificação do lugar ─────────────────────────────────────────────────────
-- O AOTR tem 14 lugares. Guard em duas camadas: GameId confirma a identidade,
-- a pasta Titans confirma que dá para caçar aqui. Nada bloqueia — só informa.

local advice = Game_.placeAdvice()
local kind = Game_.placeKind()

if not Game_.isAOTR() then
    warn(("[VHub] Este não parece ser o AOTR (GameId %s, esperado %s).")
        :format(tostring(game.GameId), tostring(Game_.UNIVERSE_ID)))
end

-- ── Hub ──────────────────────────────────────────────────────────────────────

local Hub = {}
Hub.version = "2.0.0"
Hub.placeId = game.PlaceId
Hub.placeKind = kind

Interface.VERSION = Hub.version
Interface.bindLobby(Lobby)

-- Preferências antes da UI, para os controles nascerem certos.
local loaded = State.load()

local screenGui = Interface.mount()
Visuals.mount(screenGui)

-- ── Ligações estado -> feature ───────────────────────────────────────────────

local function countGroup(keys)
    return State.countActive(keys)
end

State.on("esp", function(on)
    Interface.setStatus(on and "ESP ativo" or "Pronto")
end)

State.on("autoKill", function(on)
    if on then
        Interface.notify("Missões", ("Ataque automático ligado · alcance %s studs"):format(
            tostring(State.config.killRange)))
        if State.config.hitMagnitude > 150 then
            Interface.notify("Atenção",
                "Magnitude muito alta. Isso é fisicamente impossível no jogo e aumenta o risco de marcação.",
                8)
        end
    end
end)

State.on("napeExpander", function(on)
    if not on then Mission.restoreNapes() end
end)

State.on("safeFarm", function(on)
    if not on then
        Interface.notify("Atenção",
            "Modo Seguro desligado. Farms rápidos são o gatilho de shadow ban mais relatado.", 7)
    end
end)

State.on("openPremiumChest", function(on)
    if on then
        Interface.notify("Baú premium",
            "Ligado. Isso gasta recurso da sua conta.", 6)
    end
end)

-- ── Loops ────────────────────────────────────────────────────────────────────

Mission.start()
Lobby.start()
Post.start()
Utility.start()

-- ── Encerramento limpo ───────────────────────────────────────────────────────

local function shutdown()
    pcall(function() Mission.stop() end)
    pcall(function() Lobby.stop() end)
    pcall(function() Post.stop() end)
    pcall(function() Utility.stop() end)
    pcall(function() Visuals.unmount() end)
    pcall(function() Interface.unmount() end)
    State.save()
end
Hub.shutdown = shutdown

-- ── Boas-vindas ──────────────────────────────────────────────────────────────

task.delay(0.8, function()
    Interface.notify("VHub",
        ("v%s · %s · RightControl para abrir."):format(Hub.version, kind), 5)

    if loaded then
        Interface.notify("Configuração", "Preferências restauradas.", 3)
    end

    if advice then
        task.delay(2, function() Interface.notify("Local atual", advice, 9) end)
    end
end)

-- Avisa se a conta já está marcada — é a informação mais importante.
task.delay(1.5, function()
    local exploiter, blacklisted = Game_.isFlagged()
    if blacklisted then
        Interface.notify("Conta Marcada",
            "Sua conta está BLACKLISTED. Pare de usar o script.", 15)
    elseif exploiter then
        Interface.notify("Atenção",
            "Bandeira EXPLOITER ativa. Reduza o uso.", 10)
    end
end)

-- Se a pasta de Titãs existe mas nada foi lido, o jogo mudou os nomes.
task.delay(20, function()
    local ok, titans = pcall(function() return Game_.getTitans(true) end)
    if ok and #titans == 0 and Game_.hasTitans() then
        Interface.notify("Titãs não reconhecidos",
            "A pasta existe, mas nenhum Titã foi lido. Abra Config → Diagnóstico.", 10)
    end
end)

-- ── Expoe para inspeção ──────────────────────────────────────────────────────

if Util.getGenv then
    pcall(function() Util.getGenv().VHub = Hub end)
end

print(("[VHub] v%s · PlaceId %s · %s · executor: %s"):format(
    Hub.version, tostring(game.PlaceId), kind, Util.executorName()))

return Hub

]==]
local __entry = assert(loadstring(__src), "falha ao compilar main")
return __entry(__req)
