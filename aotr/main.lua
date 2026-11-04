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

-- ── Identidade do jogo ───────────────────────────────────────────────────────
-- O NOME do jogo muda a cada update ("[UPDATE 5] ..."), então nunca serve de
-- guarda. Estes dois valores são estáveis.
Game.ROOT_PLACE_ID = 13379208636
Game.UNIVERSE_ID   = 4658598196
Game.CREATOR_ID    = 17347863   -- grupo "AoTR [PI]"

function Game.isAOTR()
    if game.PlaceId == Game.ROOT_PLACE_ID then return true end
    -- CreatorId não é exposto ao cliente Lua. A impressão digital confiável é a
    -- presença dos dois remotes, que é o que os próprios scripts usam — e
    -- sobrevive a re-upload do place sob outro id.
    return Game.getRemotes().ok
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

    local report = {
        placeId = game.PlaceId,
        isAOTR = (game.PlaceId == Game.ROOT_PLACE_ID),
        remotesFound = r.ok,
        titanCount = #titans,
        sampleTitan = nil,
        sampleNape = nil,
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
        report.sampleNape = t.nape.Name
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

-- ── core/state ────────────────────────────────────────────────
MODULES["core/state"] = function()
local __src = [=[
--[[
    AOTR · Barramento de Estado
    Arquivo: src/core/state.lua

    Cada feature declara seu estado aqui. A UI lê e escreve só neste objeto;
    nenhuma feature conhece a UI, nenhuma UI conhece a implementação de uma
    feature. É o que permite ligar/desligar tudo sem dependência circular.

    `config` é separado de `flags`: flags são booleanos (ligado/desligado),
    config são parâmetros (distância, velocidade, cor). Salvar e carregar
    mexe só nesses dois.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local State = {}

-- ── Flags (booleanos) ────────────────────────────────────────────────────────
State.flags = {
    -- Combate
    killAura      = false,
    killAuraNape  = true,    -- mirar a nuca (crítico) em vez do corpo
    autoTP        = false,

    -- Auxílio de combate
    napeExpander  = false,
    autoRefill    = false,
    infiniteGas   = false,

    -- Segurança
    safeFarm      = true,    -- trava anti-shadow-ban: não fecha missão rápido

    -- Progressão
    autoRoll      = false,
    masteryFarm   = false,
    goldFarm      = false,
    instantRetry  = false,

    -- Visual
    esp           = false,
    espBox        = true,
    espLine       = true,
    espText       = true,
    espDistance   = true,
    espHealth     = true,
    espNape       = true,
    espBossOnly   = false,

    -- Sistema
    antiAfk       = true,
    watermark     = true,
    notifications = true,
}

-- ── Config (parâmetros) ──────────────────────────────────────────────────────
State.config = {
    -- Combate
    killAuraRange   = 25,     -- studs; o alcance real da lâmina é curto
    killAuraDelay   = 0.12,

    -- Magnitude declarada em Hitboxes/Register.
    -- Referência de mercado: scripts populares usam 215-230, o que é
    -- fisicamente impossível e o candidato nº 1 a gatilho de detecção.
    -- 12 é o comprimento aproximado da lâmina. Suba por sua conta e risco.
    hitMagnitude    = 12,
    hitOffset       = 0,

    -- Auto TP
    tpRange         = 120,
    tpOffset        = 4,
    tpCooldown      = 0.4,

    -- Nape Expander
    napeScale       = 2.5,
    napeTransparency= 0.35,

    -- Anti-shadow-ban
    safeTime        = 32,     -- segundos mínimos por missão (campo testado)

    -- Visual
    espMaxDist      = 900,
    espColor        = "Vermelho",
    espThickness    = 1.4,
}

-- Cor do ESP derivada do nome escolhido na UI.
State.ESP_COLORS = {
    ["Vermelho"] = Color3.fromRGB(215, 38, 61),
    ["Branco"]   = Color3.fromRGB(240, 241, 245),
    ["Verde"]    = Color3.fromRGB(96, 190, 140),
    ["Azul"]     = Color3.fromRGB(108, 150, 220),
    ["Amarelo"]  = Color3.fromRGB(226, 168, 72),
    ["Rosa"]     = Color3.fromRGB(230, 120, 180),
    ["Ciano"]    = Color3.fromRGB(90, 200, 210),
}

function State.espColor()
    return State.ESP_COLORS[State.config.espColor] or State.ESP_COLORS["Vermelho"]
end

-- ── Observadores ─────────────────────────────────────────────────────────────
-- Features que precisam reagir a uma mudança (ex: ESP ligado -> criar desenhos)
-- se inscrevem aqui, em vez de a UI chamar a feature diretamente.

local watchers = {}

function State.on(flag, fn)
    watchers[flag] = watchers[flag] or {}
    table.insert(watchers[flag], fn)
    -- dispara imediatamente com o estado atual, para que a feature nasça
    -- sincronizada mesmo se a flag já estiver ligada
    fn(State.flags[flag])
end

function State.set(flag, value)
    if State.flags[flag] == value then return end
    State.flags[flag] = value
    for _, fn in ipairs(watchers[flag] or {}) do
        local ok, err = pcall(fn, value)
        if not ok then
            warn(("[AOTR] observador de '%s' falhou: %s"):format(flag, tostring(err)))
        end
    end
end

function State.toggle(flag)
    State.set(flag, not State.flags[flag])
end

function State.get(flag)
    return State.flags[flag]
end

-- ── Persistência ─────────────────────────────────────────────────────────────
-- Um único arquivo JSON via executor. Envolvido em pcall porque nem todo
-- executor expõe writefile, e o script precisa rodar mesmo sem persistência.

local CONFIG_PATH = "aotr_config.json"

function State.save()
    local ok, err = pcall(function()
        if not writefile then return end
        local payload = {
            flags = State.flags,
            config = State.config,
        }
        -- Color3 não serializa; guardamos só o nome (já é string).
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
            State.flags[k] = v   -- direto: não dispara watchers antes da UI existir
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

-- ── core/theme ────────────────────────────────────────────────
MODULES["core/theme"] = function()
local __src = [=[
--[[
    AOTR · Núcleo de Tema
    Arquivo: src/core/theme.lua

    Paleta preta / vermelha / cinza-gradiente, derivada do estudo do AirFlow
    (fundo #060608, accent dessaturado, cantos suaves, glow sutil) mas invertida
    para o eixo vermelho e com profundidade real em vez de cor chapada.

    Cada token é calculado a partir de três âncoras — tinta, sangue, cinza —
    para que mudar a identidade inteira seja editar 3 constantes, não 40.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Theme = {}

-- ── Âncoras ──────────────────────────────────────────────────────────────────
-- Tinta   : o preto de fundo. Não é #000 — preto puro achata a percepção de
--           camada. 0x07/0x08 dá espaço para sombra abaixo e realce acima.
-- Sangue  : o vermelho de assinatura. 0xD7263D é quente e legível sobre tinta;
--           vermelhos mais escuros (0x8B0000) somem em telas de contraste baixo.
-- Cinza   : o neutro de texto e borda, levemente azulado para não brigar com o
--           vermelho.
local TINTA  = Color3.fromRGB(7, 8, 10)
local SANGUE = Color3.fromRGB(215, 38, 61)
local CINZA  = Color3.fromRGB(150, 154, 165)

-- Mistura linear em espaço RGB. Suficiente aqui: as paradas são próximas o
-- bastante para que a diferença com espaço linear seja imperceptível.
local function mix(a, b, t)
    return Color3.new(
        a.R + (b.R - a.R) * t,
        a.G + (b.G - a.G) * t,
        a.B + (b.B - a.B) * t
    )
end

local function lighten(c, t) return mix(c, Color3.new(1, 1, 1), t) end
local function darken(c, t)  return mix(c, Color3.new(0, 0, 0), t) end

-- ── Superfícies ──────────────────────────────────────────────────────────────
-- Escala de elevação: quanto mais perto da luz, mais claro. É isso que cria a
-- sensação de profundidade — um painel sobre outro precisa de um degrau visível.
Theme.color = {
    -- fundo
    void        = TINTA,                        -- atrás de tudo
    base        = mix(TINTA, CINZA, 0.045),     -- corpo da janela
    surface     = mix(TINTA, CINZA, 0.075),     -- cartão
    surfaceHi   = mix(TINTA, CINZA, 0.105),     -- cartão sob o mouse
    surfaceTop  = mix(TINTA, CINZA, 0.130),     -- cabeçalho fixo

    -- traço
    line        = mix(TINTA, CINZA, 0.155),     -- divisória de 1px
    lineSoft    = mix(TINTA, CINZA, 0.095),     -- divisória interna
    lineHot     = mix(SANGUE, TINTA, 0.45),     -- borda acesa

    -- texto
    text        = Color3.fromRGB(240, 241, 245),
    textDim     = mix(CINZA, TINTA, 0.20),
    textMute    = mix(CINZA, TINTA, 0.48),

    -- assinatura
    accent      = SANGUE,
    accentHi    = lighten(SANGUE, 0.28),
    accentLo    = darken(SANGUE, 0.34),
    accentGhost = mix(SANGUE, TINTA, 0.86),     -- preenchimento de 14%

    -- estados (dessaturados para não competir com o accent)
    on          = Color3.fromRGB(198, 62, 78),
    off         = mix(TINTA, CINZA, 0.20),
    warn        = Color3.fromRGB(226, 168, 72),
    danger      = Color3.fromRGB(232, 58, 58),
    ok          = Color3.fromRGB(96, 190, 140),
    info        = Color3.fromRGB(108, 150, 220),
}

-- ── Gradiente ────────────────────────────────────────────────────────────────
-- Roblox não tem gradiente nativo em Instance sem UIGradient. Em vez de criar
-- 200 UIGradients (custo de instância), pré-computo as paradas e as reuso.
-- O cinza-gradiente pedido vive aqui: cinza quente no topo, cinza frio embaixo.
--
-- LIMITE IMPORTANTE: ColorSequence e NumberSequence aceitam NO MÁXIMO 20
-- keypoints. Com 21 ou mais, o construtor levanta "table is too long" e derruba
-- o script inteiro antes da UI montar — a janela aparece branca e nada funciona.
-- 24 paradas foi exatamente esse erro na primeira versão em produção.
Theme.SEQUENCE_LIMIT = 20
Theme.gradient = {}
do
    local STOPS = Theme.SEQUENCE_LIMIT
    local topo = mix(CINZA, Color3.new(1, 1, 1), 0.10)
    local meio = mix(TINTA, CINZA, 0.10)
    local fundo = darken(TINTA, 0.25)
    for i = 0, STOPS - 1 do
        local t = i / (STOPS - 1)
        local c
        if t < 0.5 then
            c = mix(topo, meio, t / 0.5)
        else
            c = mix(meio, fundo, (t - 0.5) / 0.5)
        end
        Theme.gradient[i] = c
    end
    Theme.gradient.stops = STOPS

    -- Aplica um gradiente vertical a um Frame via UIGradient.
    -- O clamp em SEQUENCE_LIMIT é defensivo: se as paradas forem aumentadas no
    -- futuro, o gradiente degrada para menos pontos em vez de derrubar o script.
    function Theme.applyGradient(frame, flip, alphaTop, alphaBot)
        local g = Instance.new("UIGradient")
        g.Rotation = flip and 180 or 90   -- 90 = topo->base

        local n = math.min(Theme.gradient.stops, Theme.SEQUENCE_LIMIT)

        local seq = {}
        for i = 0, n - 1 do
            local t = i / (n - 1)
            table.insert(seq, ColorSequenceKeypoint.new(t, Theme.gradient[i]))
        end
        g.Color = ColorSequence.new(seq)

        if alphaTop or alphaBot then
            local at = alphaTop or 0
            local ab = alphaBot or 0
            local aseq = {}
            for i = 0, n - 1 do
                local t = i / (n - 1)
                table.insert(aseq, NumberSequenceKeypoint.new(t, at + (ab - at) * t))
            end
            g.Transparency = NumberSequence.new(aseq)
        end

        g.Parent = frame
        return g
    end
end

-- ── Tipografia ───────────────────────────────────────────────────────────────
-- Uma família só, escalada por papel. Duas famílias em UI de cheat lê como
-- descuido; o peso e o tamanho já carregam a hierarquia.
Theme.font = {
    regular = Enum.Font.Gotham,
    medium  = Enum.Font.GothamMedium,
    bold    = Enum.Font.GothamBold,
    mono    = Enum.Font.Code,
}

Theme.text = {
    title    = 15,   -- nome da janela
    section  = 12,   -- cabeçalho de grupo
    label    = 13,   -- rótulo de toggle
    sub      = 11,   -- descrição sob o rótulo
    tiny     = 10,   -- rodapé, contador
    value    = 12,   -- valor numérico em slider
}

-- ── Métrica ──────────────────────────────────────────────────────────────────
Theme.metric = {
    pad       = 12,
    padSm     = 7,
    radius    = 8,
    radiusSm  = 5,
    rowH      = 34,    -- altura de uma linha de toggle
    tabH      = 40,    -- altura da faixa de abas
    headH     = 44,    -- altura do cabeçalho
    stroke    = 1,
    scrollW   = 4,
    winW      = 508,
    winH      = 396,
}

-- ── Animação ─────────────────────────────────────────────────────────────────
-- Curvas nomeadas. Sem isso, cada lugar inventa o próprio timing e a UI
-- treme em ritmos diferentes.
Theme.ease = {
    out  = TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
    inOut= TweenInfo.new(0.30, Enum.EasingStyle.Quad,  Enum.EasingDirection.InOut),
    fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
    pop  = TweenInfo.new(0.38, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
}

Theme.duration = { hover = 0.12, press = 0.08, open = 0.26, slide = 0.20 }

-- ── Helper: Stroke ───────────────────────────────────────────────────────────
-- Borda de 1px. Usada em quase tudo — sem ela, tudo flutua sem contorno sobre
-- fundo escuro.
function Theme.stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.color.line
    s.Thickness = thickness or Theme.metric.stroke
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

-- ── Helper: Corner ───────────────────────────────────────────────────────────
function Theme.corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or Theme.metric.radius)
    c.Parent = parent
    return c
end

-- ── Helper: Padding ──────────────────────────────────────────────────────────
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
    AOTR · Fábrica de Widgets
    Arquivo: src/core/widget.lua
    
    Cada widget é uma função que devolve {instance, set, destroy}. O contrato é
    sempre o mesmo, para que a camada de UI nunca precise saber como um controle
    específico funciona por dentro.

    Estudo aplicado do AirFlow: lá a UI é montada por document.createElement em
    série, sem componentização — funciona, mas cada tela reimplementa o próprio
    botão. Aqui cada controle tem um construtor único e um estado declarativo.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Theme = __req("core/theme")

local Widget = {}

-- ── Utilidades de instância ──────────────────────────────────────────────────

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

-- Anima uma propriedade numérica com segurança (cancela tween anterior).
local function tween(obj, info, goal)
    if obj:FindFirstChild("__tw") then obj.__tw:Destroy() end
    local t = game:GetService("TweenService"):Create(obj, info, goal)
    t:Play()
    return t
end
Widget.tween = tween

-- ── Botão ────────────────────────────────────────────────────────────────────
-- Três variantes: solid (accent cheio), ghost (só borda), danger (vermelho vivo).
-- O hover desloca o conteúdo 1px para cima e clareia o fundo — micro-movimento
-- que dá a sensação de superfície física sem exagerar no movimento.

function Widget.button(props)
    local variant = props.variant or "ghost"
    local parent = props.parent

    local base = new("TextButton", {
        Name = props.name or "Btn",
        Size = props.size or UDim2.new(0, 110, 0, 30),
        Position = props.position,
        BackgroundColor3 = variant == "solid" and Theme.color.accent
            or variant == "danger" and Theme.color.danger
            or Theme.color.surface,
        BackgroundTransparency = variant == "ghost" and 1 or 0,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = parent,
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
        Parent = base,
    })

    -- Ícone opcional à esquerda do texto.
    local icon
    if props.icon then
        label.Position = UDim2.new(0, 20, 0, 0)
        label.Size = UDim2.new(1, -24, 1, 0)
        label.TextXAlignment = Enum.TextXAlignment.Left
        icon = new("ImageLabel", {
            Size = UDim2.fromOffset(14, 14),
            Position = UDim2.new(0, 8, 0.5, -7),
            BackgroundTransparency = 1,
            Image = props.icon,
            ImageColor3 = label.TextColor3,
            Parent = base,
        })
    end

    local hovering = false
    local function restColor()
        if variant == "solid" then return Theme.color.accent end
        if variant == "danger" then return Theme.color.danger end
        return Theme.color.surface
    end

    base.MouseEnter:Connect(function()
        hovering = true
        tween(base, Theme.ease.fast, {
            BackgroundColor3 = variant == "ghost" and Theme.color.surfaceHi
                or (variant == "solid" and Theme.color.accentHi or Theme.color.danger),
            BackgroundTransparency = variant == "ghost" and 0 or 0,
        })
        stroke.Color = Theme.color.accentHi
        if icon then tween(icon, Theme.ease.fast, { ImageColor3 = Theme.color.accentHi }) end
        if label then tween(label, Theme.ease.fast,
            { TextColor3 = variant == "ghost" and Theme.color.accentHi or Color3.new(1, 1, 1) }) end
    end)

    base.MouseLeave:Connect(function()
        hovering = false
        tween(base, Theme.ease.fast, {
            BackgroundColor3 = restColor(),
            BackgroundTransparency = variant == "ghost" and 1 or 0,
        })
        stroke.Color = variant == "ghost" and Theme.color.line or Theme.color.lineHot
        if icon then tween(icon, Theme.ease.fast,
            { ImageColor3 = variant == "solid" and Color3.new(1, 1, 1) or Theme.color.text }) end
        if label then tween(label, Theme.ease.fast,
            { TextColor3 = variant == "solid" and Color3.new(1, 1, 1) or Theme.color.text }) end
    end)

    base.MouseButton1Down:Connect(function()
        tween(base, Theme.ease.fast, { Size = base.Size - UDim2.fromOffset(2, 2) })
    end)

    base.MouseButton1Click:Connect(function()
        tween(base, Theme.ease.pop, { Size = props.size or UDim2.new(0, 110, 0, 30) })
        if props.onClick then props.onClick() end
    end)

    return {
        instance = base,
        set = function(_, text) label.Text = text end,
    }
end

-- ── Toggle ───────────────────────────────────────────────────────────────────
-- Linha inteira clicável (não só o switch) — alvo grande é UI boa.
-- O switch é desenhado, não é imagem: trilho + botão, animados em posição e cor.

function Widget.toggle(props)
    local parent = props.parent

    local row = new("TextButton", {
        Name = props.name or "Toggle",
        Size = props.size or UDim2.new(1, 0, 0, Theme.metric.rowH),
        BackgroundColor3 = Theme.color.surface,
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        Parent = parent,
    })
    Theme.corner(row, Theme.metric.radiusSm)
    Theme.pad(row, 0, 10, 0)

    local label = new("TextLabel", {
        Size = UDim2.new(1, -48, 0, 15),
        Position = UDim2.new(0, 0, 0, props.sub and 4 or 9),
        BackgroundTransparency = 1,
        Text = props.text or "Opção",
        TextColor3 = Theme.color.text,
        TextSize = Theme.text.label,
        Font = Theme.font.medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })

    if props.sub then
        new("TextLabel", {
            Size = UDim2.new(1, -48, 0, 12),
            Position = UDim2.new(0, 0, 0, 19),
            BackgroundTransparency = 1,
            Text = props.sub,
            TextColor3 = Theme.color.textMute,
            TextSize = Theme.text.sub,
            Font = Theme.font.regular,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = row,
        })
    end

    -- Switch
    local track = new("Frame", {
        Name = "Track",
        Size = UDim2.fromOffset(34, 18),
        Position = UDim2.new(1, -34, 0.5, -9),
        BackgroundColor3 = Theme.color.off,
        BorderSizePixel = 0,
        Parent = row,
    })
    Theme.corner(track, 9)
    local tstroke = Theme.stroke(track, Theme.color.line)

    local knob = new("Frame", {
        Name = "Knob",
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.new(0, 3, 0.5, -6),
        BackgroundColor3 = Theme.color.textMute,
        BorderSizePixel = 0,
        Parent = track,
    })
    Theme.corner(knob, 6)

    local state = props.default or false

    local function render(animate)
        local info = animate and Theme.ease.out or TweenInfo.new(0)
        tween(track, info, {
            BackgroundColor3 = state and Theme.color.accentLo or Theme.color.off,
        })
        tstroke.Color = state and Theme.color.accent or Theme.color.line
        tween(knob, info, {
            Position = state and UDim2.new(0, 19, 0.5, -6) or UDim2.new(0, 3, 0.5, -6),
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
        set = function(_, v) state = v; render(true); if props.onChange then props.onChange(v) end end,
    }
end

-- ── Slider ───────────────────────────────────────────────────────────────────
-- Arrasto com captura de input. O preenchimento é um Frame cujo tamanho segue o
-- valor; o polegar aparece no hover (não fica sempre visível — poluição visual).

function Widget.slider(props)
    local parent = props.parent
    local min = props.min or 0
    local max = props.max or 100
    local value = props.default or min
    local suffix = props.suffix or ""
    local decimals = props.decimals or 0

    local wrap = new("Frame", {
        Name = props.name or "Slider",
        Size = props.size or UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        Parent = parent,
    })

    local label = new("TextLabel", {
        Size = UDim2.new(1, -60, 0, 14),
        BackgroundTransparency = 1,
        Text = props.text or "Valor",
        TextColor3 = Theme.color.text,
        TextSize = Theme.text.label,
        Font = Theme.font.medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = wrap,
    })

    local readout = new("TextLabel", {
        Size = UDim2.fromOffset(60, 14),
        Position = UDim2.new(1, -60, 0, 0),
        BackgroundTransparency = 1,
        Text = string.format("%." .. decimals .. "f%s", value, suffix),
        TextColor3 = Theme.color.accentHi,
        TextSize = Theme.text.value,
        Font = Theme.font.mono,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = wrap,
    })

    local track = new("Frame", {
        Name = "Track",
        Size = UDim2.new(1, 0, 0, 5),
        Position = UDim2.new(0, 0, 0, 26),
        BackgroundColor3 = Theme.color.off,
        BorderSizePixel = 0,
        Parent = wrap,
    })
    Theme.corner(track, 3)

    local fill = new("Frame", {
        Name = "Fill",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.color.accent,
        BorderSizePixel = 0,
        Parent = track,
    })
    Theme.corner(fill, 3)

    local thumb = new("Frame", {
        Name = "Thumb",
        Size = UDim2.fromOffset(12, 12),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Theme.color.accentHi,
        BorderSizePixel = 0,
        Parent = track,
    })
    Theme.corner(thumb, 6)
    Theme.stroke(thumb, Theme.color.void, 2)

    -- Zona de toque maior que o trilho: 5px é fino demais para acertar.
    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 22),
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
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
        local rel = (x - track.AbsolutePosition.X) / track.AbsoluteSize.X
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

    track.MouseEnter:Connect(function() tween(thumb, Theme.ease.fast, { Size = UDim2.fromOffset(14, 14) }) end)
    track.MouseLeave:Connect(function() tween(thumb, Theme.ease.fast, { Size = UDim2.fromOffset(12, 12) }) end)

    return {
        instance = wrap,
        get = function() return value end,
        set = function(_, v) apply(v, true) end,
    }
end

-- ── Dropdown ─────────────────────────────────────────────────────────────────
-- Fecha ao clicar fora — sem isso, dois dropdowns ficam abertos ao mesmo tempo
-- e a UI parece quebrada.

function Widget.dropdown(props)
    local parent = props.parent
    local options = props.options or {}
    local value = props.default or options[1]
    local open = false

    local wrap = new("Frame", {
        Name = props.name or "Dropdown",
        Size = props.size or UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        ZIndex = 5,
        Parent = parent,
    })

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = props.text or "Seleção",
        TextColor3 = Theme.color.text,
        TextSize = Theme.text.label,
        Font = Theme.font.medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = wrap,
    })

    local head = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.new(0, 0, 0, 18),
        BackgroundColor3 = Theme.color.surface,
        Text = "",
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 6,
        Parent = wrap,
    })
    Theme.corner(head, Theme.metric.radiusSm)
    local hstroke = Theme.stroke(head, Theme.color.line)
    Theme.pad(head, 0, 9, 0)

    local headLabel = new("TextLabel", {
        Size = UDim2.new(1, -20, 1, 0),
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
        Size = UDim2.fromOffset(12, 12),
        Position = UDim2.new(1, -18, 0.5, -6),
        BackgroundTransparency = 1,
        Text = "▾",
        TextColor3 = Theme.color.textMute,
        TextSize = 12,
        ZIndex = 7,
        Parent = head,
    })

    local list = new("Frame", {
        Name = "List",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 4),
        BackgroundColor3 = Theme.color.surfaceTop,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 20,
        Parent = wrap,
    })
    Theme.corner(list, Theme.metric.radiusSm)
    Theme.stroke(list, Theme.color.line)
    Theme.pad(list, 4)

    local layout = new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = list,
    })

    local rows = {}
    for i, opt in ipairs(options) do
        local r = new("TextButton", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Theme.color.surface,
            BackgroundTransparency = 1,
            Text = tostring(opt),
            TextColor3 = Theme.color.textDim,
            TextSize = Theme.text.label,
            Font = Theme.font.regular,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
            LayoutOrder = i,
            ZIndex = 21,
            Parent = list,
        })
        Theme.corner(r, 4)
        Theme.pad(r, 0, 8, 0)
        r.MouseEnter:Connect(function()
            tween(r, Theme.ease.fast, { BackgroundTransparency = 0, TextColor3 = Theme.color.accentHi })
        end)
        r.MouseLeave:Connect(function()
            tween(r, Theme.ease.fast, { BackgroundTransparency = 1, TextColor3 = Theme.color.textDim })
        end)
        r.MouseButton1Click:Connect(function()
            value = opt
            headLabel.Text = tostring(opt)
            Widget._closeOpenDropdown()
            open = false
            tween(list, Theme.ease.fast, { Size = UDim2.new(1, 0, 0, 0) })
            task.delay(0.1, function() list.Visible = false end)
            if props.onChange then props.onChange(opt) end
        end)
        rows[opt] = r
    end

    function Widget._closeOpenDropdown() end  -- substituído abaixo

    local function closeList()
        open = false
        tween(caret, Theme.ease.fast, { Rotation = 0 })
        tween(list, Theme.ease.fast, { Size = UDim2.new(1, 0, 0, 0) })
        task.delay(0.1, function()
            if not open then list.Visible = false end
        end)
        hstroke.Color = Theme.color.line
    end

    local function openList()
        open = true
        list.Visible = true
        local h = #options * 26 + 8
        tween(list, Theme.ease.out, { Size = UDim2.new(1, 0, 0, h) })
        tween(caret, Theme.ease.fast, { Rotation = 180 })
        hstroke.Color = Theme.color.accent
    end

    head.MouseButton1Click:Connect(function()
        if open then closeList() else openList() end
    end)

    -- Um só dropdown aberto por vez.
    local conn
    conn = game:GetService("UserInputService").InputBegan:Connect(function(input)
        if open and input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mp = input.Position
            local ap, sz = wrap.AbsolutePosition, wrap.AbsoluteSize
            local inHead = mp.X >= ap.X and mp.X <= ap.X + sz.X
                and mp.Y >= ap.Y and mp.Y <= ap.Y + 46
            if not inHead then closeList() end
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

-- ── Seção ────────────────────────────────────────────────────────────────────
-- Cabeçalho com contador de itens ativos. O contador é o detalhe que faz a UI
-- parecer viva: você vê o que está ligado sem ler cada linha.

function Widget.section(props)
    local parent = props.parent
    local wrap = new("Frame", {
        Name = props.name or "Section",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = parent,
    })

    local head = new("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Parent = wrap,
    })

    new("TextLabel", {
        Size = UDim2.new(1, -70, 1, 0),
        BackgroundTransparency = 1,
        Text = string.upper(props.text or "SEÇÃO"),
        TextColor3 = Theme.color.textMute,
        TextSize = Theme.text.tiny,
        Font = Theme.font.bold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = head,
    })

    local count = new("TextLabel", {
        Size = UDim2.fromOffset(66, 16),
        Position = UDim2.new(1, -66, 0.5, -8),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.color.accent,
        TextSize = Theme.text.tiny,
        Font = Theme.font.mono,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = head,
    })

    -- fio horizontal que morre antes da borda — mais elegante que linha cheia
    local rule = new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 0, 21),
        BackgroundColor3 = Theme.color.lineSoft,
        BorderSizePixel = 0,
        Parent = wrap,
    })

    local body = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 26),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = wrap,
    })
    new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
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

-- ── Divisória ────────────────────────────────────────────────────────────────
function Widget.divider(parent)
    return new("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.color.lineSoft,
        BorderSizePixel = 0,
        Parent = parent,
    })
end

-- ── Caixa de texto ───────────────────────────────────────────────────────────
function Widget.input(props)
    local parent = props.parent
    local wrap = new("Frame", {
        Size = props.size or UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        Parent = parent,
    })

    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = props.text or "Campo",
        TextColor3 = Theme.color.text,
        TextSize = Theme.text.label,
        Font = Theme.font.medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = wrap,
    })

    local box = new("TextBox", {
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.new(0, 0, 0, 18),
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
    Theme.pad(box, 0, 9, 0)

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

-- ── features/utility ──────────────────────────────────────────
MODULES["features/utility"] = function()
local __src = [=[
--[[
    AOTR · Utilidades
    Arquivo: src/features/utility.lua

    Auto Reabastecer, Anti-AFK, Retry Instantâneo e farms.

    DUAS CORREÇÕES QUE MUDARAM O DESENHO DESTE MÓDULO
    -------------------------------------------------
    1. NÃO EXISTE remote de roll de família. A rolagem é pura automação de
       interface: procura-se um botão cujo texto começa com "ROLL", clica, e
       depois LÊ-SE o resultado raspando o texto da tela no formato
       "Nome (Raridade)". A versão anterior deste arquivo chamava
       Game.findRemote("roll") e nunca acharia nada.

    2. As raridades são: COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC,
       SECRET, EXCLUSIVE. É MYTHIC, não "Mythical". A tabela abaixo está na
       ordem interna real do jogo.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Game = __req("core/game")
local State = __req("core/state")
local Util = __req("core/util")

local Utility = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")

-- ── Raridades (tabela interna real, ordem crescente) ─────────────────────────

Utility.RANK = {
    COMMON = 1, UNCOMMON = 2, RARE = 3, EPIC = 4,
    LEGENDARY = 5, MYTHIC = 6, SECRET = 7, EXCLUSIVE = 8,
}

function Utility.rankOf(rarity)
    return Utility.RANK[string.upper(tostring(rarity or ""))] or 0
end

-- ── Anti-AFK ─────────────────────────────────────────────────────────────────

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

-- ── Auto Reabastecer ─────────────────────────────────────────────────────────
-- O sinal de lâmina gasta é o atributo `Broken` na parte da lâmina.
-- A recarga usa a estação física do mapa como argumento.

local lastReload = 0

function Utility.refillTick()
    if os.clock() - lastReload < 1.0 then return end

    local station = Game.getRefillStation()
    local lp = Game.getLocalPlayer()

    -- Sem estação e sem cargas, não há o que fazer.
    local refills = Game.getRefills()
    if not station and (not refills or refills <= 0) then return end

    local blade = Game.getBlade()
    local broken = blade and blade:GetAttribute("Broken")

    if broken or State.flags.autoRefill then
        lastReload = os.clock()
        Game.get("Blades", "Full_Reload", "Left", station)
        Game.get("Blades", "Full_Reload", "Right", station)
        Game.get("Blades", "Reload")
    end

    if State.flags.infiniteGas and station then
        Game.post("Attacks", "Reload", station)
    end
end

-- ── Auto Roll de Família (automação de interface) ────────────────────────────
-- Não há remote: procura-se o botão na PlayerGui, clica, e lê-se o resultado.

local function isTextObject(obj)
    return obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")
end

local function textOf(obj)
    local ok, t = pcall(function() return obj.Text end)
    return ok and tostring(t) or ""
end

local function isShown(obj)
    local ok, v = pcall(function()
        return obj.Visible and (obj.AbsoluteSize.X > 0 or obj.AbsoluteSize.Y > 0)
    end)
    return ok and v or false
end

function Utility.findRollButton()
    local lp = Game.getLocalPlayer()
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if not pg then return nil end

    for _, d in ipairs(pg:GetDescendants()) do
        if isTextObject(d) and isShown(d) then
            local t = textOf(d):upper()
            if string.sub(t, 1, 4) == "ROLL" then return d end
        end
    end
    return nil
end

-- Lê o par "Nome (Raridade)" exibido após a rolagem.
function Utility.readFamily()
    local lp = Game.getLocalPlayer()
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if not pg then return nil end

    for _, d in ipairs(pg:GetDescendants()) do
        if isTextObject(d) and isShown(d) then
            local name, rarity = textOf(d):match("^(.-)%s*%((%a+)%)$")
            if name and Utility.RANK[string.upper(rarity)] then
                return name, string.upper(rarity)
            end
        end
    end
    return nil
end

function Utility.pressButton(btn)
    if not btn then return false end
    -- TextButton aceita ativação direta; se falhar, simulamos o clique.
    if btn:IsA("TextButton") or btn:IsA("ImageButton") then
        local ok = pcall(function()
            local vim = game:GetService("VirtualInputManager")
            local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
            vim:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 1)
            task.wait(0.05)
            vim:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 1)
        end)
        return ok
    end
    return false
end

Utility.rollStats = { rolls = 0, best = nil, bestRank = 0, log = {} }

local lastRoll = 0

function Utility.rollTick()
    if os.clock() - lastRoll < 0.8 then return end

    -- Verifica o resultado da rolagem ANTERIOR.
    local name, rarity = Utility.readFamily()
    if name then
        local rank = Utility.rankOf(rarity)
        if rank > (Utility.rollStats.bestRank or 0) then
            Utility.rollStats.best = name .. " (" .. rarity .. ")"
            Utility.rollStats.bestRank = rank
            Utility.rollStats.log[#Utility.rollStats.log + 1] = Utility.rollStats.best
            if #Utility.rollStats.log > 30 then table.remove(Utility.rollStats.log, 1) end
            if rank >= 6 then   -- MYTHIC ou melhor
                Utility.notifyRoll(name, rarity)
            end
        end
    end

    local btn = Utility.findRollButton()
    if btn then
        lastRoll = os.clock()
        if Utility.pressButton(btn) then
            Utility.rollStats.rolls = Utility.rollStats.rolls + 1
        end
    end
end

Utility._onRare = nil

function Utility.notifyRoll(name, rarity)
    if Utility._onRare then
        pcall(Utility._onRare, name, rarity)
    end
end

-- ── Retry Instantâneo ────────────────────────────────────────────────────────
-- O verbo real é GET("Functions","Retry","Add").

local lastRetry = 0

function Utility.retryTick()
    if os.clock() - lastRetry < 3 then return end

    local hum = Game.getHumanoid()
    if hum and hum.Health <= 0 then
        lastRetry = os.clock()
        Game.get("Functions", "Retry", "Add")
        return
    end

    -- GUI de resultado visível sinaliza fim de missão.
    local lp = Game.getLocalPlayer()
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if pg then
        for _, d in ipairs(pg:GetDescendants()) do
            if isTextObject(d) and isShown(d) then
                local t = string.lower(textOf(d))
                if string.find(t, "mission complete", 1, true)
                    or string.find(t, "missão concluída", 1, true)
                    or string.find(t, "retry", 1, true) then
                    lastRetry = os.clock()
                    Game.get("Functions", "Retry", "Add")
                    return
                end
            end
        end
    end
end

-- ── Maestria ─────────────────────────────────────────────────────────────────
-- Não existe remote de maestria. O que existe é uso de habilidade:
-- GET("S_Skills","Usage", "<id>") com ids numéricos em string.
-- Ids confirmados nas fontes: "108", "14", "23".

Utility.SKILL_IDS = { "108", "14", "23" }
local lastSkill = 0
local skillIndex = 1

function Utility.masteryTick()
    if os.clock() - lastSkill < 2.5 then return end
    lastSkill = os.clock()

    local id = Utility.SKILL_IDS[skillIndex]
    skillIndex = skillIndex % #Utility.SKILL_IDS + 1
    Game.get("S_Skills", "Usage", id)
end

-- ── Farm de missões ──────────────────────────────────────────────────────────
-- Missões são acionadas pela interface. Procura-se um botão de missão/raid
-- visível e aciona. Sem remote dedicado — confirmado nas duas fontes.

local lastQuest = 0

function Utility.questTick()
    if os.clock() - lastQuest < 5 then return end

    local lp = Game.getLocalPlayer()
    local pg = lp and lp:FindFirstChild("PlayerGui")
    if not pg then return end

    for _, d in ipairs(pg:GetDescendants()) do
        if isTextObject(d) and isShown(d) then
            local t = string.lower(textOf(d))
            if string.find(t, "start mission", 1, true)
                or string.find(t, "iniciar missão", 1, true)
                or string.find(t, "daily", 1, true) then
                if Utility.pressButton(d) then
                    lastQuest = os.clock()
                    return
                end
            end
        end
    end
end

-- ── Ciclo ────────────────────────────────────────────────────────────────────

function Utility.start()
    Utility.setupAntiAfk()

    Utility._conn = RunService.Heartbeat:Connect(function(dt)
        local ok, err = pcall(function()
            if State.flags.autoRefill or State.flags.infiniteGas then
                Utility.refillTick()
            end
            if State.flags.autoRoll then
                Utility.rollTick()
            end
            if State.flags.instantRetry then
                Utility.retryTick()
            end
            if State.flags.masteryFarm then
                Utility.masteryTick()
            end
            if State.flags.goldFarm then
                Utility.questTick()
            end
        end)
        if not ok then warn("[AOTR] utilidades: " .. tostring(err)) end
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
                    if State.flags.espDistance then
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
        warn("[AOTR] ESP: nenhum ScreenGui recebido; o ESP ficará inativo.")
        return false
    end
    screen = gui

    container = Util.tag(Instance.new("Frame"))
    container.Name = "AOTR_ESP"
    container.Size = UDim2.fromScale(1, 1)
    container.BackgroundTransparency = 1
    container.ZIndex = 0
    container.Parent = screen

    Visuals._conn = RunService.RenderStepped:Connect(function()
        if not State.flags.esp then return end
        local ok, err = pcall(Visuals.tick)
        if not ok then warn("[AOTR] ESP: " .. tostring(err)) end
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
    AOTR · Interface
    Arquivo: src/ui/interface.lua

    Janela arrastável, abas laterais, rolagem suave, busca de recursos,
    minimizar e notificações. Tudo em PT-BR.

    ESTUDO APLICADO DO AIRFLOW
    --------------------------
    Do AirFlow vem a estrutura: cabeçalho com identidade, faixa de navegação,
    conteúdo em cartões, gradiente de fundo feito em canvas no original.
    Roblox não tem canvas livre, então o gradiente aqui é UIGradient multi-parada
    (24 stops pré-computados no tema) — mesmo efeito, sem custo de frame.

    O que muda: o AirFlow usa uma única lista longa por tela. Aqui há BUSCA,
    porque com 20+ recursos a lista fica difícil de navegar. É a diferença entre
    "bonito" e "usável".

    Atalho: RightControl para mostrar/esconder.
--]]


-- injetado pelo bundler: resolvedor de módulos no escopo deste chunk
local __req = ...
local Theme = __req("core/theme")
local Widget = __req("core/widget")
local State = __req("core/state")
local Util = __req("core/util")
local Game = __req("core/game")

local UI = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local _LP_cache
local function LP()
    if _LP_cache and _LP_cache.Parent then return _LP_cache end
    _LP_cache = Players.LocalPlayer
    return _LP_cache
end

local gui, root, body, sidebar, content, statusBar
local tabs = {}
local pages = {}
local activeTab = "combate"
local minimized = false
local toasts = {}

-- ── Registro de recursos ─────────────────────────────────────────────────────
-- Cada recurso se declara uma vez. A UI gera o controle certo a partir do tipo.
-- É isso que torna trivial adicionar um recurso novo: uma linha na tabela.

local FEATURES = {
    combate = {
        label = "Combate",
        icon = "⚔",
        items = {
            { type = "toggle", flag = "killAura",     text = "Kill Aura",         sub = "Ataca Titãs automaticamente no alcance" },
            { type = "toggle", flag = "killAuraNape", text = "Mirar na Nuca",     sub = "Registra o golpe na hitbox crítica" },
            { type = "toggle", flag = "autoTP",       text = "Auto TP ao Titã",   sub = "Teleporta para trás da nuca mais próxima" },
            { type = "toggle", flag = "napeExpander", text = "Nape Expander",     sub = "Amplia e destaca a nuca para mira manual" },
            { type = "divider" },
            { type = "slider", flag = "killAuraRange", text = "Alcance do Aura",  min = 5,  max = 150, suffix = " studs" },
            { type = "slider", flag = "killAuraDelay", text = "Intervalo",        min = 0.05, max = 1, decimals = 2, suffix = "s" },
            { type = "slider", flag = "tpOffset",      text = "Distância da Nuca", min = 1,  max = 12, suffix = " studs" },
            { type = "slider", flag = "napeScale",     text = "Escala da Nuca",    min = 1,  max = 6, decimals = 1, suffix = "x" },
            { type = "info",  text = "O alcance real da lâmina neste jogo é curto. Valores altos de 'Alcance do Aura' exigem a magnitude estendida em Avançado." },
        },
    },
    recursos = {
        label = "Recursos",
        icon = "◆",
        items = {
            { type = "toggle", flag = "autoRefill",   text = "Auto Reabastecer", sub = "Recarrega lâminas quebradas automaticamente" },
            { type = "toggle", flag = "infiniteGas",  text = "Gás Infinito",     sub = "Aciona a estação de reabastecimento sem parar" },
            { type = "divider" },
            { type = "toggle", flag = "autoRoll",     text = "Auto Roll Família", sub = "Gira o sistema de famílias pela interface" },
            { type = "toggle", flag = "masteryFarm",  text = "Farm de Maestria", sub = "Repete habilidades para subir maestria" },
            { type = "toggle", flag = "goldFarm",     text = "Farm de Ouro & XP", sub = "Repete missões em sequência" },
            { type = "toggle", flag = "instantRetry", text = "Retry Instantâneo", sub = "Reinicia a missão assim que termina" },
            { type = "info", text = "Gás não existe como valor no cliente — 'Gás Infinito' aciona a estação de reabastecimento, que é o que os hubs reais fazem." },
        },
    },
    visual = {
        label = "Visual",
        icon = "◉",
        items = {
            { type = "toggle", flag = "esp",         text = "Titan ESP",       sub = "Mostra Titãs através das paredes" },
            { type = "toggle", flag = "espBox",      text = "Caixa" },
            { type = "toggle", flag = "espLine",     text = "Linha de Rastreio" },
            { type = "toggle", flag = "espText",     text = "Nome e Tipo" },
            { type = "toggle", flag = "espHealth",   text = "Barra de Vida" },
            { type = "toggle", flag = "espNape",     text = "Marcar Nuca",     sub = "Ponto no alvo crítico exato" },
            { type = "toggle", flag = "espBossOnly", text = "Somente Chefes",  sub = "Filtra Titãs puros e anormais" },
            { type = "dropdown", flag = "espColor",  text = "Cor do ESP",
              options = { "Vermelho", "Branco", "Verde", "Azul", "Amarelo", "Rosa", "Ciano" } },
            { type = "slider", flag = "espMaxDist",  text = "Distância Máxima", min = 100, max = 2000, suffix = " studs" },
            { type = "slider", flag = "espThickness", text = "Espessura",       min = 1, max = 4, decimals = 1 },
        },
    },
    sistema = {
        label = "Sistema",
        icon = "⚙",
        items = {
            { type = "toggle", flag = "antiAfk",      text = "Anti-AFK",       sub = "Impede desconexão por inatividade" },
            { type = "toggle", flag = "watermark",    text = "Marca d'Água" },
            { type = "toggle", flag = "notifications",text = "Notificações" },
            { type = "divider" },
            { type = "toggle", flag = "safeFarm",     text = "Modo Seguro",    sub = "Trava a missão por 32s para evitar shadow ban" },
            { type = "slider", flag = "safeTime",     text = "Tempo Mínimo",   min = 0, max = 90, suffix = "s",
              note = "0 desliga a proteção" },
            { type = "divider" },
            { type = "button", text = "Salvar Configuração", variant = "ghost", onClick = function()
                if State.save() then
                    UI.notify("Configuração", "Salvo com sucesso.")
                else
                    UI.notify("Configuração", "Seu executor não permite salvar arquivos.", 4)
                end
            end },
            { type = "button", text = "Carregar Configuração", variant = "ghost", onClick = function()
                if State.load() then
                    UI.rebuild()
                    UI.notify("Configuração", "Carregada.")
                else
                    UI.notify("Configuração", "Nenhum arquivo encontrado.", 4)
                end
            end },
            { type = "button", text = "Diagnóstico do Jogo", variant = "solid", onClick = function()
                UI.showDiagnostic()
            end },
            { type = "button", text = "Checar Marcação da Conta", variant = "danger", onClick = function()
                UI.checkFlag()
            end },
        },
    },
}

UI.FEATURES = FEATURES
UI.controls = {}   -- [flag] = widget, para rebuild

-- ── Construção da janela ─────────────────────────────────────────────────────

local function buildRoot()
    gui = Instance.new("ScreenGui")
    gui.Name = "AOTR_UI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = LP():WaitForChild("PlayerGui")

    root = Widget.new("Frame", {
        Name = "Root",
        Size = UDim2.fromOffset(Theme.metric.winW, Theme.metric.winH),
        Position = UDim2.new(0.5, -Theme.metric.winW / 2, 0.5, -Theme.metric.winH / 2),
        BackgroundColor3 = Theme.color.base,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = gui,
    })
    Theme.corner(root, Theme.metric.radius + 2)
    Theme.stroke(root, Theme.color.lineHot)

    -- Gradiente de fundo: cinza quente no topo -> tinta embaixo.
    local bg = Widget.new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 0,
        Parent = root,
    })
    Theme.corner(bg, Theme.metric.radius + 2)
    Theme.applyGradient(bg)

    -- Brilho vermelho no topo: dá o "calor" da identidade sem poluir o conteúdo.
    -- Não é uma imagem — é um gradiente radial simulado com UIGradient em ângulo.
    local glow = Widget.new("Frame", {
        Size = UDim2.new(1, 0, 0, 90),
        BackgroundColor3 = Theme.color.accent,
        BackgroundTransparency = 0.93,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = root,
    })
    Theme.corner(glow, Theme.metric.radius + 2)
    local gg = Instance.new("UIGradient")
    gg.Rotation = 90
    gg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.0),
        NumberSequenceKeypoint.new(1, 1.0),
    })
    gg.Parent = glow
    return root
end

local function buildHeader()
    local head = Widget.new("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, Theme.metric.headH),
        BackgroundColor3 = Theme.color.surfaceTop,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = root,
    })
    Theme.pad(head, 0, Theme.metric.pad + 2, 0)

    -- marca: um losango vermelho, ecoando a geometria do AirFlow (que usa
    -- uma imagem de logo) mas sem asset externo — nada para o Roblox censurar.
    local mark = Widget.new("Frame", {
        Size = UDim2.fromOffset(9, 9),
        Position = UDim2.new(0, 0, 0.5, -4.5),
        BackgroundColor3 = Theme.color.accent,
        BorderSizePixel = 0,
        Rotation = 45,
        ZIndex = 3,
        Parent = head,
    })
    Theme.corner(mark, 1)

    Widget.new("TextLabel", {
        Size = UDim2.fromOffset(160, 18),
        Position = UDim2.new(0, 18, 0, 8),
        BackgroundTransparency = 1,
        Text = "AOTR",
        TextColor3 = Theme.color.text,
        TextSize = Theme.text.title,
        Font = Theme.font.bold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = head,
    })
    Widget.new("TextLabel", {
        Size = UDim2.fromOffset(220, 12),
        Position = UDim2.new(0, 18, 0, 24),
        BackgroundTransparency = 1,
        Text = "Attack on Titan Revolution",
        TextColor3 = Theme.color.textMute,
        TextSize = Theme.text.tiny,
        Font = Theme.font.regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = head,
    })

    -- estatísticas ao vivo no cabeçalho — o detalhe que faz parecer vivo
    local stats = Widget.new("TextLabel", {
        Name = "Stats",
        Size = UDim2.fromOffset(220, 14),
        Position = UDim2.new(1, -220 - 74, 0.5, -7),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Theme.color.textMute,
        TextSize = Theme.text.tiny,
        Font = Theme.font.mono,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 3,
        Parent = head,
    })
    UI.statsLabel = stats

    -- botão minimizar
    local min = Widget.new("TextButton", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, -60, 0.5, -13),
        BackgroundColor3 = Theme.color.surface,
        BackgroundTransparency = 1,
        Text = "—",
        TextColor3 = Theme.color.textDim,
        TextSize = 14,
        Font = Theme.font.bold,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 4,
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

    -- botão fechar
    local close = Widget.new("TextButton", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.new(1, -30, 0.5, -13),
        BackgroundColor3 = Theme.color.surface,
        BackgroundTransparency = 1,
        Text = "✕",
        TextColor3 = Theme.color.textDim,
        TextSize = 13,
        Font = Theme.font.bold,
        AutoButtonColor = false,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = head,
    })
    Theme.corner(close, 6)
    close.MouseEnter:Connect(function()
        Widget.tween(close, Theme.ease.fast, { BackgroundTransparency = 0, BackgroundColor3 = Theme.color.danger, TextColor3 = Color3.new(1, 1, 1) })
    end)
    close.MouseLeave:Connect(function()
        Widget.tween(close, Theme.ease.fast, { BackgroundTransparency = 1, BackgroundColor3 = Theme.color.surface, TextColor3 = Theme.color.textDim })
    end)
    close.MouseButton1Click:Connect(function() UI.setVisible(false) end)

    -- arrasto pela barra de título
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

    return head
end

local function buildSidebar()
    sidebar = Widget.new("Frame", {
        Name = "Sidebar",
        Size = UDim2.new(0, 132, 1, -(Theme.metric.headH + 26)),
        Position = UDim2.new(0, 0, 0, Theme.metric.headH),
        BackgroundColor3 = Theme.color.void,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = root,
    })
    Widget.new("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = sidebar,
    })
    Theme.pad(sidebar, 0, 8, 8)

    for i, key in ipairs({ "combate", "recursos", "visual", "sistema" }) do
        local def = FEATURES[key]
        local btn = Widget.new("TextButton", {
            Name = key,
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Theme.color.surface,
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            BorderSizePixel = 0,
            LayoutOrder = i,
            ZIndex = 3,
            Parent = sidebar,
        })
        Theme.corner(btn, Theme.metric.radiusSm)

        local bar = Widget.new("Frame", {
            Name = "Bar",
            Size = UDim2.new(0, 2, 0, 0),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Theme.color.accent,
            BorderSizePixel = 0,
            ZIndex = 5,
            Parent = btn,
        })
        Theme.corner(bar, 1)

        local ic = Widget.new("TextLabel", {
            Size = UDim2.fromOffset(20, 20),
            Position = UDim2.new(0, 10, 0.5, -10),
            BackgroundTransparency = 1,
            Text = def.icon,
            TextColor3 = Theme.color.textMute,
            TextSize = 13,
            Font = Theme.font.bold,
            ZIndex = 4,
            Parent = btn,
        })
        local lb = Widget.new("TextLabel", {
            Size = UDim2.new(1, -38, 1, 0),
            Position = UDim2.new(0, 32, 0, 0),
            BackgroundTransparency = 1,
            Text = def.label,
            TextColor3 = Theme.color.textMute,
            TextSize = Theme.text.label,
            Font = Theme.font.medium,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
            Parent = btn,
        })

        tabs[key] = { btn = btn, bar = bar, icon = ic, label = lb }

        btn.MouseEnter:Connect(function()
            if activeTab ~= key then
                Widget.tween(btn, Theme.ease.fast, { BackgroundTransparency = 0.4 })
                Widget.tween(lb, Theme.ease.fast, { TextColor3 = Theme.color.textDim })
            end
        end)
        btn.MouseLeave:Connect(function()
            if activeTab ~= key then
                Widget.tween(btn, Theme.ease.fast, { BackgroundTransparency = 1 })
                Widget.tween(lb, Theme.ease.fast, { TextColor3 = Theme.color.textMute })
            end
        end)
        btn.MouseButton1Click:Connect(function() UI.selectTab(key) end)
    end
    return sidebar
end

local function buildContent()
    content = Widget.new("Frame", {
        Name = "Content",
        Size = UDim2.new(1, -132 - 1, 1, -(Theme.metric.headH + 26)),
        Position = UDim2.new(0, 132, 0, Theme.metric.headH),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = root,
    })

    local scroll = Widget.new("ScrollingFrame", {
        Name = "Scroll",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = Theme.metric.scrollW,
        ScrollBarImageColor3 = Theme.color.line,
        ScrollBarImageTransparency = 0.3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 2,
        Parent = content,
    })
    Theme.pad(scroll, 0, Theme.metric.pad + 2, Theme.metric.pad)

    Widget.new("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = scroll,
    })
    UI.scroll = scroll
    return scroll
end

local function buildStatusBar()
    statusBar = Widget.new("Frame", {
        Name = "StatusBar",
        Size = UDim2.new(1, 0, 0, 26),
        Position = UDim2.new(0, 0, 1, -26),
        BackgroundColor3 = Theme.color.surfaceTop,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = root,
    })
    Theme.pad(statusBar, 0, Theme.metric.pad + 2, 0)

    local dot = Widget.new("Frame", {
        Size = UDim2.fromOffset(6, 6),
        Position = UDim2.new(0, 0, 0.5, -3),
        BackgroundColor3 = Theme.color.ok,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = statusBar,
    })
    Theme.corner(dot, 3)
    UI.statusDot = dot

    local txt = Widget.new("TextLabel", {
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "Pronto",
        TextColor3 = Theme.color.textMute,
        TextSize = Theme.text.tiny,
        Font = Theme.font.regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
        Parent = statusBar,
    })
    UI.statusText = txt

    Widget.new("TextLabel", {
        Size = UDim2.fromOffset(110, 14),
        Position = UDim2.new(1, -110, 0.5, -7),
        BackgroundTransparency = 1,
        Text = "RightCtrl · ocultar",
        TextColor3 = Theme.color.textMute,
        TextSize = Theme.text.tiny,
        Font = Theme.font.mono,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 4,
        Parent = statusBar,
    })
    return statusBar
end

-- ── Página (conteúdo de uma aba) ─────────────────────────────────────────────

local function buildPage(key)
    local def = FEATURES[key]
    local page = Widget.new("Frame", {
        Name = key,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
        Parent = UI.scroll,
    })
    Widget.new("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = page,
    })

    local section = Widget.section({ parent = page, text = def.label })
    section.instance.LayoutOrder = 1

    UI.controls = UI.controls or {}

    for i, item in ipairs(def.items) do
        local w
        if item.type == "toggle" then
            w = Widget.toggle({
                parent = section.body,
                text = item.text,
                sub = item.sub,
                default = State.flags[item.flag],
                onChange = function(v) State.set(item.flag, v) end,
                size = UDim2.new(1, 0, 0, item.sub and 40 or 32),
            })
            w.instance.LayoutOrder = i
            UI.controls[item.flag] = w

        elseif item.type == "slider" then
            w = Widget.slider({
                parent = section.body,
                text = item.text,
                min = item.min, max = item.max,
                default = State.config[item.flag],
                suffix = item.suffix, decimals = item.decimals,
                onChange = function(v) State.config[item.flag] = v end,
            })
            w.instance.LayoutOrder = i
            UI.controls[item.flag] = w

        elseif item.type == "dropdown" then
            w = Widget.dropdown({
                parent = section.body,
                text = item.text,
                options = item.options,
                default = State.config[item.flag],
                onChange = function(v) State.config[item.flag] = v end,
            })
            w.instance.LayoutOrder = i
            UI.controls[item.flag] = w

        elseif item.type == "button" then
            w = Widget.button({
                parent = section.body,
                text = item.text,
                variant = item.variant or "ghost",
                size = UDim2.new(1, 0, 0, 30),
                onClick = item.onClick,
            })
            w.instance.LayoutOrder = i

        elseif item.type == "divider" then
            local d = Widget.divider(section.body)
            d.LayoutOrder = i

        elseif item.type == "info" then
            local box = Widget.new("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = Theme.color.accentGhost,
                BorderSizePixel = 0,
                LayoutOrder = i,
                Parent = section.body,
            })
            Theme.corner(box, Theme.metric.radiusSm)
            Theme.stroke(box, Theme.color.lineSoft)
            Theme.pad(box, 0, 10, 7)
            Widget.new("TextLabel", {
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Text = item.text,
                TextColor3 = Theme.color.textDim,
                TextSize = Theme.text.sub,
                Font = Theme.font.regular,
                TextWrapped = true,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                Parent = box,
            })
        end
    end

    pages[key] = { frame = page, section = section, def = def }
    return page
end

-- ── Notificações ─────────────────────────────────────────────────────────────

local toastHolder

function UI.notify(title, text, duration)
    if not (State.flags.notifications and toastHolder) then return end
    duration = duration or 3

    local card = Widget.new("Frame", {
        Size = UDim2.fromOffset(250, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.color.surfaceTop,
        BorderSizePixel = 0,
        ZIndex = 50,
        Parent = toastHolder,
    })
    Theme.corner(card, Theme.metric.radiusSm)
    Theme.stroke(card, Theme.color.lineHot)
    Theme.pad(card, 0, 10, 8)

    local stack = Widget.new("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = card,
    })
    Widget.new("UIListLayout", { Padding = UDim.new(0, 3), Parent = stack })

    Widget.new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.color.accentHi,
        TextSize = Theme.text.label,
        Font = Theme.font.bold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = stack,
    })
    Widget.new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Theme.color.textDim,
        TextSize = Theme.text.sub,
        Font = Theme.font.regular,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = stack,
    })

    -- barra de vida da notificação: comunica a duração sem número
    local life = Widget.new("Frame", {
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = Theme.color.accent,
        BorderSizePixel = 0,
        ZIndex = 51,
        Parent = card,
    })

    card.Position = UDim2.new(1, 20, 1, 0)
    Widget.tween(card, Theme.ease.out, { Position = UDim2.new(1, -262, 1, -8 - #toasts * 62) })
    Widget.tween(life, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 2) })

    table.insert(toasts, card)
    task.delay(duration, function()
        Widget.tween(card, Theme.ease.fast, { Position = UDim2.new(1, 20, 1, 0) })
        task.wait(0.15)
        for i, c in ipairs(toasts) do if c == card then table.remove(toasts, i) break end end
        card:Destroy()
    end)
end

Util._onNotify = UI.notify

-- ── Diagnóstico ──────────────────────────────────────────────────────────────

function UI.showDiagnostic()
    local r = Game.diagnose()
    local lines = {
        ("PlaceId: %d %s"):format(r.placeId, r.isAOTR and "(correto)" or "(INESPERADO)"),
        ("Remotes GET/POST: %s"):format(r.remotesFound and "encontrados" or "AUSENTES"),
        ("Titãs vivos: %d"):format(r.titanCount),
    }
    if r.sampleTitan then
        table.insert(lines, ("Exemplo: %s [%s]"):format(r.sampleTitan, r.sampleKind or "?"))
        table.insert(lines, ("Nuca: %s"):format(r.sampleNape or "NÃO ENCONTRADA"))
    else
        table.insert(lines, "Nenhum Titã no mapa agora.")
    end
    table.insert(lines, ("Refills: %s"):format(tostring(r.refills)))
    table.insert(lines, ("Nível: %s  Prestígio: %s"):format(tostring(r.level), tostring(r.prestige)))
    table.insert(lines, ("Lanças: %s  Lâmina quebrada: %s"):format(tostring(r.spears), tostring(r.bladeBroken)))
    table.insert(lines, ("Estação de reabastecimento: %s"):format(r.refillStation and "visível" or "não encontrada"))
    table.insert(lines, ("Exploiter: %s  Blacklisted: %s"):format(tostring(r.flagged), tostring(r.blacklisted)))

    UI.notify("Diagnóstico", table.concat(lines, "\n"), 10)
    print("[AOTR] Diagnóstico:")
    for _, l in ipairs(lines) do print("  " .. l) end
    if r.sampleParts and #r.sampleParts > 0 then
        print("  Hitboxes: " .. table.concat(r.sampleParts, ", "))
    end
end

-- Lê as bandeiras que o próprio servidor replica de volta ao cliente.
function UI.checkFlag()
    local exploiter, blacklisted = Game.isFlagged()
    if blacklisted then
        UI.notify("Conta Marcada",
            "BLACKLISTED está ativo nesta conta.\nPare de usar o script e verifique o servidor do jogo.", 12)
    elseif exploiter then
        UI.notify("Atenção",
            "A bandeira EXPLOITER está ativa.\nSua conta foi sinalizada. Reduza o uso e evite farms rápidos.", 10)
    else
        UI.notify("Conta Limpa", "Nenhuma marcação ativa. Continue respeitando o Modo Seguro.", 5)
    end
end

-- ── Abas e visibilidade ──────────────────────────────────────────────────────

function UI.selectTab(key)
    if not FEATURES[key] then return end
    activeTab = key

    for k, t in pairs(tabs) do
        local on = (k == key)
        Widget.tween(t.bar, Theme.ease.out, {
            Size = on and UDim2.new(0, 2, 0, 18) or UDim2.new(0, 2, 0, 0),
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
    local target = v and 44 or Theme.metric.winH
    Widget.tween(root, Theme.ease.out, { Size = UDim2.fromOffset(Theme.metric.winW, target) })
    if sidebar then sidebar.Visible = not v end
    if content then content.Visible = not v end
    if statusBar then statusBar.Visible = not v end
    UI.statusText.Text = v and "Minimizado — RightCtrl para restaurar" or "Pronto"
end

function UI.setVisible(v)
    if gui then gui.Enabled = v end
end

function UI.isVisible()
    return gui and gui.Enabled
end

-- Atualiza a linha de status do rodapé. Mantido separado para que as features
-- não precisem conhecer a estrutura da barra.
function UI.setStatus(text)
    if UI.statusText then UI.statusText.Text = text or "Pronto" end
end

-- Reconstrói os controles a partir do estado atual (usado após carregar config).
function UI.rebuild()
    for flag, w in pairs(UI.controls) do
        if w.set then
            local v = State.flags[flag]
            if v == nil then v = State.config[flag] end
            pcall(function() w:set(v) end)
        end
    end
end

-- ── Loop de estatísticas ─────────────────────────────────────────────────────

local function statsLoop()
    task.spawn(function()
        while gui and gui.Parent do
            local ok = pcall(function()
                if not State.flags.watermark then
                    UI.statsLabel.Text = ""
                else
                    local titans = #Game.getTitans()
                    local parts = {
                        ("%d titãs"):format(titans),
                        ("%d FPS"):format(math.floor(1 / math.max(RunService.RenderStepped:Wait(), 1e-3))),
                    }
                    UI.statsLabel.Text = table.concat(parts, "  ·  ")
                end
            end)
            task.wait(0.5)
        end
    end)
end

-- ── Montagem ─────────────────────────────────────────────────────────────────

function UI.mount()
    buildRoot()
    buildHeader()
    buildSidebar()
    buildContent()
    buildStatusBar()
    -- região de notificações, acima da janela
    toastHolder = Widget.new("Frame", {
        Name = "Toasts",
        Size = UDim2.fromOffset(260, 300),
        Position = UDim2.new(0.5, Theme.metric.winW / 2 + 8, 0.5, Theme.metric.winH / 2 - 300),
        BackgroundTransparency = 1,
        ZIndex = 40,
        Parent = gui,
    })

    for _, key in ipairs({ "combate", "recursos", "visual", "sistema" }) do
        buildPage(key)
    end
    UI.selectTab("combate")

    -- atalho
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.RightControl then
            UI.setVisible(not UI.isVisible())
        end
    end)

    UI.statusText.Text = ("Pronto · %s"):format(Util.executorName())
    statsLoop()
    return gui
end

function UI.unmount()
    if gui then gui:Destroy(); gui = nil end
    UI.controls = {}
    tabs, pages = {}, {}
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
    AOTR · Attack on Titan Revolution — Script Hub
    ============================================================================
    Versão   : 1.0.0
    Jogo     : Attack on Titan Revolution (Roblox)
    PlaceId  : 13379208636
    Interface: PT-BR

    COMO USAR
    ---------
    Cole o conteúdo de build/AOTR.lua no seu executor e execute.
    RightControl mostra e esconde a interface.

    Este arquivo é o ponto de entrada. O bundler (build/bundle.mjs) resolve os
    módulos de src/ e injeta o resolvedor __req como parâmetro deste chunk.
    ============================================================================
--]]

-- ── Serviços ─────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ── Módulos ──────────────────────────────────────────────────────────────────
-- __req chega por parâmetro do bundle. Fora do bundle, avisamos em vez de
-- falhar de forma obscura mais adiante.


local Theme     = __req("core/theme")
local Widget    = __req("core/widget")
local State     = __req("core/state")
local Util      = __req("core/util")
local Game_     = __req("core/game")
local Combat    = __req("features/combat")
local Visuals   = __req("features/visuals")
local Utility   = __req("features/utility")
local Interface = __req("ui/interface")

-- ── Verificação de jogo ──────────────────────────────────────────────────────
-- O NOME do jogo muda a cada update ("[UPDATE 5] ..."), então não serve de
-- guarda. O PlaceId é estável. Não bloqueia: apenas avisa.

if game.PlaceId ~= Game_.ROOT_PLACE_ID then
    warn(("[AOTR] PlaceId %d não é o AOTR (%d). O script vai tentar mesmo assim.")
        :format(game.PlaceId, Game_.ROOT_PLACE_ID))
end

-- ── Hub ──────────────────────────────────────────────────────────────────────

local Hub = {}
Hub.version = "1.0.0"
Hub.placeId = game.PlaceId

-- Carrega preferências antes de montar a UI, para que os controles nasçam com
-- os valores certos em vez de piscar em "tudo desligado".
local loaded = State.load()

-- mount() devolve o ScreenGui criado; o ESP precisa dele como container.
local screenGui = Interface.mount()
Visuals.mount(screenGui)

-- ── Ligações estado -> feature ───────────────────────────────────────────────

State.on("esp", function(on)
    Interface.setStatus(on and "ESP ativo" or "Pronto")
end)

State.on("killAura", function(on)
    if on then
        Interface.notify("Combate", ("Kill Aura ativado · alcance %d studs"):format(
            State.config.killAuraRange))
        if State.config.hitMagnitude > 40 then
            Interface.notify("Atenção",
                "Magnitude de acerto alta. Isso é fisicamente impossível no jogo e aumenta o risco de marcação.",
                7)
        end
    end
end)

State.on("napeExpander", function(on)
    if not on then Combat.restoreNapes() end
end)

State.on("safeFarm", function(on)
    Interface.setStatus(on and "Modo Seguro ativo" or "Pronto")
    if not on then
        Interface.notify("Atenção", "Modo Seguro desligado. Farms rápidos podem marcar a conta.", 6)
    end
end)

-- ── Loops ────────────────────────────────────────────────────────────────────

Combat.start()
Utility.start()

-- ── Encerramento limpo ───────────────────────────────────────────────────────
-- Sem isto, rodar o script duas vezes duplica os loops e dobra o consumo.

local function shutdown()
    pcall(function() Combat.stop() end)
    pcall(function() Utility.stop() end)
    pcall(function() Visuals.unmount() end)
    pcall(function() Interface.unmount() end)
    State.save()
end
Hub.shutdown = shutdown

-- ── Boas-vindas e checagens ──────────────────────────────────────────────────

task.delay(0.7, function()
    Interface.notify("AOTR carregado",
        ("v%s · RightControl para abrir e fechar."):format(Hub.version), 5)

    if loaded then
        Interface.notify("Configuração", "Preferências salvas restauradas.", 3)
    end
end)

-- Avisa cedo se a conta já está marcada. É a informação mais importante que o
-- usuário pode receber, e o servidor replica ela de volta ao cliente.
task.delay(1.5, function()
    local exploiter, blacklisted = Game_.isFlagged()
    if blacklisted then
        Interface.notify("Conta Marcada",
            "Sua conta está BLACKLISTED. Pare de usar o script.", 15)
    elseif exploiter then
        Interface.notify("Atenção",
            "Bandeira EXPLOITER ativa. Reduza o uso e evite farms rápidos.", 10)
    end
end)

-- Se nenhum Titã aparecer em 20 s, o usuário precisa saber que é o jogo que
-- mudou, não o script que quebrou em silêncio.
task.delay(20, function()
    local ok, titans = pcall(function() return Game_.getTitans(true) end)
    if ok and #titans == 0 then
        Interface.notify("Nenhum Titã encontrado",
            "Abra Sistema → Diagnóstico do Jogo e me mande o resultado.", 10)
    end
end)

-- ── Exposição para inspeção manual ───────────────────────────────────────────

if Util.getGenv then
    pcall(function() Util.getGenv().AOTR = Hub end)
end

print(("[AOTR] v%s · PlaceId %d · executor: %s"):format(
    Hub.version, game.PlaceId, Util.executorName()))

return Hub

]==]
local __entry = assert(loadstring(__src), "falha ao compilar main")
return __entry(__req)
