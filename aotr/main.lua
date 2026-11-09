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

-- Marker.Adornee — quando o Titã está com um alvo marcado (nuca, braço, perna),
-- o próprio jogo aponta a parte certa. O trz usa esta ordem: Marker primeiro,
-- Nape como reserva. Seguir o Marker evita registrar o golpe na parte errada
-- em Titãs grandes (Colossal) e em animações de ataque.
function Game.markerTarget(model)
    local marker = model:FindFirstChild("Marker")
    if not marker then return nil end

    local ok, adornee = pcall(function() return marker.Adornee end)
    if ok and adornee and type(adornee.IsA) == "function" and adornee:IsA("BasePart") then
        return adornee
    end
    return nil
end

function Game.targetOf(titan)
    return titan and (titan.target or titan.nape) or nil
end

-- Três sinais de Titã vivo, todos usados por scripts que funcionam:
--   Humanoid.Health > 0
--   atributos Dead / Killed ausentes
--   Fake.Head.CanCollide verdadeiro (o jogo derruba a colisão ao morrer)
-- Ler atributo de Instance pode falhar em executor restrito; pcall protege.
local function attrTrue(model, name)
    local ok, value = pcall(function() return model:GetAttribute(name) end)
    return ok and value == true
end

function Game.isTitanAlive(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false, hum end
    if attrTrue(model, "Dead") or attrTrue(model, "Killed") then return false, hum end

    local fake = model:FindFirstChild("Fake")
    local head = fake and fake:FindFirstChild("Head")
    if head and head:IsA("BasePart") and head.CanCollide == false then
        return false, hum
    end

    return true, hum
end

-- O Titã do próprio jogador (shifter) aparece como Attack_Titan na pasta.
-- Atacá-lo é autossabotagem; o Tekkit pausa o farm inteiro enquanto ele existe.
function Game.isShifter()
    local folder = Game.getTitanFolder()
    return folder ~= nil and folder:FindFirstChild("Attack_Titan") ~= nil
end

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
            local alive, hum = Game.isTitanAlive(model)
            if alive then
                local nape = napeOf(model)
                local marker = Game.markerTarget(model)
                local target = marker or nape
                if nape and target then
                    local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
                    if root then
                        local kind, isBoss = Game.classify(model)
                        local isAttack = string.find(string.lower(model.Name), "attack", 1, true) ~= nil
                        table.insert(list, {
                            model = model,
                            humanoid = hum,
                            nape = nape,
                            target = target,
                            marker = marker,
                            root = root,
                            kind = kind,
                            isBoss = isBoss,
                            isAttack = isAttack,
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
    local lp = getLocalPlayer()
    local rig = lp and c:FindFirstChild("Rig_" .. lp.Name) or nil
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
        remoteGetClass = r.GET and r.GET.ClassName or nil,
        remotePostClass = r.POST and r.POST.ClassName or nil,
        shifter = Game.isShifter(),
        titanCount = #titans,
        sampleTitan = nil,
        sampleNape = nil,
        sampleTarget = nil,
        sampleMarker = false,
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
        report.sampleTarget = t.target and t.target.Name or nil
        report.sampleMarker = t.marker ~= nil
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

    PERFIS NOMEADOS
    ---------------
    O arquivo vhub_config.json guarda a configuração ATIVA (o último estado).
    vhub_profiles.json guarda perfis nomeados: cada um é um retrato de flags e
    config. No carregamento, o perfil marcado como autoload tem prioridade sobre
    a configuração ativa — é o comportamento do AirFlow ("Current autoload").
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
    -- ESP de qualquer lugar: Highlight + nameplate ignoram a distância e a
    -- parede. As setas avisam quando o Titã está fora da tela ou atrás de você.
    espHighlight    = true,
    espNameplate    = true,
    espArrows       = true,
    espAnywhere     = true,

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
    -- O valor precisa cobrir a distância real até a hitbox. Com a lâmina
    -- (~12 studs) e o teleporte para a nuca (offset 4), 60 dá folga sem chegar
    -- aos 143–850 dos scripts públicos, que são o sinal mais fácil de auditar.
    hitMagnitude    = 60,
    hitOffset       = 0,

    -- Remote usado em Hitboxes/Register.
    --   "POST"  → RemoteEvent FireServer (Facu v8, trz, Smooth, dio, Asta)
    --   "GET"   → RemoteFunction InvokeServer (Tekkit, StwFate)
    --   "Ambos" → tenta os dois; cobre versões diferentes do jogo.
    -- O padrão é POST porque é o que o catálogo de endpoints atual e a maioria
    -- dos scripts recentes usam. O botão "Testar golpe" mostra qual respondeu.
    registerMethod  = "POST",

    -- Nuca (tamanho de fábrica: Vector3.new(15, 9, 11))
    napeScale       = 1.5,
    -- Tamanho absoluto em studs (maior dimensão). 0 desliga e usa napeScale.
    -- O AirFlow usa 280; deixamos 0 de fábrica porque o padrão seguro é o
    -- multiplicador, e 280 é uma escolha consciente do usuário.
    napeSize        = 0,
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
    espMaxDist      = 1200,
    espColor        = "Vermelho",
    espThickness    = 1.4,

    -- Menu / tema
    menuScale       = 100,          -- porcentagem (70–140)
    menuKey         = "RightControl",
    themePreset     = "VHub",
    accentColor     = "#E02D2D",    -- hex RGB da cor de destaque
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
local PROFILES_PATH = "vhub_profiles.json"

local function http()
    return game:GetService("HttpService")
end

-- Cópia defensiva: gravar/ler JSON não pode compartilhar tabela com o estado
-- vivo, senão uma alteração futura muda o retrato do perfil sem querer.
local function copyTable(t)
    local out = {}
    if type(t) ~= "table" then return out end
    for k, v in pairs(t) do
        if type(v) == "table" then out[k] = copyTable(v) else out[k] = v end
    end
    return out
end

local function snapshot()
    return {
        flags = copyTable(State.flags),
        config = copyTable(State.config),
    }
end

-- Aplica dados externos com validação de tipo. É a única porta de entrada de
-- configuração em disco: lixo de versão antiga não pode quebrar o script.
local function applyData(data)
    if type(data) ~= "table" then return false end
    local applied = false

    for k, v in pairs(data.flags or {}) do
        if State.flags[k] ~= nil and type(v) == "boolean" then
            State.flags[k] = v
            applied = true
        end
    end
    for k, v in pairs(data.config or {}) do
        local current = State.config[k]
        if current ~= nil and type(v) == type(current) then
            if type(v) == "table" then
                State.config[k] = copyTable(v)
            else
                State.config[k] = v
            end
            applied = true
        end
    end

    return applied
end

function State.save()
    local ok = pcall(function()
        if not writefile then return end
        writefile(CONFIG_PATH, http():JSONEncode(snapshot()))
    end)
    return ok
end

function State.load()
    local ok, data = pcall(function()
        if not (isfile and isfile(CONFIG_PATH)) then return nil end
        return http():JSONDecode(readfile(CONFIG_PATH))
    end)
    if not ok or type(data) ~= "table" then return false end

    applyData(data)
    return true
end

-- ── Perfis nomeados ──────────────────────────────────────────────────────────

local function readProfiles()
    local data = { profiles = {}, autoload = nil }
    local ok, decoded = pcall(function()
        if not (isfile and isfile(PROFILES_PATH)) then return nil end
        return http():JSONDecode(readfile(PROFILES_PATH))
    end)

    if ok and type(decoded) == "table" then
        if type(decoded.profiles) == "table" then data.profiles = decoded.profiles end
        if type(decoded.autoload) == "string" then data.autoload = decoded.autoload end
    end
    return data
end

local function writeProfiles(data)
    local ok, err = pcall(function()
        if not writefile then
            error("executor sem writefile", 0)
        end
        writefile(PROFILES_PATH, http():JSONEncode(data))
    end)
    return ok, err
end

local function cleanName(name)
    if type(name) ~= "string" then return "" end
    return (name:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Lista de nomes, em ordem alfabética. A UI usa para o resumo e os testes.
function State.profileList()
    local data = readProfiles()
    local names = {}
    for name in pairs(data.profiles) do
        if type(name) == "string" and name ~= "" then table.insert(names, name) end
    end
    table.sort(names)
    return names
end

function State.profileExists(name)
    name = cleanName(name)
    if name == "" then return false end
    return readProfiles().profiles[name] ~= nil
end

-- Retrato do estado atual, sem gravar. Útil para depuração e para a UI.
function State.profileSnapshot()
    return snapshot()
end

-- Cria ou substitui um perfil com o estado atual.
function State.profileSave(name)
    name = cleanName(name)
    if name == "" then return false, "informe um nome de perfil" end
    if #name > 40 then return false, "nome muito longo (máximo 40)" end

    local data = readProfiles()
    local shot = snapshot()
    shot.savedAt = os.time()
    data.profiles[name] = shot

    local ok, err = writeProfiles(data)
    if not ok then return false, tostring(err) end
    return true
end

-- Cria um perfil NOVO com o estado atual. Diferente de profileSave, recusa
-- substituir um nome existente — é a semântica de "Create" do AirFlow, que não
-- deixa sobrescrever configuração sem querer.
function State.profileCreate(name)
    name = cleanName(name)
    if name == "" then return false, "informe um nome de perfil" end
    if State.profileExists(name) then
        return false, "já existe um perfil com esse nome"
    end
    return State.profileSave(name)
end

-- Carrega um perfil no estado ativo. Não grava em disco: a configuração ativa
-- é persistida no shutdown, como sempre.
function State.profileLoad(name)
    name = cleanName(name)
    if name == "" then return false, "informe um nome de perfil" end

    local data = readProfiles()
    local profile = data.profiles[name]
    if type(profile) ~= "table" then return false, "perfil não encontrado" end

    applyData(profile)
    return true
end

function State.profileDelete(name)
    name = cleanName(name)
    if name == "" then return false, "informe um nome de perfil" end

    local data = readProfiles()
    if data.profiles[name] == nil then return false, "perfil não encontrado" end

    data.profiles[name] = nil
    if data.autoload == name then data.autoload = nil end

    local ok, err = writeProfiles(data)
    if not ok then return false, tostring(err) end
    return true
end

-- Define (ou limpa, com nil/"") o perfil carregado automaticamente na entrada.
function State.profileSetAutoload(name)
    local data = readProfiles()

    if name == nil or cleanName(name) == "" then
        data.autoload = nil
        local ok, err = writeProfiles(data)
        if not ok then return false, tostring(err) end
        return true
    end

    name = cleanName(name)
    if type(data.profiles[name]) ~= "table" then return false, "perfil não encontrado" end

    data.autoload = name
    local ok, err = writeProfiles(data)
    if not ok then return false, tostring(err) end
    return true
end

function State.profileAutoload()
    return readProfiles().autoload
end

-- Chamado UMA vez na entrada, depois de State.load(). O perfil de autoload tem
-- a última palavra para que o comportamento seja previsível entre sessões.
function State.loadAutoload()
    local name = State.profileAutoload()
    if not name then return false end
    local ok = State.profileLoad(name)
    if ok then return true, name end
    return false
end

-- Exposto para testes e para o diagnóstico.
State.PROFILES_PATH = PROFILES_PATH
State.CONFIG_PATH = CONFIG_PATH

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

-- LocalPlayer resolvido a cada uso: o executor pode injetar antes do jogador
-- existir, e um upvalue nil congelaria amigos/perfil para sempre.
local function getLocalPlayer() return Players.LocalPlayer end

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
local fpsConn = nil

task.spawn(function()
    fpsConn = RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local elapsed = os.clock() - windowStart
        if elapsed >= 0.5 then
            fps = math.floor(frameCount / elapsed + 0.5)
            frameCount = 0
            windowStart = os.clock()
        end
    end)
end)

-- Sem isso, cada reexecução do script deixava um RenderStepped contando
-- frames para sempre. O descarregamento precisa soltar esta conexão.
function Stats.stop()
    if fpsConn then fpsConn:Disconnect(); fpsConn = nil end
end

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

local friendsCache = { list = {}, at = -1e9 }

function Stats.friendsHere(force)
    local now = os.clock()
    if not force and (now - friendsCache.at) < 20 then
        return friendsCache.list
    end

    local found = {}
    local me = getLocalPlayer()
    if not me then return found end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= me then
            -- userId ou Player: a API aceita ambos nas versões atuais.
            local ok, isFriend = pcall(function()
                return me:IsFriendsWith(p.UserId)
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
local universeCache = { count = nil, max = nil, at = -1e9 }

function Stats.universePlayers()
    local now = os.clock()
    if (now - universeCache.at) < 60 then
        return universeCache.count, universeCache.max
    end

    local req = request or http_request or (syn and syn.request)
    if not req then return nil, nil end

    universeCache.at = now

    task.spawn(function()
        local ok, playing, max = pcall(function()
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
        if ok and playing then
            universeCache.count = playing
            universeCache.max = max
        end
    end)

    return universeCache.count, universeCache.max
end

-- ── Jogador local ────────────────────────────────────────────────────────────

function Stats.playerInfo()
    local lp = getLocalPlayer()
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
local CINZA = Color3.fromRGB(148, 150, 158)
local DEFAULT_ACCENT = Color3.fromRGB(224, 45, 45)

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
-- A paleta é calculada a partir do accent. Mudar o accent em tempo real
-- significa recalcular ESTA tabela no lugar (nunca substituir a referência:
-- os módulos guardaram Theme.color e continuariam vendo a paleta antiga).
local function palette(accent)
    return {
        void       = TINTA,
        base       = mix(TINTA, CINZA, 0.055),
        surface    = mix(TINTA, CINZA, 0.085),
        surfaceHi  = mix(TINTA, CINZA, 0.120),
        surfaceTop = mix(TINTA, CINZA, 0.150),
        card       = mix(TINTA, CINZA, 0.100),

        line       = mix(TINTA, CINZA, 0.170),
        lineSoft   = mix(TINTA, CINZA, 0.105),
        lineHot    = mix(accent, TINTA, 0.40),

        text       = Color3.fromRGB(242, 243, 247),
        textDim    = mix(CINZA, TINTA, 0.18),
        textMute   = mix(CINZA, TINTA, 0.50),

        accent     = accent,
        accentHi   = lighten(accent, 0.30),
        accentLo   = darken(accent, 0.36),
        accentDeep = darken(accent, 0.62),
        accentGhost= mix(accent, TINTA, 0.88),

        on         = mix(accent, Color3.new(1, 1, 1), 0.18),
        off        = mix(TINTA, CINZA, 0.22),
        warn       = Color3.fromRGB(230, 172, 76),
        danger     = Color3.fromRGB(238, 62, 62),
        ok         = Color3.fromRGB(98, 194, 142),
        info       = Color3.fromRGB(110, 152, 222),
    }
end

Theme.color = palette(DEFAULT_ACCENT)
Theme.accent = DEFAULT_ACCENT
Theme.DEFAULT_ACCENT = DEFAULT_ACCENT

-- ── Presets de tema ──────────────────────────────────────────────────────────
-- Nomes de jogador, não de marca alheia: a identidade padrão continua sendo o
-- vermelho do VHub. Os outros presets existem para quem quiser outra leitura.
Theme.PRESETS = {
    ["VHub"]      = { 224, 45, 45 },    -- brasa (padrão)
    ["Carmim"]    = { 215, 38, 61 },
    ["Aço"]       = { 110, 152, 222 },
    ["Esmeralda"] = { 98, 194, 142 },
    ["Âmbar"]     = { 230, 172, 76 },
    ["Violeta"]   = { 155, 120, 220 },
    ["Gelo"]      = { 92, 202, 212 },
}
Theme.PRESET_ORDER = { "VHub", "Carmim", "Aço", "Esmeralda", "Âmbar", "Violeta", "Gelo" }

function Theme.presetColor(name)
    local rgb = Theme.PRESETS[name]
    if not rgb then return nil end
    return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Troca a paleta viva. A UI é remontada em seguida (UI.remount), porque as
-- instâncias antigas guardaram cores individuais.
function Theme.applyAccent(accent)
    if not accent or accent.R == nil then return false end
    Theme.accent = accent
    for k, v in pairs(palette(accent)) do Theme.color[k] = v end
    return true
end

-- Aceita "#RRGGBB", "RRGGBB", "#RGB" e devolve Color3 (ou nil).
function Theme.fromHex(hex)
    if hex == nil then return nil end
    if type(hex) ~= "string" then
        -- Já é Color3 (userdata no Roblox, table no mock).
        if hex.R ~= nil then return hex end
        return nil
    end

    local s = hex:gsub("#", "")
    if #s == 3 then
        s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2)
    end
    if #s ~= 6 or s:find("%X") then return nil end

    local r = tonumber(s:sub(1, 2), 16)
    local g = tonumber(s:sub(3, 4), 16)
    local b = tonumber(s:sub(5, 6), 16)
    if not (r and g and b) then return nil end
    return Color3.fromRGB(r, g, b)
end

-- Devolve "#RRGGBB" em maiúsculas.
function Theme.toHex(color)
    if not color or color.R == nil then return nil end
    local function byte(v)
        local n = math.floor(v * 255 + 0.5)
        if n < 0 then n = 0 elseif n > 255 then n = 255 end
        return string.format("%02X", n)
    end
    return "#" .. byte(color.R) .. byte(color.G) .. byte(color.B)
end

-- Nome do preset que corresponde exatamente à cor, ou "Personalizado".
function Theme.presetFor(color)
    local hex = Theme.toHex(color)
    if not hex then return "Personalizado" end
    for _, name in ipairs(Theme.PRESET_ORDER) do
        local c = Theme.presetColor(name)
        if Theme.toHex(c) == hex then return name end
    end
    return "Personalizado"
end

function Theme.applyConfig(config)
    local color = Theme.fromHex(config and config.accentColor) or DEFAULT_ACCENT
    return Theme.applyAccent(color)
end

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
    local a = Theme.color.accent
    return Theme.gradient(frame, {
        { 0.0, lighten(a, 0.14) },
        { 0.5, a },
        { 1.0, darken(a, 0.30) },
    })
end

-- Brilho colorido que some para o escuro: usado atrás do logo e no cabeçalho.
function Theme.gradientGlow(frame)
    local a = Theme.color.accent
    return Theme.gradient(frame, {
        { 0.0, mix(a, TINTA, 0.55) },
        { 0.6, mix(a, TINTA, 0.88) },
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
Util.identify     = pick(identifyexecutor, getexecutorname)

-- Synapse expõe write_clipboard recebendo uma TABELA, enquanto setclipboard e
-- toclipboard recebem texto. Escolher a referência crua fazia a cópia falhar
-- só nesse executor; aqui a assinatura é normalizada.
local directClipboard = pick(setclipboard, toclipboard)
if directClipboard then
    Util.setClipboard = directClipboard
elseif syn and syn.write_clipboard then
    Util.setClipboard = function(text) syn.write_clipboard({ text }) end
else
    Util.setClipboard = nil
end

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

-- ── Conexões de serviço ──────────────────────────────────────────────────────
-- Slider e dropdown escutam UserInputService para arrastar e fechar ao clicar
-- fora. Essas conexões NÃO morrem junto com o Frame: sem registro, cada
-- remontagem (mudança de tema) deixaria um ouvinte antigo vivo para sempre.
-- A UI chama Widget.releaseConnections() no unmount.

local serviceConnections = {}

local function trackService(conn)
    if conn then table.insert(serviceConnections, conn) end
    return conn
end

function Widget.releaseConnections()
    for _, conn in ipairs(serviceConnections) do
        pcall(function() conn:Disconnect() end)
    end
    serviceConnections = {}
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
    trackService(game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            apply(fromX(input.Position.X), true)
        end
    end))

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

    trackService(game:GetService("UserInputService").InputBegan:Connect(function(input)
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
    end))

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

    local label = new("TextLabel", {
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

    -- Texto mutável: a UI usa para o resumo de perfis e o cartão de servidor,
    -- que mudam sem que a seção inteira precise ser remontada.
    return {
        instance = box,
        set = function(_, text) label.Text = tostring(text or "") end,
        get = function() return label.Text end,
    }
end

return Widget

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar core/widget")
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

    VALORES VÁLIDOS (listas completas das fontes + captura do AirFlow)
      Mapas        : Shiganshina, Trost, Outskirts, Forest, Utgard, Docks,
                     Stohess, Chapel
      Dificuldade  : Easy, Normal, Hard, Severe, Aberrant, Highest
      Tipo         : Missions | Raids | Waves
      Objetivo     : Skirmish (só em Missions) | Waves (só em Waves)
      Modificadores: 15 opções, ver MODIFIERS abaixo

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

Lobby.DIFFICULTIES = {
    "Easy", "Normal", "Hard", "Severe", "Aberrant", "Highest",
}

Lobby.TYPES = { "Missions", "Raids", "Waves" }

Lobby.OBJECTIVES = { "Skirmish", "Waves" }

-- Lista completa vista no dropdown do AirFlow (captura de 05/11): 15 opções.
-- Faltavam Fatigue, Evolution e Primitive na versão anterior.
Lobby.MODIFIERS = {
    "No Perks", "No Skills", "No Memories", "Nightmare", "Oddball",
    "Injury Prone", "Chronic Injuries", "Fog", "Glass Cannon",
    "Time Trial", "Fatigue", "Evolution", "Boring", "Simple",
    "Primitive",
}

Lobby.RAIDS = {
    ["Attack Titan"]   = "Trost",
    ["Armored Titan"]  = "Shiganshina",
    ["Female Titan"]   = "Stohess",
    ["Colossal Titan"] = "Shiganshina",
}

-- Ordem fixa para o dropdown da UI. Percorrer `pairs(RAIDS)` funcionaria, mas
-- a ordem mudaria entre sessões e o menu ficaria imprevisível.
Lobby.RAID_NAMES = {
    "Attack Titan", "Armored Titan", "Female Titan", "Colossal Titan",
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
        POST("Hitboxes", "Register", part, magnitude, offset)
        POST("Attacks", "Slash", false)     fecha o golpe (só ao parar)

        O par abrir/fechar importa: o servidor valida a JANELA do golpe, não
        um disparo isolado. Mandar só o Register não registra dano.

        Register: o catálogo de endpoints do Facu v8 e os scripts recentes
        (trz, Smooth, dio, Asta) usam POST:FireServer; Tekkit e StwFate usam
        GET:InvokeServer. Como os dois grupos existem em versões diferentes do
        jogo, o método é configurável e "Ambos" cobre os dois. O padrão é POST.

        Os scripts que farmam de verdade NÃO fecham o Slash a cada golpe:
        abrem uma vez e registram vários. Fechar no mesmo frame cancelava a
        janela e era um dos motivos de "não causar dano".

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
    Fontes usam 143+rand(10), rand(215,230), rand(625,850). Os valores altos são
    fisicamente impossíveis e o dado mais fácil do servidor auditar. O padrão
    aqui é 60: cobre o alcance curto com folga e fica abaixo do que os scripts
    públicos usam. O valor alto é opt-in no Config.
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
Mission._wantGrabs = false

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
-- Abre a janela do Slash e registra o golpe. O fechamento é feito por
-- Mission.stopAttack() ao parar o auto kill, não a cada ataque.

-- Distância infinita (jogador sem personagem) não pode ir para %d: em Lua 5.4
-- math.huge não tem representação inteira e string.format lança erro.
local function distText(dist)
    dist = tonumber(dist)
    if not dist or dist ~= dist or dist == math.huge then return "—" end
    return tostring(math.floor(dist))
end

function Mission.hitMagnitude()
    local base = tonumber(State.config.hitMagnitude) or 60
    base = math.clamp(base, 1, 10000)
    -- Jitter de 4%: magnitude constante é uma assinatura trivial de detectar.
    local spread = math.max(1, base * 0.04)
    return math.floor(base + (math.random() * 2 - 1) * spread + 0.5)
end

local REGISTER_GET_INTERVAL = 0.35
local lastGetRegister = 0

function Mission.registerHit(part, magnitude, offset, method)
    method = method or State.config.registerMethod or "POST"
    local postOk, getResult = false, nil

    if method == "POST" or method == "Ambos" then
        postOk = Game.post("Hitboxes", "Register", part, magnitude, offset)
    end
    if method == "GET" or method == "Ambos" then
        local now = os.clock()
        -- InvokeServer cede a thread até o servidor responder. Em "Ambos" ele
        -- é limitado para não empilhar uma chamada por golpe.
        if method == "GET" or (now - lastGetRegister) >= REGISTER_GET_INTERVAL then
            lastGetRegister = now
            getResult = Game.get("Hitboxes", "Register", part, magnitude, offset)
        end
    end

    return postOk == true, getResult
end

function Mission.strike(titan)
    local part = Game.targetOf(titan)
    if not part then return false end

    Game.post("Attacks", "Slash", true)
    Mission._slashOpen = true

    local magnitude = Mission.hitMagnitude()
    local offset = tonumber(State.config.hitOffset) or 0
    local postOk, getResult = Mission.registerHit(part, magnitude, offset)

    Mission.lastStrike = {
        part = part,
        magnitude = magnitude,
        offset = offset,
        method = State.config.registerMethod or "POST",
        post = postOk,
        get = getResult,
        at = os.clock(),
    }

    return postOk or getResult ~= nil
end

-- Fecha a janela do golpe. Chamado ao desligar o auto kill/descarregar, não a
-- cada ataque: fechar no mesmo frame cancelava o Register.
function Mission.stopAttack()
    if not Mission._slashOpen then return end
    Mission._slashOpen = false
    Game.post("Attacks", "Slash", false)
end

-- Diagnóstico de combate em um clique. Mantém a vida antes/depois e reporta o
-- tipo real dos remotes, para separar "o script não chamou" de "o servidor
-- recusou" sem adivinhação.
function Mission.testStrike()
    local titans = Game.getTitans(true)
    if #titans == 0 then
        return false, "Nenhum Titã vivo encontrado. Entre numa missão e espere a onda."
    end

    local titan = titans[1]
    local part = Game.targetOf(titan)
    if not part then return false, "O Titã não tem Nape nem Marker. Veja o Diagnóstico." end

    local before = tonumber(titan.hp) or 0
    local remotes = Game.getRemotes()
    local sent = Mission.strike(titan)
    local strike = Mission.lastStrike or {}

    local detail = ("Alvo: %s · parte: %s · %s studs\nVida antes: %d\nMétodo: %s · magnitude %d · offset %s\nGET=%s  POST=%s"):format(
        tostring(titan.name), tostring(part.Name), distText(titan.dist),
        math.floor(before),
        tostring(strike.method or State.config.registerMethod or "POST"),
        math.floor(tonumber(strike.magnitude) or 0),
        tostring(strike.offset or State.config.hitOffset or 0),
        remotes.GET and remotes.GET.ClassName or "ausente",
        remotes.POST and remotes.POST.ClassName or "ausente")

    task.delay(0.7, function()
        local after = titan.humanoid and titan.humanoid.Health or before
        local damage = before - after
        local tail
        if damage > 0 then
            tail = ("Vida agora: %d · dano: %d\nO servidor ACEITOU o golpe."):format(
                math.floor(after), math.floor(damage))
        elseif sent then
            tail = ("Vida agora: %d · sem dano ainda\nO remote saiu, mas o servidor não aplicou. Teste GET/Ambos ou aumente a magnitude."):format(
                math.floor(after))
        else
            tail = "O remote recusou a chamada. Veja Config → Diagnóstico."
        end
        Util.notify("Teste de golpe", tail, 12)
    end)

    return sent, detail
end

function Mission.statusLine()
    local t = Mission.target
    local alvo = "nenhum"
    if t then
        alvo = ("%s · %s studs"):format(
            tostring(t.name), distText(t.dist))
    end
    return ("Abates: %d · Escapes: %d\nAlvo atual: %s"):format(
        Mission.kills, Mission.escapes, alvo)
end

-- ── Escape de agarrão ────────────────────────────────────────────────────────
-- O prompt de agarrão aparece como filho novo em PlayerGui.Interface.Buttons.
-- O sinal é observado, não adivinhado.

local escapeConn = nil
Mission.grabbed = false
Mission.escapes = 0

function Mission.watchGrabs()
    if escapeConn or not Mission._wantGrabs then return end

    local lp = Game.getLocalPlayer()
    local pg = lp and lp:FindFirstChild("PlayerGui")
    local iface = pg and pg:FindFirstChild("Interface")
    local buttons = iface and iface:FindFirstChild("Buttons")

    if not buttons then
        -- Ainda não montou: tenta de novo em instantes. O retry confere a flag
        -- para não reconectar depois de Mission.stop()/descarregamento.
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
    -- Enquanto o jogador É um Titã, atacar é autossabotagem (regra do Tekkit).
    if Game.isShifter() then return end

    local titans = Game.getTitans()
    if #titans == 0 then return end

    local range = State.config.killRange
    local target
    for _, t in ipairs(titans) do
        if not t.isAttack and Game.targetOf(t) and t.dist <= range then
            target = t
            break
        end
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
local napeKey = nil

-- Tamanho alvo da nuca. Duas formas, na ordem de prioridade:
--   napeSize > 0  → tamanho absoluto em studs (maior dimensão). 280 é o valor
--                   que o AirFlow usa; é opt-in consciente.
--   napeSize == 0 → multiplicador napeScale sobre o tamanho de fábrica.
function Mission.napeTargetSize()
    local absolute = tonumber(State.config.napeSize) or 0
    if absolute > 0 then
        -- A maior dimensão de fábrica é X (15). Escalar por ela mantém a
        -- proporção 15:9:11 e faz "280" significar 280 studs de comprimento.
        return NAPE_FACTORY_SIZE * (absolute / NAPE_FACTORY_SIZE.X)
    end
    return NAPE_FACTORY_SIZE * (State.config.napeScale or 1)
end

function Mission.expandNapes()
    local size = Mission.napeTargetSize()
    for _, t in ipairs(Game.getTitans()) do
        local nape = t.nape
        if nape and not expanded[nape] then
            expanded[nape] = {
                size = nape.Size,
                transparency = nape.Transparency,
                color = nape.Color,
                material = nape.Material,
            }
            nape.Size = size
            nape.Transparency = State.config.napeTransparency
            nape.Color = Theme.color.accent
            nape.Material = Enum.Material.Neon
            nape.CanCollide = false
        end
    end
    napeKey = Mission._napeSignature()
end

-- Assinatura dos parâmetros da nuca. Comparar Vector3 por identidade não
-- funciona no mock (e é frágil no Roblox), então a assinatura é textual.
function Mission._napeSignature()
    return ("%s|%s|%s"):format(
        tostring(State.config.napeSize or 0),
        tostring(State.config.napeScale or 0),
        tostring(State.config.napeTransparency or 0))
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
    napeKey = nil
end

-- Uma nuca que sai do mapa e volta deve ser re-expandida. Sem isso, o Titã
-- seguinte nasce com hitbox normal e o usuário acha que a feature parou.
-- Também reaplica o tamanho quando o usuário mexe no slider durante a missão.
function Mission.refreshExpanded()
    local live = {}
    for _, t in ipairs(Game.getTitans()) do live[t.nape] = true end

    for part in pairs(expanded) do
        if not live[part] or not part.Parent then
            expanded[part] = nil
        end
    end

    -- Comparar ANTES de expandir: expandNapes grava a assinatura no fim, e
    -- comparar depois faria a mudança do slider passar despercebida.
    local signature = Mission._napeSignature()
    if napeKey ~= signature then
        local size = Mission.napeTargetSize()
        for part in pairs(expanded) do
            if part and part.Parent then
                pcall(function()
                    part.Size = size
                    part.Transparency = State.config.napeTransparency
                end)
            end
        end
    end

    -- Expande nacas novas com o tamanho atual e grava a assinatura aplicada.
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
        else Mission._tracked[t.model] = { hp = t.hp, seen = now, isAttack = t.isAttack } end
    end
    for model, rec in pairs(Mission._tracked) do
        if not seen[model] then
            if (now - rec.seen) < 2 and State.flags.autoKill and not rec.isAttack then
                Mission.kills = Mission.kills + 1
            end
            Mission._tracked[model] = nil
        end
    end
end

-- ── Ciclo ────────────────────────────────────────────────────────────────────

function Mission.start()
    if Mission._conn then return end
    Mission._wantGrabs = true
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
    Mission._wantGrabs = false
    Mission.stopAttack()
    Mission.restoreNapes()
end

function Mission.newMission()
    Mission._missionStart = os.clock()
    Mission.kills = 0
    Mission.target = nil
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
    if Post._rejoinConn then return end

    Post._rejoinConn = lp.OnTeleport:Connect(function()
        Post.lastAction = "Teleportando…"
    end)

    -- Detecta troca de lugar por mudança de PlaceId entre leituras. O laço é
    -- cancelável: sem isso, descarregar o script deixava uma corrotina viva
    -- para sempre e uma nova era criada a cada Post.start().
    if Post._watching then return end
    Post._watching = true
    task.spawn(function()
        local lastPlace = game.PlaceId
        while Post._watching do
            task.wait(2)
            if not Post._watching then break end
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
    if Post._rejoinConn then Post._rejoinConn:Disconnect(); Post._rejoinConn = nil end
    Post._watching = false
end

return Post

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar features/postmission")
return __chunk(__req)
end

-- ── features/server ───────────────────────────────────────────
MODULES["features/server"] = function()
local __src = [=[
--[[
    VHub · Servidor
    Arquivo: src/features/server.lua

    Ferramentas de sessão que o AirFlow oferece na Home: rejoin, server hop,
    entrar no servidor mais vazio e copiar identificadores.

    Nada aqui conhece a UI. As ações devolvem true/false e avisam pelo
    Util.notify (que a interface registra em UI.notify). A lista de servidores
    vem da API pública da Roblox, então depende de request/http_request —
    quando o executor não tem, a função avisa em vez de falhar em silêncio.

    LIMITE HONESTO: a API só lista servidores PÚBLICOS. Servidor privado,
    reservado ou cheio não aparece; "mais vazio" é o menor `playing` entre os
    que a API devolveu, não uma garantia de vaga.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Game = __req("core/game")
local Util = __req("core/util")

local Server = {}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local SERVERS_URL = "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"

-- ── Identificadores ──────────────────────────────────────────────────────────

function Server.jobId()
    return game.JobId or ""
end

function Server.placeId()
    return game.PlaceId
end

function Server.universeId()
    return game.GameId or Game.UNIVERSE_ID
end

function Server.shortJob()
    local id = Server.jobId()
    if #id <= 12 then return id end
    return id:sub(1, 8) .. "…"
end

function Server.info()
    return {
        jobId = Server.jobId(),
        shortJob = Server.shortJob(),
        placeId = Server.placeId(),
        universeId = Server.universeId(),
        players = #Players:GetPlayers(),
        maxPlayers = Players.MaxPlayers,
    }
end

-- ── Área de transferência ────────────────────────────────────────────────────

function Server.copy(text, label)
    if not text or text == "" then
        Util.notify("Copiar", "Nada para copiar aqui.", 4)
        return false
    end
    if not Util.setClipboard then
        Util.notify("Copiar", "Este executor não expõe a área de transferência.", 5)
        return false
    end

    local ok = pcall(Util.setClipboard, text)
    if ok then
        Util.notify("Copiado", label or text, 3)
    else
        Util.notify("Copiar", "A cópia falhou neste executor.", 4)
    end
    return ok
end

function Server.copyJobId()
    return Server.copy(Server.jobId(), "Job ID copiado.")
end

function Server.copyUniverse()
    return Server.copy(tostring(Server.universeId()), "Universo copiado.")
end

function Server.copyPlace()
    return Server.copy(tostring(Server.placeId()), "PlaceId copiado.")
end

function Server.copyInvite()
    local url = ("https://www.roblox.com/games/start?placeId=%d&gameInstanceId=%s")
        :format(Server.placeId(), Server.jobId())
    return Server.copy(url, "Link do servidor copiado.")
end

-- ── Teleporte ────────────────────────────────────────────────────────────────

local function teleportService()
    return game:GetService("TeleportService")
end

function Server.connect(jobId)
    if not jobId or jobId == "" then
        Util.notify("Servidor", "Job ID inválido.", 4)
        return false
    end

    local lp = Players.LocalPlayer
    if not lp then
        Util.notify("Servidor", "Jogador ainda não carregou.", 4)
        return false
    end

    local ok, err = pcall(function()
        teleportService():TeleportToPlaceInstance(Server.placeId(), jobId, lp)
    end)
    if not ok then
        Util.notify("Servidor", "O executor bloqueou o teleporte: " .. tostring(err), 6)
        return false
    end

    Util.notify("Servidor", "Teleportando…", 3)
    return true
end

function Server.rejoin()
    local job = Server.jobId()
    if job ~= "" then
        return Server.connect(job)
    end

    -- Fallback para lugares em que o JobId não é exposto: teleporte simples.
    local lp = Players.LocalPlayer
    if not lp then return false end
    local ok, err = pcall(function()
        teleportService():Teleport(Server.placeId(), lp)
    end)
    if not ok then
        Util.notify("Servidor", "O executor bloqueou o teleporte: " .. tostring(err), 6)
        return false
    end
    Util.notify("Servidor", "Reentrando…", 3)
    return true
end

-- ── Lista de servidores públicos ─────────────────────────────────────────────

local function requestFn()
    return request or http_request or (syn and syn.request)
end

-- Assíncrono: chama callback(list, erro). list é uma tabela de
-- { id, playing, maxPlayers }, como a API devolve.
function Server.fetchServers(callback)
    local req = requestFn()
    if not req then
        callback(nil, "executor sem request/http_request")
        return
    end

    task.spawn(function()
        local ok, result = pcall(function()
            local res = req({
                Url = SERVERS_URL:format(Server.placeId()),
                Method = "GET",
            })
            if not res or not res.Body then error("resposta vazia", 0) end
            local data = HttpService:JSONDecode(res.Body)
            local list = data and data.data
            if type(list) ~= "table" then error("JSON sem campo data", 0) end
            return list
        end)
        if ok then callback(result) else callback(nil, tostring(result)) end
    end)
end

local function eligible(list, currentJob)
    local out = {}
    for _, s in ipairs(list or {}) do
        if type(s) == "table" and type(s.id) == "string"
            and s.id ~= "" and s.id ~= currentJob then
            local playing = tonumber(s.playing) or 0
            local max = tonumber(s.maxPlayers) or 0
            if max == 0 or playing < max then
                table.insert(out, {
                    id = s.id,
                    playing = playing,
                    maxPlayers = max,
                })
            end
        end
    end
    return out
end

-- Escolha aleatória entre os servidores com vaga. Separada do teleporte para
-- ser testável sem rede.
function Server.chooseHop(list, currentJob)
    local pool = eligible(list, currentJob)
    if #pool == 0 then return nil end
    return pool[math.random(1, #pool)]
end

-- O menos populoso. Empate fica com o primeiro — estável e previsível.
function Server.chooseLowest(list, currentJob)
    local pool = eligible(list, currentJob)
    if #pool == 0 then return nil end

    local best = pool[1]
    for i = 2, #pool do
        if pool[i].playing < best.playing then best = pool[i] end
    end
    return best
end

function Server.serverHop()
    Server.fetchServers(function(list, err)
        if not list then
            Util.notify("Server Hop", "Não consegui listar servidores: " .. tostring(err), 6)
            return
        end

        local pick = Server.chooseHop(list, Server.jobId())
        if not pick then
            Util.notify("Server Hop", "Nenhum servidor público com vaga agora.", 5)
            return
        end

        Server.connect(pick.id)
    end)
end

function Server.joinLowest()
    Server.fetchServers(function(list, err)
        if not list then
            Util.notify("Servidor mais vazio",
                "Não consegui listar servidores: " .. tostring(err), 6)
            return
        end

        local pick = Server.chooseLowest(list, Server.jobId())
        if not pick then
            Util.notify("Servidor mais vazio", "Nenhum servidor público com vaga agora.", 5)
            return
        end

        Util.notify("Servidor mais vazio",
            ("%d/%d jogadores — entrando…"):format(pick.playing, pick.maxPlayers), 3)
        Server.connect(pick.id)
    end)
end

return Server

]=]
local __chunk = assert(loadstring(__src), "falha ao compilar features/server")
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

    TRÊS CAMADAS, porque uma só não cobre "ver de qualquer lugar":

      1. Highlight 3D (Adornee = modelo, DepthMode = AlwaysOnTop)
         Atravessa parede, terreno e distância. É o que faz o Titã ficar
         visível mesmo do outro lado do mapa. Parenteado no modelo, então
         não replica para outros jogadores.

      2. BillboardGui (nameplate preso ao Titã)
         Nome, distância e vida sempre acima dele. MaxDistance = 0 significa
         sem limite de distância. Só o cliente vê.

      3. Projeção 2D no ScreenGui
         Caixa, linha, vida, marcador de nuca — os mesmos elementos da versão
         anterior. Quando o Titã sai da tela ou fica atrás da câmera, entra uma
         SETA na borda apontando para ele; sem isso, Titã fora do campo de
         visão simplesmente desaparecia.

    DESEMPENHO — a decisão central
    ------------------------------
    O jeito ingênuo é criar Instance novas a cada frame. Com 30 Titãs e vários
    elementos cada, isso são centenas de instâncias destruídas e recriadas por
    frame: o coletor de lixo do Roblox engasga e o FPS cai.

    Aqui as instâncias 2D são criadas UMA vez por Titã e depois só têm suas
    propriedades atualizadas; um pool reutiliza os desenhos de Titãs que saíram
    da lista. Highlight e nameplate também são criados uma vez e só reutilizados.
    O tick é limitado a ~20 Hz: 60 Hz de ESP não melhora nada e custa CPU.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Game = __req("core/game")
local State = __req("core/state")
local Util = __req("core/util")
local Theme = __req("core/theme")

local Visuals = {}

-- Luau expõe math.atan2; Lua 5.4 só tem math.atan(y, x). O teste roda no
-- interpretador padrão, então a função é resolvida uma vez.
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local screen = nil      -- ScreenGui
local container = nil   -- Frame que segura os desenhos 2D
local drawings = {}     -- [model] = { box, line, label, hpBg, hpFill, hpText, napeDot, arrow, arrowText }
local highlights = {}   -- [model] = Highlight
local nameplates = {}   -- [model] = BillboardGui
local npLabels = {}     -- [model] = TextLabel dentro do BillboardGui
local pool = {}         -- desenhos 2D livres para reuso

local DRAW_KEYS = {
    "box", "line", "label", "hpBg", "hpFill", "hpText", "napeDot",
    "arrow", "arrowText",
}
local DRAW_2D_KEYS = {
    "box", "line", "label", "hpBg", "hpFill", "hpText", "napeDot",
}

local function colorFor(titan)
    if titan.isAttack then return Theme.color.ok end
    if titan.isBoss then return Theme.color.accentHi end
    return State.espColor()
end

-- A distância vem como math.huge quando o jogador ainda não tem personagem
-- (ou quando o root não está no espaço). string.format("%d") recusa infinito
-- e derrubaria o tick inteiro, então o texto é montado aqui.
local function distText(dist)
    dist = tonumber(dist)
    if not dist or dist ~= dist or dist == math.huge then return "—" end
    return tostring(math.floor(dist))
end

local function eachKey(map, fn)
    local keys = {}
    for k in pairs(map) do table.insert(keys, k) end
    for _, k in ipairs(keys) do fn(k) end
end

-- ── Construção do desenho 2D ─────────────────────────────────────────────────

local function buildDrawing()
    local d = {}

    if State.flags.espBox then
        d.box = Util.tag(Instance.new("Frame"))
        d.box.Name = "VHub_ESP_Box"
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
        d.line = Util.tag(Instance.new("Frame"))
        d.line.Name = "VHub_ESP_Line"
        d.line.AnchorPoint = Vector2.new(0, 0.5)
        d.line.BorderSizePixel = 0
        d.line.BackgroundColor3 = State.espColor()
        d.line.ZIndex = 1
    end

    if State.flags.espText then
        d.label = Util.tag(Instance.new("TextLabel"))
        d.label.Name = "VHub_ESP_Label"
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
        d.hpBg.Name = "VHub_ESP_HPBg"
        d.hpBg.BorderSizePixel = 0
        d.hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
        d.hpBg.ZIndex = 3

        d.hpFill = Util.tag(Instance.new("Frame"))
        d.hpFill.Name = "VHub_ESP_HPFill"
        d.hpFill.BorderSizePixel = 0
        d.hpFill.BackgroundColor3 = Theme.color.ok
        d.hpFill.ZIndex = 4

        d.hpText = Util.tag(Instance.new("TextLabel"))
        d.hpText.Name = "VHub_ESP_HPText"
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
        d.napeDot.Name = "VHub_ESP_Nape"
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

    if State.flags.espArrows then
        -- seta de borda: aponta para Titã fora da tela ou atrás da câmera.
        d.arrow = Util.tag(Instance.new("TextLabel"))
        d.arrow.Name = "VHub_ESP_Arrow"
        d.arrow.BackgroundTransparency = 1
        d.arrow.BorderSizePixel = 0
        d.arrow.Font = Theme.font.bold
        d.arrow.Text = "▲"
        d.arrow.TextSize = 22
        d.arrow.TextStrokeTransparency = 0
        d.arrow.TextStrokeColor3 = Color3.new(0, 0, 0)
        d.arrow.AnchorPoint = Vector2.new(0.5, 0.5)
        d.arrow.Size = UDim2.fromOffset(26, 26)
        d.arrow.ZIndex = 7

        d.arrowText = Util.tag(Instance.new("TextLabel"))
        d.arrowText.BackgroundTransparency = 1
        d.arrowText.Font = Theme.font.mono
        d.arrowText.TextSize = 10
        d.arrowText.TextStrokeTransparency = 0.2
        d.arrowText.TextStrokeColor3 = Color3.new(0, 0, 0)
        d.arrowText.TextXAlignment = Enum.TextXAlignment.Center
        d.arrowText.AnchorPoint = Vector2.new(0.5, 0)
        d.arrowText.Size = UDim2.fromOffset(120, 14)
        d.arrowText.ZIndex = 7
    end

    return d
end

local function parentDrawing(d)
    for _, k in ipairs(DRAW_KEYS) do
        if d[k] then d[k].Parent = container end
    end
end

local function hideDrawing(d)
    for _, k in ipairs(DRAW_KEYS) do
        if d[k] then d[k].Visible = false end
    end
end

local function hide2D(d)
    for _, k in ipairs(DRAW_2D_KEYS) do
        if d[k] then d[k].Visible = false end
    end
end

-- As opções de desenho mudam em runtime. Comparar uma assinatura evita
-- reconstruir o desenho a cada frame e garante que ligar/desligar um elemento
-- apareça na hora (a versão antiga só detectava a caixa).
local function drawingSignature()
    local parts = {}
    for _, flag in ipairs({
        "espBox", "espLine", "espText", "espHealth", "espNape", "espArrows",
    }) do
        table.insert(parts, State.flags[flag] and "1" or "0")
    end
    return table.concat(parts)
end

local function acquire(model)
    if drawings[model] then return drawings[model] end
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

-- Destrói de vez um desenho do pool. Diferente de Visuals.destroyDrawing, que
-- só esconde e devolve ao pool para reuso.
local function killDrawing(d)
    if not d then return end
    for _, k in ipairs(DRAW_KEYS) do
        if d[k] then pcall(function() d[k]:Destroy() end) end
    end
end

-- ── Highlight / nameplate ────────────────────────────────────────────────────

local function destroyHighlight(model)
    local h = highlights[model]
    if h then pcall(function() h:Destroy() end) end
    highlights[model] = nil
end

local function ensureHighlight(titan)
    local model = titan.model
    if not model then return nil end

    local h = highlights[model]
    if h and h.Parent then return h end

    h = Instance.new("Highlight")
    h.Name = "VHub_ESP"
    h.Adornee = model
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.FillTransparency = 0.7
    h.OutlineTransparency = 0.05
    h.Parent = model
    highlights[model] = h
    return h
end

local function destroyNameplate(model)
    local np = nameplates[model]
    if np then pcall(function() np:Destroy() end) end
    nameplates[model] = nil
    npLabels[model] = nil
end

local function ensureNameplate(titan)
    local model = titan.model
    if not model then return nil, nil end

    local np = nameplates[model]
    if np and np.Parent then return np, npLabels[model] end

    local host = titan.root or model
    if not host or host.Size == nil then return nil, nil end

    np = Instance.new("BillboardGui")
    np.Name = "VHub_Nameplate"
    np.Adornee = host
    np.AlwaysOnTop = true
    np.MaxDistance = 0          -- 0 = sem limite de distância
    np.Size = UDim2.new(0, 200, 0, 38)
    local size = host.Size
    local height = 4
    if type(size) == "table" or type(size) == "userdata" then
        height = tonumber(size.Y) or 4
    end
    np.StudsOffsetWorldSpace = Vector3.new(0, height + 3, 0)
    np.Parent = host

    local label = Instance.new("TextLabel")
    label.Name = "Info"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Theme.font.bold
    label.TextSize = 12
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextWrapped = true
    label.TextColor3 = Theme.color.text
    label.Parent = np

    nameplates[model] = np
    npLabels[model] = label
    return np, label
end

-- ── Projeção ─────────────────────────────────────────────────────────────────
-- WorldToViewportPoint devolve (Vector3, bool): o bool é false quando o ponto
-- está ATRÁS da câmera. Sem checar isso, o ESP desenha caixas espelhadas de
-- Titãs que estão nas suas costas.

local function project(pos, cam)
    if not (cam and pos) then return nil end
    local ok, v, onScreen = pcall(function()
        return cam:WorldToViewportPoint(pos)
    end)
    if not ok or not onScreen or v.Z <= 0 then return nil end
    return Vector2.new(v.X, v.Y), v.Z
end

-- Direção em coordenadas de tela para o indicador de borda. Em espaço de
-- câmera o eixo X cresce para a direita e o Y para cima; a tela cresce para
-- baixo, daí o sinal invertido. Quando o ponto está atrás (Z >= 0), a direção
-- é espelhada para a seta apontar para o lado certo ao virar.
local function screenDirection(pos, cam)
    if not (cam and pos) then return 0, 1 end
    local rel = cam.CFrame:PointToObjectSpace(pos)
    local sx = rel.X
    local sy = -rel.Y
    if rel.Z >= 0 then sx, sy = -sx, -sy end
    if math.abs(sx) < 1e-3 and math.abs(sy) < 1e-3 then sy = 1 end
    return sx, sy
end

-- ── Cálculo da caixa ─────────────────────────────────────────────────────────
-- Estima a caixa 2D a partir do tamanho real do modelo, projetando os cantos.
-- A altura vem do modelo, então a caixa acompanha Puro, Anormal e Colossal.

local function computeBox(titan, cam)
    local model = titan.model
    local ok, cf, size = pcall(function()
        return model:GetBoundingBox()
    end)

    if not ok then
        local p = titan.root.Position
        local top = project(p + Vector3.new(0, 3, 0), cam)
        local bot = project(p - Vector3.new(0, 3, 0), cam)
        if not (top and bot) then return nil end
        local h = math.abs(bot.Y - top.Y)
        return { x = top.X - h * 0.3, y = top.Y, w = h * 0.6, h = h }
    end

    local corners = {}
    for xi = -1, 1, 2 do
        for yi = -1, 1, 2 do
            for zi = -1, 1, 2 do
                local world = cf * Vector3.new(
                    size.X / 2 * xi, size.Y / 2 * yi, size.Z / 2 * zi)
                local scr = project(world, cam)
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

-- ── Setas de borda ───────────────────────────────────────────────────────────

local function showArrow(d, titan, cam, color)
    if not (d.arrow and cam) then return end

    local viewport = cam.ViewportSize or Vector2.new(1920, 1080)
    local cx, cy = viewport.X / 2, viewport.Y / 2
    local margin = math.min(90, math.min(cx, cy) * 0.35)
    local halfW = math.max(cx - margin, 12)
    local halfH = math.max(cy - margin, 12)

    local sx, sy = screenDirection(titan.root.Position, cam)
    local ax = math.max(math.abs(sx), 1e-3)
    local ay = math.max(math.abs(sy), 1e-3)
    local scale = math.min(halfW / ax, halfH / ay)

    local px, py = cx + sx * scale, cy + sy * scale
    d.arrow.Visible = true
    d.arrow.Position = UDim2.fromOffset(px, py)
    d.arrow.Rotation = math.deg(atan2(sy, sx)) + 90
    d.arrow.TextColor3 = color

    if d.arrowText then
        d.arrowText.Visible = true
        d.arrowText.Text = ("%s · %sm"):format(
            tostring(titan.name), distText(titan.dist))
        d.arrowText.Position = UDim2.fromOffset(px, py + 13)
        d.arrowText.TextColor3 = color
    end
end

-- ── Tick ─────────────────────────────────────────────────────────────────────

function Visuals.tick()
    if not (screen and screen.Parent) then return end

    local cam = Workspace.CurrentCamera
    if not cam then return end

    local signature = drawingSignature()
    if signature ~= Visuals._signature then
        Visuals._signature = signature
        eachKey(drawings, function(model) Visuals.destroyDrawing(model) end)
        -- O pool guarda desenhos montados com a assinatura ANTIGA. Devolvê-los
        -- a um Titã já rastreado faria o elemento recém-ligado nunca aparecer
        -- (o desenho não tem a instância que a flag nova pede).
        for _, d in ipairs(pool) do killDrawing(d) end
        pool = {}
    end

    local viewport = cam.ViewportSize or Vector2.new(1920, 1080)
    local originX, originY = viewport.X / 2, viewport.Y
    local color = State.espColor()
    local maxDist = tonumber(State.config.espMaxDist) or 1200
    local anywhere = State.flags.espAnywhere ~= false

    local titans = Game.getTitans()
    local live = {}

    for _, titan in ipairs(titans) do
        live[titan.model] = true

        -- Filtro de chefe e distância. "De qualquer lugar" ignora a distância,
        -- mas nunca o filtro explícito de somente chefes.
        local visible = not (State.flags.espBossOnly and not titan.isBoss)
        if visible and not anywhere and titan.dist > maxDist then visible = false end

        if not visible then
            local d = drawings[titan.model]
            if d then hideDrawing(d) end
            local h = highlights[titan.model]
            if h then h.Enabled = false end
            local np = nameplates[titan.model]
            if np then np.Enabled = false end
        else
            local titanColor = colorFor(titan)

            -- Camada 1 — atravessa paredes e distância.
            if State.flags.espHighlight then
                local h = ensureHighlight(titan)
                if h then
                    h.Enabled = true
                    h.FillColor = titanColor
                    h.OutlineColor = titanColor
                end
            else
                destroyHighlight(titan.model)
            end

            -- Camada 2 — identificação presa ao Titã.
            if State.flags.espNameplate then
                local np, label = ensureNameplate(titan)
                if np and label then
                    np.Enabled = true
                    local ratio = math.clamp(
                        (tonumber(titan.hp) or 0) / math.max(tonumber(titan.maxHp) or 1, 1), 0, 1)
                    label.Text = ("%s%s  ·  %sm  ·  %d%%"):format(
                        titan.isAttack and "[VOCÊ] " or "",
                        tostring(titan.name),
                        distText(titan.dist),
                        math.floor(ratio * 100))
                    label.TextColor3 = titanColor
                end
            else
                destroyNameplate(titan.model)
            end

            -- Camada 3 — projeção 2D.
            local projected = project(titan.root.Position, cam)
            local box = projected and computeBox(titan, cam) or nil
            local d = acquire(titan.model)

            if box and box.w > 1 and box.h > 1 then
                if d.box then
                    d.box.Visible = true
                    d.box.Position = UDim2.fromOffset(box.x, box.y)
                    d.box.Size = UDim2.fromOffset(box.w, box.h)
                    d.boxStroke.Color = titanColor
                    d.boxStroke.Thickness = State.config.espThickness
                end

                if d.line then
                    d.line.Visible = true
                    local fx, fy = box.x + box.w / 2, box.y + box.h
                    local dx, dy = fx - originX, fy - originY
                    local len = math.sqrt(dx * dx + dy * dy)
                    local ang = math.deg(atan2(dy, dx))
                    d.line.Position = UDim2.fromOffset(originX, originY)
                    d.line.Size = UDim2.fromOffset(len, 1)
                    d.line.Rotation = ang
                    d.line.BackgroundColor3 = titanColor
                    d.line.BackgroundTransparency = 0.35
                end

                if d.label then
                    d.label.Visible = true
                    d.label.Text = ("%s%s  ·  %sm"):format(
                        titan.isAttack and "[VOCÊ] " or "",
                        tostring(titan.name),
                        distText(titan.dist))
                    d.label.TextColor3 = titanColor
                    d.label.Position = UDim2.fromOffset(box.x - 30, box.y - 16)
                    d.label.Size = UDim2.fromOffset(box.w + 60, 14)
                end

                if d.hpBg and d.hpFill then
                    d.hpBg.Visible = true
                    d.hpFill.Visible = true
                    local ratio = math.clamp(
                        (tonumber(titan.hp) or 0) / math.max(tonumber(titan.maxHp) or 1, 1), 0, 1)
                    local barW, barH = 3, box.h

                    d.hpBg.Position = UDim2.fromOffset(box.x - 7, box.y)
                    d.hpBg.Size = UDim2.fromOffset(barW, barH)
                    d.hpFill.Position = UDim2.fromOffset(box.x - 7, box.y + barH * (1 - ratio))
                    d.hpFill.Size = UDim2.fromOffset(barW, barH * ratio)

                    local c
                    if ratio > 0.6 then c = Theme.color.ok
                    elseif ratio > 0.3 then c = Theme.color.warn
                    else c = Theme.color.danger end
                    d.hpFill.BackgroundColor3 = c

                    if d.hpText then
                        d.hpText.Visible = true
                        d.hpText.Text = Util.abbrev(titan.hp or 0)
                        d.hpText.Position = UDim2.fromOffset(box.x - 42, box.y + box.h / 2 - 6)
                        d.hpText.Size = UDim2.fromOffset(34, 12)
                        d.hpText.TextXAlignment = Enum.TextXAlignment.Right
                    end
                end

                if d.napeDot then
                    local np = project(titan.nape.Position, cam)
                    if np then
                        d.napeDot.Visible = true
                        d.napeDot.Position = UDim2.fromOffset(np.X - 3, np.Y - 3)
                        d.napeDot.Size = UDim2.fromOffset(6, 6)
                    else
                        d.napeDot.Visible = false
                    end
                end

                if d.arrow then d.arrow.Visible = false end
                if d.arrowText then d.arrowText.Visible = false end
            else
                -- Fora do campo de visão: nada de caixa, mas a seta continua.
                if d then
                    hide2D(d)
                    if State.flags.espArrows then
                        showArrow(d, titan, cam, titanColor)
                    elseif d.arrow then
                        d.arrow.Visible = false
                        if d.arrowText then d.arrowText.Visible = false end
                    end
                end
            end
        end
    end

    -- Recicla o que saiu do mapa. Sem isso, Highlight e nameplate de Titã
    -- destruído ficariam órfãos no modelo morto até o jogador sair.
    eachKey(drawings, function(model)
        if not live[model] then Visuals.destroyDrawing(model) end
    end)
    eachKey(highlights, function(model)
        if not live[model] then destroyHighlight(model) end
    end)
    eachKey(nameplates, function(model)
        if not live[model] then destroyNameplate(model) end
    end)
end

-- ── Ciclo de vida ────────────────────────────────────────────────────────────

function Visuals.hideAll()
    for _, d in pairs(drawings) do hideDrawing(d) end
    for _, h in pairs(highlights) do
        pcall(function() h.Enabled = false end)
    end
    for _, np in pairs(nameplates) do
        pcall(function() np.Enabled = false end)
    end
end

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

    Visuals._acc = 0
    Visuals._wasOn = false

    Visuals._conn = RunService.RenderStepped:Connect(function(dt)
        if not State.flags.esp then
            if Visuals._wasOn then
                Visuals.hideAll()
                Visuals._wasOn = false
            end
            return
        end
        Visuals._wasOn = true

        -- ~20 Hz. Um ESP a 60 Hz não fica mais legível e multiplica o custo
        -- de GetBoundingBox/projeção por três.
        Visuals._acc = (Visuals._acc or 0) + (tonumber(dt) or 0)
        if Visuals._acc < 0.05 then return end
        Visuals._acc = 0

        local ok, err = pcall(Visuals.tick)
        if not ok then warn("[VHub] ESP: " .. tostring(err)) end
    end)
    return true
end

function Visuals.clear()
    eachKey(drawings, function(model) Visuals.destroyDrawing(model) end)
    eachKey(highlights, function(model) destroyHighlight(model) end)
    eachKey(nameplates, function(model) destroyNameplate(model) end)

    for _, d in ipairs(pool) do killDrawing(d) end
    pool = {}
    Visuals._signature = nil
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
-- Lobby e Servidor são a fonte única das listas e das ações da Home. Não há
-- ciclo: nenhum dos dois conhece a UI (só core/game, core/state e core/util).
local Lobby = __req("features/lobby")
local Server = __req("features/server")
-- Missão entra só pela leitura de estado (abates/alvo) e pelo teste de golpe.
-- mission.lua não conhece a UI, então não há ciclo.
local Mission = __req("features/mission")

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

-- Conexões feitas em serviços (UserInputService) que precisam ser desligadas
-- no unmount. Sem isso, cada remontagem deixaria um listener antigo vivo,
-- alternando a visibilidade duas ou três vezes por tecla.
local connections = {}

-- Hooks chamados depois de cada montagem (inclusive a primeira). O main usa
-- para remontar o ESP no ScreenGui novo.
local remountHooks = {}

-- Módulos ligados em tempo de execução. O main chama bindLobby/bindServer;
-- os padrões abaixo garantem que a UI também funcione sozinha nos testes.
local Lobby_ref = Lobby
local Server_ref = Server

-- Registro dos controles para o rebuild após carregar configuração.
-- Precisa existir ANTES dos builders rodarem — eles escrevem aqui.
UI.controls = {}
UI.VERSION = "2.0.0"

-- Teclas oferecidas no seletor. A lista cobre o que os executores costumam
-- deixar livre; não tentamos capturar qualquer tecla (conflitaria com o jogo).
local MENU_KEYS = {
    "RightControl", "RightShift", "LeftControl", "LeftShift",
    "Insert", "Home", "End", "K", "P", "F1", "F2",
}

local function track(conn)
    if conn then table.insert(connections, conn) end
    return conn
end

local function menuScaleValue()
    local pct = tonumber(State.config.menuScale) or 100
    return math.clamp(pct, 70, 140) / 100
end

local function shortKey(name)
    return (tostring(name or "RightControl"):gsub("Control", "Ctrl"))
end

local function keyFromName(name)
    if type(name) ~= "string" then return nil end
    local ok, code = pcall(function() return Enum.KeyCode[name] end)
    if ok then return code end
    return nil
end

local function serverSummary()
    local s = Server_ref.info()
    local job = s.shortJob
    if not job or job == "" then job = "indisponível" end
    return ("Job %s\nPlaceId %s · universo %s\n%s jogadores no servidor"):format(
        job, tostring(s.placeId), tostring(s.universeId), tostring(s.players))
end

local function profileSummary()
    local names = State.profileList()
    local auto = State.profileAutoload()
    local listed = #names > 0 and table.concat(names, ", ") or "nenhum"
    if #listed > 110 then listed = listed:sub(1, 107) .. "…" end
    return ("Autoload atual: %s\nPerfis (%d): %s"):format(
        auto or "nenhum", #names, listed)
end

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

    -- Escala do menu em tempo real. UIScale reduz/amplia o Frame inteiro sem
    -- tocar no layout interno — por isso o slider não precisa remontar a UI.
    UI.scale = Instance.new("UIScale")
    UI.scale.Scale = menuScaleValue()
    UI.scale.Parent = root

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
    track(head.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = root.Position
        end
    end))
    track(head.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            root.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
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

    UI.keyHint = Widget.label({
        parent = statusBar,
        text = ("%s · ocultar"):format(shortKey(State.config.menuKey)),
        position = UDim2.new(1, -160, 0, 0),
        size = UDim2.fromOffset(160, 26),
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

    -- ── Servidor
    -- Ferramentas de sessão: reentrar, trocar de servidor e copiar os
    -- identificadores. Nenhuma delas depende de estado interno da UI.
    local srvSec = Widget.section({ parent = page, text = "Servidor" })
    srvSec.instance.LayoutOrder = 4
    UI.serverInfo = Widget.info({
        parent = srvSec.body,
        text = serverSummary(),
        order = 1,
    })

    addButton(srvSec, 2, "Reentrar no servidor", "solid", function()
        Server_ref.rejoin()
    end)
    addButton(srvSec, 3, "Server Hop", "ghost", function()
        Server_ref.serverHop()
    end)
    addButton(srvSec, 4, "Entrar no servidor mais vazio", "ghost", function()
        Server_ref.joinLowest()
    end)
    addButton(srvSec, 5, "Copiar Job ID", "ghost", function()
        Server_ref.copyJobId()
    end)
    addButton(srvSec, 6, "Copiar universo", "ghost", function()
        Server_ref.copyUniverse()
    end)
    addButton(srvSec, 7, "Copiar convite do servidor", "ghost", function()
        Server_ref.copyInvite()
    end)
    addInfo(srvSec, 8,
        "Server Hop e Servidor mais vazio consultam a lista pública da Roblox e precisam de request/http_request no executor. A lista só traz servidores públicos com vaga.")

    -- ── Comunidade
    local commSec = Widget.section({ parent = page, text = "Comunidade" })
    commSec.instance.LayoutOrder = 5
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
    local killInfo = Widget.info({
        parent = titas.body,
        text = Mission.statusLine(),
        order = 8,
    })
    UI.killInfo = killInfo
    addButton(titas, 9, "Testar golpe agora", "solid", function()
        local ok, detail = Mission.testStrike()
        if ok then
            UI.notify("Teste de golpe", tostring(detail), 10)
        else
            UI.notify("Teste de golpe", tostring(detail), 8)
        end
    end)
    addInfo(titas, 10,
        "O alcance real da lâmina é curto. Com \"Mirar na nuca\" ligado o script chega a ~4 studs do alvo; sem ele, a magnitude precisa cobrir o alcance. USE O TESTE DE GOLPE antes de confiar no auto kill: ele mostra a vida antes/depois e qual remote respondeu.")

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
    addSlider(nuca, 3, "napeSize", "Tamanho absoluto", 0, 400, " studs", 0)
    addSlider(nuca, 4, "napeScale", "Multiplicador", 0, 2, "x", 1)
    addSlider(nuca, 5, "napeTransparency", "Transparência", 0, 1, "", 2)
    addInfo(nuca, 6,
        "Tamanho de fábrica da nuca: 15 × 9 × 11. O tamanho absoluto tem prioridade quando é maior que 0 (280 é o valor do AirFlow); com 0, vale o multiplicador. Tudo é restaurado ao desligar.")

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
    -- As listas vêm do módulo Lobby: uma fonte única para UI e execução.
    local maps = { "Automático" }
    for _, m in ipairs(Lobby_ref.MAPS) do table.insert(maps, m) end

    addDropdown(mis, 3, "missionType", "Modo", Lobby_ref.TYPES)
    addDropdown(mis, 4, "mapName", "Mapa", maps)
    addDropdown(mis, 5, "objective", "Objetivo", Lobby_ref.OBJECTIVES)
    addDropdown(mis, 6, "difficulty", "Dificuldade", Lobby_ref.DIFFICULTIES)
    addDropdown(mis, 7, "raid", "Titã (modo Raids)", Lobby_ref.RAID_NAMES)

    local modChips = Widget.chips({
        parent = mis.body,
        text = "Modificadores",
        options = Lobby_ref.MODIFIERS,
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
    addToggle(esp, 2, "espAnywhere", "Ver de qualquer lugar",
        "Ignora a distância: Highlight + nome aparecem no mapa inteiro")
    addToggle(esp, 3, "espHighlight", "Contorno 3D",
        "Aplica Highlight no Titã, atravessando paredes e terreno")
    addToggle(esp, 4, "espNameplate", "Nome e vida sobre o Titã",
        "Billboard preso ao modelo, sem limite de distância")
    addToggle(esp, 5, "espArrows", "Setas fora da tela",
        "Aponta para Titãs atrás de você ou fora do campo de visão")
    addToggle(esp, 6, "espBox", "Caixa")
    addToggle(esp, 7, "espLine", "Linha de rastreio")
    addToggle(esp, 8, "espText", "Nome e distância na tela")
    addToggle(esp, 9, "espHealth", "Barra de vida")
    addToggle(esp, 10, "espNape", "Marcar a nuca")
    addToggle(esp, 11, "espBossOnly", "Somente chefes", "Esconde os Titãs puros")
    addDropdown(esp, 12, "espColor", "Cor", {
        "Vermelho", "Branco", "Verde", "Azul", "Amarelo", "Rosa", "Ciano" })
    addSlider(esp, 13, "espMaxDist", "Distância máxima (2D)", 100, 10000, " studs")
    addSlider(esp, 14, "espThickness", "Espessura", 1, 4, "", 1)
    addInfo(esp, 15,
        "Com \"Ver de qualquer lugar\" ligado, a distância máxima só limita a caixa/linha 2D. O contorno 3D, o nome e as setas continuam valendo para o mapa inteiro.")

    pages.visual = { frame = page }
end

-- ── Página: Config ───────────────────────────────────────────────────────────

local function refreshProfileInfo()
    if UI.profileInfo then UI.profileInfo:set(profileSummary()) end
end

-- Aplica uma cor e remonta no próximo ciclo. Remontar de dentro do callback de
-- um widget destruiria o próprio controle que ainda está executando.
local function applyThemeColor(color, presetName)
    if not color then return false end
    State.config.accentColor = Theme.toHex(color)
    State.config.themePreset = presetName or Theme.presetFor(color)
    Theme.applyAccent(color)
    task.defer(function() UI.remount() end)
    return true
end

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

    -- ── Menu e tema
    local menu = Widget.section({ parent = page, text = "Menu e Tema" })
    menu.instance.LayoutOrder = 1

    local scale = Widget.slider({
        parent = menu.body,
        text = "Tamanho do menu",
        min = 70, max = 140,
        default = State.config.menuScale,
        suffix = "%", decimals = 0,
        onChange = function(v) UI.applyMenuScale(v) end,
    })
    scale.instance.LayoutOrder = 1
    UI.controls.menuScale = scale

    addDropdown(menu, 2, "menuKey", "Tecla de abrir/fechar", MENU_KEYS, function(v)
        if UI.keyHint then
            UI.keyHint.Text = ("%s · ocultar"):format(shortKey(v))
        end
    end)

    local accent = Theme.fromHex(State.config.accentColor) or Theme.DEFAULT_ACCENT
    local presetOptions = { "Personalizado" }
    for _, name in ipairs(Theme.PRESET_ORDER) do table.insert(presetOptions, name) end

    addDropdown(menu, 3, "themePreset", "Preset de tema",
        presetOptions,
        function(name)
            if name == "Personalizado" then
                UI.notify("Tema", "Use o campo hex abaixo para escolher uma cor própria.", 4)
                return
            end
            local color = Theme.presetColor(name)
            if color then applyThemeColor(color, name) end
        end)

    local accentInput = Widget.input({
        parent = menu.body,
        text = "Cor de destaque (hex)",
        default = Theme.toHex(accent) or "#E02D2D",
        placeholder = "#E02D2D",
        onSubmit = function(value)
            local color = Theme.fromHex(value)
            if not color then
                UI.notify("Tema", "Cor inválida. Use #RRGGBB.", 4)
                return
            end
            applyThemeColor(color)
        end,
    })
    accentInput.instance.LayoutOrder = 4
    UI.controls.accentColor = accentInput

    addButton(menu, 5, "Restaurar tema do VHub", "ghost", function()
        applyThemeColor(Theme.DEFAULT_ACCENT, "VHub")
    end)
    addInfo(menu, 6,
        "O tamanho e a tecla mudam na hora. A cor de destaque e o preset remontam a interface para repintar todos os controles. Tudo é salvo no vhub_config.json.")

    local sis = Widget.section({ parent = page, text = "Sistema" })
    sis.instance.LayoutOrder = 2
    addToggle(sis, 1, "antiAfk", "Anti-AFK", "Impede a desconexão por inatividade")
    addToggle(sis, 2, "watermark", "Marca d'água")
    addToggle(sis, 3, "notifications", "Notificações")

    local av = Widget.section({ parent = page, text = "Avançado" })
    av.instance.LayoutOrder = 3
    addSlider(av, 1, "hitMagnitude", "Magnitude do acerto", 5, 10000, "", 0)
    addSlider(av, 2, "hitOffset", "Offset do acerto", 0, 100, "", 0)
    addDropdown(av, 3, "registerMethod", "Remote do Register",
        { "POST", "GET", "Ambos" })
    addInfo(av, 4,
        "A magnitude declara a distância do golpe em studs. O padrão 60 cobre o alcance curto com folga; 143–850 são valores de scripts públicos e o sinal mais fácil do servidor auditar.\n\nPOST usa o RemoteEvent (padrão dos scripts recentes); GET usa o RemoteFunction (Tekkit/StwFate); Ambos tenta os dois. Se o auto kill não causar dano, altere só este campo e use \"Testar golpe\".",
        true)

    local dados = Widget.section({ parent = page, text = "Dados" })
    dados.instance.LayoutOrder = 4
    addButton(dados, 1, "Salvar configuração", "ghost", function()
        if State.save() then UI.notify("Configuração", "Salvo com sucesso.")
        else UI.notify("Configuração", "Seu executor não permite salvar arquivos.", 4) end
    end)
    addButton(dados, 2, "Carregar configuração", "ghost", function()
        if State.load() then
            Theme.applyConfig(State.config)
            UI.applyMenuScale(State.config.menuScale)
            UI.notify("Configuração", "Carregada.")
            task.defer(function() UI.remount() end)
        else
            UI.notify("Configuração", "Nenhum arquivo encontrado.", 4)
        end
    end)
    addButton(dados, 3, "Diagnóstico do jogo", "solid", function() UI.showDiagnostic() end)
    addButton(dados, 4, "Checar marcação da conta", "danger", function() UI.checkFlag() end)
    addButton(dados, 5, "Descarregar script", "danger", function()
        if not UI.requestShutdown() then
            UI.notify("VHub", "O descarregamento não foi ligado pela entrada do script.", 5)
        end
    end)

    -- ── Perfis nomeados
    local prof = Widget.section({ parent = page, text = "Perfis de Configuração" })
    prof.instance.LayoutOrder = 5

    local nameInput = Widget.input({
        parent = prof.body,
        text = "Nome do perfil",
        placeholder = "ex: farm seguro",
    })
    nameInput.instance.LayoutOrder = 1

    addButton(prof, 2, "Criar perfil com o estado atual", "ghost", function()
        local ok, err = State.profileCreate(nameInput.get())
        if ok then UI.notify("Perfil", "Perfil criado.")
        else UI.notify("Perfil", tostring(err), 4) end
        refreshProfileInfo()
    end)
    addButton(prof, 3, "Salvar (criar ou substituir)", "solid", function()
        local ok, err = State.profileSave(nameInput.get())
        if ok then UI.notify("Perfil", "Estado salvo no perfil.")
        else UI.notify("Perfil", tostring(err), 4) end
        refreshProfileInfo()
    end)
    addButton(prof, 4, "Carregar perfil", "ghost", function()
        local ok, err = State.profileLoad(nameInput.get())
        if not ok then
            UI.notify("Perfil", tostring(err), 4)
            return
        end
        Theme.applyConfig(State.config)
        UI.applyMenuScale(State.config.menuScale)
        task.defer(function()
            UI.remount()
            UI.notify("Perfil", "Perfil carregado.")
        end)
    end)
    addButton(prof, 5, "Apagar perfil", "danger", function()
        local ok, err = State.profileDelete(nameInput.get())
        if ok then UI.notify("Perfil", "Perfil apagado.")
        else UI.notify("Perfil", tostring(err), 4) end
        refreshProfileInfo()
    end)
    addButton(prof, 6, "Definir como autoload", "ghost", function()
        local ok, err = State.profileSetAutoload(nameInput.get())
        if ok then UI.notify("Perfil", "Perfil definido como autoload.")
        else UI.notify("Perfil", tostring(err), 4) end
        refreshProfileInfo()
    end)
    addButton(prof, 7, "Limpar autoload", "ghost", function()
        local ok, err = State.profileSetAutoload(nil)
        if ok then UI.notify("Perfil", "Autoload removido.")
        else UI.notify("Perfil", tostring(err), 4) end
        refreshProfileInfo()
    end)

    local profInfo = Widget.info({
        parent = prof.body,
        text = profileSummary(),
        order = 8,
    })
    UI.profileInfo = profInfo

    local sobre = Widget.section({ parent = page, text = "Sobre" })
    sobre.instance.LayoutOrder = 6
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
        -- A interface pode ter sido remontada/descarregada durante a vida do
        -- toast; o card já foi destruído junto com o ScreenGui antigo. Criar um
        -- tween num Instance destruído lança erro fora de qualquer pcall.
        if not card.Parent then return end
        Widget.tween(card, Theme.ease.fast, { Position = UDim2.new(1, 24, 1, 0) })
        task.wait(0.15)
        for i, c in ipairs(toasts) do if c == card then table.remove(toasts, i) break end end
        if card.Parent then card:Destroy() end
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
        ("Remotes: %s (GET=%s · POST=%s)"):format(
            r.remotesFound and "ok" or "AUSENTES",
            tostring(r.remoteGetClass or "?"), tostring(r.remotePostClass or "?")),
        ("Pasta de Titãs: %s"):format(r.hasTitanFolder and "presente" or "ausente aqui"),
        ("Titãs vivos: %s"):format(tostring(r.titanCount)),
        ("Shifter (Attack_Titan): %s"):format(r.shifter and "sim" or "não"),
    }
    if r.sampleTitan then
        table.insert(lines, ("Exemplo: %s [%s]"):format(r.sampleTitan, r.sampleKind or "?"))
        table.insert(lines, ("Nuca: %s"):format(r.sampleNape or "não encontrada"))
        table.insert(lines, ("Alvo do Register: %s%s"):format(
            tostring(r.sampleTarget or "?"), r.sampleMarker and " (Marker)" or ""))
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
    -- Captura o gui DESTA montagem. Se a interface for remontada, o gui antigo
    -- é destruído e este loop sai sozinho — em vez de continuar escrevendo num
    -- ScreenGui morto (e acumular um loop por remontagem).
    local myGui = gui

    task.spawn(function()
        -- Identidade: uma vez só, não muda durante a sessão.
        local info = Stats.playerInfo()
        if info then
            UI.heroName.Text = info.display or info.name
            UI.heroSub.Text = ("@%s · conta de %d dias"):format(info.name, info.accountAge or 0)
            if info.avatar then UI.avatar:set(info.avatar) end
        end

        local last = os.clock()
        while myGui and myGui.Parent do
            local now = os.clock()
            local dt = now - last
            last = now

            pcall(function()
                local snap = Stats.snapshot()
                if UI.serverInfo then UI.serverInfo:set(serverSummary()) end
                if UI.killInfo then UI.killInfo:set(Mission.statusLine()) end

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

function UI.bindLobby(mod)
    if mod then Lobby_ref = mod end
end

function UI.bindServer(mod)
    if mod then Server_ref = mod end
end

-- O descarregamento pertence à entrada (main), que conhece todos os módulos.
-- A UI só guarda a função e a chama fora do callback do botão: destruir a
-- própria interface dentro do clique derrubaria o widget que está executando.
local shutdownHandler = nil

function UI.bindShutdown(fn)
    if type(fn) == "function" then shutdownHandler = fn end
end

function UI.requestShutdown()
    if not shutdownHandler then return false end
    local fn = shutdownHandler
    UI.notify("VHub", "Descarregando script…", 2)
    task.defer(function()
        local ok, err = pcall(fn)
        if not ok then warn("[VHub] falha ao descarregar: " .. tostring(err)) end
    end)
    return true
end

-- Tamanho do menu em tempo real. O UIScale é recriado a cada montagem, então
-- a função tolera UI.scale nil (antes do mount) sem quebrar.
function UI.applyMenuScale(value)
    local pct = math.clamp(tonumber(value) or 100, 70, 140)
    State.config.menuScale = pct
    if UI.scale then UI.scale.Scale = pct / 100 end
    return pct
end

-- Registra um hook executado depois de cada montagem (inclusive a primeira).
function UI.onRemount(fn)
    if type(fn) == "function" then table.insert(remountHooks, fn) end
    return fn
end

function UI.currentTab()
    return activeTab
end

function UI.mount()
    if gui then UI.unmount() end
    connections = {}

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

    track(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        local code = keyFromName(State.config.menuKey)
        if code ~= nil and input.KeyCode == code then
            UI.setVisible(not UI.isVisible())
        end
    end))

    UI.setStatus(("Pronto · %s"):format(Util.executorName()))
    refreshLoop()

    for _, fn in ipairs(remountHooks) do
        local ok, err = pcall(fn, gui)
        if not ok then warn("[VHub] hook de remonte falhou: " .. tostring(err)) end
    end

    return gui
end

-- Remonta a interface preservando aba, visibilidade e estado minimizado.
-- Usado quando o tema muda (as instâncias antigas guardaram cores).
function UI.remount()
    local tab = activeTab
    local wasVisible = gui and gui.Enabled
    local wasMinimized = minimized

    UI.unmount()
    local newGui = UI.mount()

    if tab then UI.selectTab(tab) end
    if wasMinimized then UI.setMinimized(true) end
    if wasVisible ~= nil then UI.setVisible(wasVisible) end
    return newGui
end

function UI.unmount()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}

    -- Sliders e dropdowns escutam UserInputService por conta própria; sem isso
    -- cada remontagem deixaria um ouvinte antigo vivo.
    Widget.releaseConnections()

    if gui then gui:Destroy(); gui = nil end

    UI.controls = {}
    tabs, pages = {}, {}
    statCards = {}
    toasts = {}
    toastHolder = nil
    root, sidebar, content, statusBar = nil, nil, nil, nil
    UI.scale = nil
    activeTab = "home"
    minimized = false
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
local Server    = __req("features/server")
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

-- ── Reexecução ───────────────────────────────────────────────────────────────
-- Rodar o loadstring duas vezes sem descarregar deixava dois laços, dois ESPs e
-- dois ouvintes da tecla do menu vivos. Se já existe um Hub nesta sessão,
-- desliga o anterior antes de montar o novo.
local genv = nil
if Util.getGenv then
    local ok, g = pcall(Util.getGenv)
    if ok then genv = g end
end

if genv and genv.VHub and genv.VHub.__vhub then
    pcall(function() genv.VHub.shutdown() end)
end

-- ── Hub ──────────────────────────────────────────────────────────────────────

local Hub = {}
Hub.version = "2.0.0"
Hub.placeId = game.PlaceId
Hub.placeKind = kind
Hub.__vhub = true

Interface.VERSION = Hub.version
Interface.bindLobby(Lobby)
Interface.bindServer(Server)

-- Preferências antes da UI, para os controles nascerem certos. O autoload tem
-- a última palavra: é o perfil que o usuário mandou carregar em toda entrada.
local loaded = State.load()
local autoloaded, autoloadName = State.loadAutoload()
Theme.applyConfig(State.config)

-- O ESP vive dentro do ScreenGui da interface. Toda remontagem (mudança de
-- tema, por exemplo) precisa desligar o antigo e montar no gui novo.
Interface.onRemount(function(screenGui)
    Visuals.unmount()
    Visuals.mount(screenGui)
end)

-- ── Encerramento limpo ───────────────────────────────────────────────────────
-- Definido antes do mount porque o botão "Descarregar script" precisa dele.
-- Cada parada vai em pcall: uma feature quebrada não pode impedir as outras de
-- soltar conexões e sair da memória.
local function shutdown()
    pcall(function() Mission.stopAttack() end)
    pcall(function() Mission.stop() end)
    pcall(function() Lobby.stop() end)
    pcall(function() Post.stop() end)
    pcall(function() Utility.stop() end)
    pcall(function() Stats.stop() end)
    pcall(function() Visuals.unmount() end)
    pcall(function() Interface.unmount() end)
    pcall(function() State.save() end)
    if genv and genv.VHub == Hub then genv.VHub = nil end
end
Hub.shutdown = shutdown
Interface.bindShutdown(shutdown)

Interface.mount()

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

-- ── Boas-vindas ──────────────────────────────────────────────────────────────

task.delay(0.8, function()
    Interface.notify("VHub",
        ("v%s · %s · %s para abrir."):format(
            Hub.version, kind, tostring(State.config.menuKey or "RightControl")), 5)

    if loaded then
        Interface.notify("Configuração", "Preferências restauradas.", 3)
    end

    if autoloaded then
        Interface.notify("Perfil",
            ("Perfil '%s' carregado automaticamente."):format(tostring(autoloadName)), 4)
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
