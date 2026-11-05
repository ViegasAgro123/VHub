--[[
    VHub · Gravador do AirFlow
    Arquivo: diagnose/recorder.lua

    PARA QUE SERVE
    --------------
    O AirFlow é Luarmor + Luraph: o código real nunca existe em texto enquanto
    roda. Não dá para "abrir e ler as linhas" de uma VM — o bytecode é um blob
    binário decifrado em memória a cada instrução.

    O que dá para fazer (e é o que este arquivo faz) é registrar o
    COMPORTAMENTO observável:

      1. Remotes — toda chamada a GET/POST com argumentos, retorno, tempo e
         pilha. É aqui que aparece a magnitude real do Register, o offset, a
         cadência do Slash, o intervalo entre golpes.
      2. GUI — a árvore inteira da interface com cor, tamanho, posição, fonte,
         stroke, corner, gradiente, imagem. Isso é o suficiente para
         reconstruir o visual com o nosso tema.
      3. Estado — posição, velocidade, vida, titãs, atributos. Mostra o que
         cada funcionalidade faz com o personagem e com o mundo.
      4. Capabilities do executor — o que dá para usar e o que não dá.

    COMO USAR
    ---------
    Cole no executor ANTES do AirFlow:

        loadstring(game:HttpGet("https://raw.githubusercontent.com/ViegasAgro123/VHub/main/diagnose/recorder.lua"))()

    Depois execute o AirFlow normalmente e use a interface dele um pouco:
    ligue cada função, ataque, abra cada aba. O gravador registra sozinho.

    No fim:

        salvarTudo()      -- grava um relatório único
        dumparGui()       -- força um dump da interface atual
        copiarGui()       -- dump da interface para a área de transferência

    ARQUIVOS GERADOS (na pasta do executor)
    ---------------------------------------
        vhub_af_remotes_<data>.log
        vhub_af_gui_<data>.txt
        vhub_af_estado_<data>.log
        vhub_af_relatorio_<data>.txt
--]]

local CONFIG = {
    hookRemotes   = true,   -- intercepta FireServer/InvokeServer
    autoGui       = true,   -- dump automático quando uma GUI nova aparece
    amostrar      = true,   -- amostra estado do jogo
    intervalo     = 2,      -- segundos entre amostras
    maxEventos    = 8000,
    maxNos        = 5000,
    flushSegundos = 3,
    todosRemotes  = false,  -- true = registra QUALQUER remote (mais ruidoso)
    -- Teto do arquivo de GUI. A UI do jogo muda o tempo todo (vida, ping, FPS)
    -- e redumpá-la gera dezenas de MB sem nenhuma informação nova. O que
    -- interessa é a UI do script (CoreGui/HUI), que não é filtrada aqui.
    limiteGuiMB   = 12,
    -- ScreenGuis da UI do jogo: não entram no dump dinâmico nem no vigia.
    guisIgnoradas = {
        ["Interface"] = true, ["Fullscreen"] = true, ["DevConsoleMaster"] = true,
        ["SystemScrim"] = true, ["Watermark"] = true, ["ShortcutBar"] = true,
        ["Drawing"] = true, ["RobloxPromptGui"] = true, ["Chat"] = true,
        ["PlayerList"] = true, ["ScreenshotsCarousel"] = true,
        ["TeleportEffectGui"] = true, ["CaptureOverlay"] = true,
    },
}

-- ── Capabilities: cada executor expõe um subconjunto ─────────────────────────

local function pegarGlobal(nome)
    -- Três rotas: _G (Synapse/Delta), getgenv (Xeno e afins) e resolução direta
    -- como global. Alguns executores criam um _G novo por script, e aí só a
    -- terceira rota acha a função.
    local env
    pcall(function()
        local g = getgenv()
        if type(g) == "table" then env = g end
    end)
    if not env then
        pcall(function()
            local e = getfenv(0)
            if type(e) == "table" then env = e end
        end)
    end

    local rotas = {
        function() return _G[nome] end,
        function() return env and env[nome] end,
        function()
            local f = loadstring("return " .. nome)
            if not f then return nil end
            return f()
        end,
    }

    for _, rota in ipairs(rotas) do
        local ok, valor = pcall(rota)
        if ok and type(valor) == "function" then return valor end
    end
    return nil
end

local CAP = {
    writefile       = pegarGlobal("writefile"),
    appendfile      = pegarGlobal("appendfile"),
    readfile        = pegarGlobal("readfile"),
    listfiles       = pegarGlobal("listfiles"),
    makefolder      = pegarGlobal("makefolder"),
    hookmetamethod  = pegarGlobal("hookmetamethod"),
    getrawmetatable = pegarGlobal("getrawmetatable"),
    setreadonly     = pegarGlobal("setreadonly"),
    getnamecall     = pegarGlobal("getnamecallmethod"),
    newcclosure     = pegarGlobal("newcclosure"),
    hookfunction    = pegarGlobal("hookfunction"),
    setclipboard    = pegarGlobal("setclipboard"),
    gethui          = pegarGlobal("gethui"),
    getgc           = pegarGlobal("getgc"),
    request         = pegarGlobal("request"),
    syn_request     = pegarGlobal("syn.request"),
    http_request    = pegarGlobal("http_request"),
    http_post       = pegarGlobal("http.post"),
}

-- Nomes alternativos: cada executor batiza a mesma coisa de um jeito.
CAP.hookfunction = CAP.hookfunction or pegarGlobal("replaceclosure") or pegarGlobal("hookfunc")
CAP.setreadonly = CAP.setreadonly or pegarGlobal("make_writeable")
if not CAP.getrawmetatable and debug and type(debug.getmetatable) == "function" then
    CAP.getrawmetatable = function(obj) return debug.getmetatable(obj) end
end
if not CAP.getnamecall and debug and type(debug.getnamecallmethod) == "function" then
    CAP.getnamecall = debug.getnamecallmethod
end

local typeOf = typeof or type

-- ── Utilidades de texto ──────────────────────────────────────────────────────

local T0 = os.clock()

local function stamp()
    return os.date("%Y%m%d_%H%M%S")
end

local STAMP = stamp()

local function num(n)
    if n == math.floor(n) then return tostring(n) end
    local s = ("%.3f"):format(n)
    s = s:gsub("0+$", ""):gsub("%.$", "")
    return s
end

local function cor(c)
    return ("rgb(%d,%d,%d)"):format(
        math.floor(c.R * 255 + 0.5),
        math.floor(c.G * 255 + 0.5),
        math.floor(c.B * 255 + 0.5))
end

local function udim2(u)
    return ("(%s,%d,%s,%d)"):format(
        num(u.X.Scale), u.X.Offset, num(u.Y.Scale), u.Y.Offset)
end

local function vetor(v)
    return ("(%.1f,%.1f,%.1f)"):format(v.X, v.Y, v.Z)
end

local function cortar(s, limite)
    s = tostring(s)
    limite = limite or 240
    if #s <= limite then return s end
    return s:sub(1, limite) .. ("…(%d B)"):format(#s)
end

-- Serializa valores de argumentos de remote sem explodir em tabelas enormes.
local function fmt(v, prof, vistos)
    if v == nil then return "nil" end
    local t = typeOf(v)

    if t == "Instance" then
        local ok, nome = pcall(function() return v:GetFullName() end)
        return ("Instance<%s %s>"):format(v.ClassName, ok and nome or v.Name)
    elseif t == "Vector3" then
        return "V3" .. vetor(v)
    elseif t == "Vector2" then
        return ("V2(%.1f,%.1f)"):format(v.X, v.Y)
    elseif t == "CFrame" then
        local p = v.Position
        return ("CFrame%s"):format(vetor(p))
    elseif t == "Color3" then
        return cor(v)
    elseif t == "UDim2" then
        return "UDim2" .. udim2(v)
    elseif t == "number" then
        return num(v)
    elseif t == "string" then
        return ("%q"):format(cortar(v))
    elseif t == "boolean" or t == "nil" then
        return tostring(v)
    elseif t == "function" then
        local info = debug and debug.getinfo and debug.getinfo(v, "S")
        local src = info and info.source or "?"
        return ("function(%s)"):format(cortar(src, 60))
    elseif t == "table" then
        prof = prof or 1
        if prof > 2 then return "{...}" end
        vistos = vistos or {}
        if vistos[v] then return "{recursivo}" end
        vistos[v] = true

        local partes, n = {}, 0
        for k, val in next, v do
            n = n + 1
            if n > 12 then
                table.insert(partes, "…")
                break
            end
            table.insert(partes, ("%s=%s"):format(
                type(k) == "string" and k or ("[" .. fmt(k, prof + 1, vistos) .. "]"),
                fmt(val, prof + 1, vistos)))
        end
        vistos[v] = nil
        return "{" .. table.concat(partes, ", ") .. "}"
    end

    return cortar(tostring(v))
end

local function pilha()
    if not (debug and debug.traceback) then return "" end
    local ok, tb = pcall(debug.traceback, "", 3)
    if not ok or type(tb) ~= "string" then return "" end
    local linhas = {}
    for linha in tb:gmatch("[^\n]+") do
        if not linha:find("Gravador", 1, true) then
            table.insert(linhas, "      " .. linha)
            if #linhas >= 3 then break end
        end
    end
    return table.concat(linhas, "\n")
end

-- Junta os argumentos de um remote sem o campo `n` do table.pack.
local function fmtArgs(args)
    local partes = {}
    for i = 1, (args.n or #args) do
        table.insert(partes, fmt(args[i], 1))
    end
    return table.concat(partes, ", ")
end

-- ── Estado em memória ────────────────────────────────────────────────────────

local REMOTES = {}
local CLIQUES = {}
local ESTADO = {}
local GUI_DUMPS = {}
local GUI_TOTAL_BYTES = 0
local AVISOU_TETO_GUI = false
local GUIS_VISTAS = {}
local REMOTES_VISTOS = {}
local eventos = 0
local avisos = {}

local function avisar(msg)
    table.insert(avisos, msg)
    print("[Gravador] " .. msg)
end

-- ── Persistência ─────────────────────────────────────────────────────────────

local ARQ_REMOTES = "vhub_af_remotes_" .. STAMP .. ".log"
local ARQ_ESTADO  = "vhub_af_estado_" .. STAMP .. ".log"
local ARQ_GUI     = "vhub_af_gui_" .. STAMP .. ".txt"
local ARQ_RELATO  = "vhub_af_relatorio_" .. STAMP .. ".txt"
local ARQ_HOOKS   = "vhub_af_hooks_" .. STAMP .. ".txt"
local ARQ_CLIQUES = "vhub_af_cliques_" .. STAMP .. ".log"

local function escrever(nome, conteudo)
    if not CAP.writefile then return false end
    -- Sempre sobrescreve: o conteúdo é montado a partir do estado em memória,
    -- então append duplicaria tudo se o writefile falhasse uma vez.
    return (pcall(CAP.writefile, nome, conteudo))
end

local function flush()
    if not CAP.writefile then return end
    if #REMOTES > 0 then
        escrever(ARQ_REMOTES, table.concat(REMOTES, "\n") .. "\n")
    end
    if #ESTADO > 0 then
        escrever(ARQ_ESTADO, table.concat(ESTADO, "\n") .. "\n")
    end
    if #GUI_DUMPS > 0 then
        escrever(ARQ_GUI, table.concat(GUI_DUMPS, "\n\n"))
    end
    if #CLIQUES > 0 then
        escrever(ARQ_CLIQUES, table.concat(CLIQUES, "\n") .. "\n")
    end
end

-- ── 1. Remotes ───────────────────────────────────────────────────────────────

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function pastaRemotes()
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    return assets and assets:FindFirstChild("Remotes")
end

local function ehRemoteRelevante(inst)
    if typeof(inst) ~= "Instance" then return false end
    if not (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")
        or inst:IsA("UnreliableRemoteEvent")) then
        return false
    end
    if CONFIG.todosRemotes then return true end

    local pasta = pastaRemotes()
    if pasta and inst:IsDescendantOf(pasta) then return true end

    -- Fallback: nome típico de remote de script hub
    local nome = inst.Name:lower()
    return nome == "get" or nome == "post"
end

local function registrarRemotes()
    if eventos >= CONFIG.maxEventos then return end
    eventos = eventos + 1
end

local function anotar(nome, metodo, args, ret, dt, classe)
    registrarRemotes()
    local alvo = nome .. ":" .. metodo
    local linha = ("[+%8.3fs] %s(%s)"):format(os.clock() - T0, alvo, fmtArgs(args))

    if ret ~= nil then
        if type(ret) == "table" and ret.n then
            linha = linha .. (" -> %s"):format(fmtArgs(ret))
        else
            linha = linha .. (" -> %s"):format(fmt(ret, 1))
        end
    end

    linha = linha .. ("  | %s  %.2fms"):format(classe or "?", (dt or 0) * 1000)
    table.insert(REMOTES, linha)

    -- Pilha só nas primeiras chamadas: depois vira ruído e infla o arquivo.
    if eventos <= 200 then
        local st = pilha()
        if st ~= "" then table.insert(REMOTES, st) end
    end
end

local hooksInstalados = {}
local HOOK_DIAG = {}

local function instalarHookRemotes()
    HOOK_DIAG = {}

    local function registrarTentativa(nome, ok, detalhe)
        HOOK_DIAG[nome] = ok and "ok" or tostring(detalhe)
    end

    -- Sem getnamecallmethod, o método sai do tipo do remote. POST é
    -- RemoteEvent (FireServer), GET é RemoteFunction (InvokeServer).
    local function metodoDe(self, metodo)
        if metodo and metodo ~= "" then return metodo end
        local ok, classe = pcall(function() return self.ClassName end)
        if not ok then return "?" end
        if classe == "RemoteFunction" then return "InvokeServer" end
        if classe == "RemoteEvent" or classe == "UnreliableRemoteEvent" then return "FireServer" end
        return "?"
    end

    -- Núcleo comum: decide se interessa, mede e devolve os retornos intactos.
    -- `emHook` evita recursão: ehRemoteRelevante chama :IsA, que é namecall.
    local emHook = false

    local function tratar(old, self, metodo, ...)
        if emHook then return old(self, ...) end

        local args = table.pack(...)
        emHook = true
        local resultados = table.pack(pcall(function()
            if not ehRemoteRelevante(self) then
                return old(self, table.unpack(args, 1, args.n))
            end

            metodo = metodoDe(self, metodo)
            if metodo ~= "FireServer" and metodo ~= "InvokeServer"
                and metodo ~= "FireServerAsync" then
                return old(self, table.unpack(args, 1, args.n))
            end

            local inicio = os.clock()
            local resultado = table.pack(old(self, table.unpack(args, 1, args.n)))
            local dt = os.clock() - inicio

            local ret = resultado.n > 1 and resultado or resultado[1]
            pcall(anotar, self.Name, metodo, args, ret, dt, self.ClassName)
            return table.unpack(resultado, 1, resultado.n)
        end))
        emHook = false

        if not resultados[1] then
            return old(self, table.unpack(args, 1, args.n))
        end
        return table.unpack(resultados, 2, resultados.n)
    end

    -- Porta 1: metatable na mão. É a mais restaurável e a que preserva retorno.
    if CAP.getrawmetatable then
        local ok, erro = pcall(function()
            local mt = CAP.getrawmetatable(game)
            if type(mt) ~= "table" then
                error("getrawmetatable devolveu " .. type(mt))
            end

            local old = mt.__namecall
            if type(old) ~= "function" then
                error("__namecall não é função (" .. type(old) .. ")")
            end

            local novo = function(self, ...)
                return tratar(old, self, CAP.getnamecall and CAP.getnamecall() or nil, ...)
            end
            if CAP.newcclosure then novo = CAP.newcclosure(novo) end

            if CAP.setreadonly then CAP.setreadonly(mt, false) end
            mt.__namecall = novo
            if CAP.setreadonly then CAP.setreadonly(mt, true) end

            hooksInstalados.namecall = {
                desfazer = function()
                    pcall(function()
                        if CAP.setreadonly then CAP.setreadonly(mt, false) end
                        mt.__namecall = old
                        if CAP.setreadonly then CAP.setreadonly(mt, true) end
                    end)
                end,
            }
        end)

        if ok then
            registrarTentativa("getrawmetatable", true)
            avisar("hook via getrawmetatable")
            return true
        end
        registrarTentativa("getrawmetatable", false, erro)
    else
        registrarTentativa("getrawmetatable", false, "indisponível")
    end

    -- Porta 2: hookfunction/replaceclosure em cada método de remote.
    if CAP.hookfunction then
        local alvo = pastaRemotes()
        if not alvo then
            registrarTentativa("hookfunction", false, "pasta de remotes não encontrada")
        else
            local ok, erro = pcall(function()
                for _, inst in ipairs(alvo:GetChildren()) do
                    if inst:IsA("RemoteEvent") then
                        local original = inst.FireServer
                        CAP.hookfunction(original, function(self, ...)
                            return tratar(original, self, "FireServer", ...)
                        end)
                    elseif inst:IsA("RemoteFunction") then
                        local original = inst.InvokeServer
                        CAP.hookfunction(original, function(self, ...)
                            return tratar(original, self, "InvokeServer", ...)
                        end)
                    end
                end
            end)

            if ok then
                registrarTentativa("hookfunction", true)
                avisar("hook via hookfunction no remote")
                return true
            end
            registrarTentativa("hookfunction", false, erro)
        end
    else
        registrarTentativa("hookfunction", false, "indisponível")
    end

    -- Porta 2.5: getmetatable padrão (Xeno expõe este, não o getrawmetatable).
    if type(getmetatable) == "function" then
        local ok, erro = pcall(function()
            local mt = getmetatable(game)
            if type(mt) ~= "table" then
                error("getmetatable(game) devolveu " .. type(mt))
            end
            local old = mt.__namecall
            if type(old) ~= "function" then
                error("__namecall não é função (" .. type(old) .. ")")
            end

            local novo = function(self, ...)
                return tratar(old, self, CAP.getnamecall and CAP.getnamecall() or nil, ...)
            end
            if CAP.newcclosure then novo = CAP.newcclosure(novo) end

            mt.__namecall = novo

            hooksInstalados.namecall = {
                desfazer = function()
                    pcall(function() mt.__namecall = old end)
                end,
            }
        end)

        if ok then
            registrarTentativa("getmetatable", true)
            avisar("hook via getmetatable")
            return true
        end
        registrarTentativa("getmetatable", false, erro)
    end

    -- Porta 3: hookmetamethod, mas só depois de validar a convenção de retorno
    -- num table descartável. Se o executor devolver nil, não existe original
    -- para delegar nem para restaurar — aí não instala nada.
    if CAP.hookmetamethod then
        local testeOk, testeErro = pcall(function()
            local alvo = setmetatable({}, { __index = function() return 1 end })
            local original = CAP.hookmetamethod(alvo, "__index", function(_, chave)
                return chave
            end)
            if type(original) ~= "function" then
                error("hookmetamethod não devolveu o original (" .. type(original) .. ")")
            end
        end)

        if not testeOk then
            registrarTentativa("hookmetamethod", false, testeErro)
        else
            local ok, erro = pcall(function()
                local original
                original = CAP.hookmetamethod(game, "__namecall", function(self, ...)
                    if type(original) ~= "function" then
                        error("VHub: hookmetamethod sem original", 0)
                    end
                    return tratar(original, self,
                        CAP.getnamecall and CAP.getnamecall() or nil, ...)
                end)
                if type(original) ~= "function" then
                    error("hookmetamethod devolveu " .. type(original))
                end
                hooksInstalados.namecall = {
                    desfazer = function()
                        pcall(CAP.hookmetamethod, game, "__namecall", original)
                    end,
                }
            end)

            if ok then
                registrarTentativa("hookmetamethod", true)
                avisar("hook via hookmetamethod")
                return true
            end
            registrarTentativa("hookmetamethod", false, erro)
        end
    else
        registrarTentativa("hookmetamethod", false, "indisponível")
    end

    return false
end

-- Lista o que o executor realmente expõe. Serve para descobrir nomes
-- alternativos quando todas as portas de hook falham.
local function varrerExecutor()
    local nomes, vistos = {}, {}
    local fonte = _G

    if type(getgenv) == "function" then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" then fonte = g end
    end

    local function adicionar(chave, valor, origem)
        if type(chave) ~= "string" or type(valor) ~= "function" or vistos[chave] then
            return
        end
        local baixo = chave:lower()
        if baixo:find("hook") or baixo:find("meta") or baixo:find("closure")
            or baixo:find("readonly") or baixo:find("namecall")
            or baixo:find("executor") or baixo:find("getgenv") then
            vistos[chave] = true
            table.insert(nomes, origem .. chave)
        end
    end

    pcall(function()
        for chave, valor in pairs(fonte) do adicionar(chave, valor, "") end
    end)

    pcall(function()
        for chave, valor in pairs(debug) do adicionar(chave, valor, "debug.") end
    end)

    table.sort(nomes)
    return nomes
end

-- Monta o laudo dos hooks, copia para a área de transferência e grava em disco.
local function relatorioHooks()
    local linhas = {}
    local executavel = "?"
    pcall(function()
        if type(identifyexecutor) == "function" then executavel = identifyexecutor() end
    end)

    table.insert(linhas, "=== VHUB HOOK REPORT ===")
    table.insert(linhas, "executor: " .. tostring(executavel))
    table.insert(linhas, "remotes: " .. tostring(pastaRemotes()
        and pastaRemotes():GetFullName() or "não encontrados"))

    table.insert(linhas, "caps:")
    for _, nome in ipairs({
        "writefile", "hookmetamethod", "getrawmetatable", "setreadonly",
        "getnamecallmethod", "newcclosure", "hookfunction", "setclipboard",
        "gethui", "getgc",
    }) do
        local chave = (nome == "getnamecallmethod") and "getnamecall" or nome
        table.insert(linhas, ("  %-18s %s"):format(nome, CAP[chave] and "ok" or "—"))
    end

    table.insert(linhas, "tentativas:")
    for nome, resultado in pairs(HOOK_DIAG) do
        table.insert(linhas, ("  %-18s %s"):format(nome, resultado))
    end

    table.insert(linhas, "funções do executor (filtradas):")
    local encontradas = varrerExecutor()
    if #encontradas == 0 then
        table.insert(linhas, "  (nada encontrado)")
    end
    for _, nome in ipairs(encontradas) do
        table.insert(linhas, "  " .. nome)
    end

    local texto = table.concat(linhas, "\n")
    escrever(ARQ_HOOKS, texto)
    if CAP.setclipboard then pcall(CAP.setclipboard, texto) end
    print(texto)
    return texto
end

-- ── Telemetria: canal fora do F9 ─────────────────────────────────────────────
-- O console do executor não dá para copiar. O laudo vai por HTTP para um
-- tópico ntfy e a leitura é feita por fora: https://ntfy.sh/<topico>/json?poll=1

local NTFY = "vhub-aotr-captura-9f42"

local function httpPost(url, corpo)
    local candidatos = {
        { nome = "request", fn = CAP.request },
        { nome = "http_request", fn = CAP.http_request },
        { nome = "syn.request", fn = CAP.syn_request },
        { nome = "http.post", fn = CAP.http_post },
    }

    for _, candidato in ipairs(candidatos) do
        if candidato.fn then
            local ok, resposta = pcall(function()
                if candidato.nome == "http.post" then
                    return candidato.fn(url, corpo, "text/plain")
                end
                return candidato.fn({
                    Url = url,
                    Method = "POST",
                    Body = corpo,
                    Headers = { ["Content-Type"] = "text/plain" },
                })
            end)

            if ok then
                local codigo
                if type(resposta) == "table" then
                    codigo = resposta.StatusCode or resposta.Status or resposta.status
                end
                codigo = tonumber(codigo)
                if not codigo or codigo < 400 then
                    return true, candidato.nome
                end
            end
        end
    end
    return false
end

local function enviarTexto(texto, rotulo)
    -- ntfy corta mensagem grande; fatia em pedaços com cabeçalho de ordem.
    local limite = 3300
    local pedacos = {}
    for i = 1, #texto, limite do
        table.insert(pedacos, texto:sub(i, i + limite - 1))
    end
    if #pedacos == 0 then pedacos = { "" } end

    local enviados = 0
    for indice, pedaco in ipairs(pedacos) do
        local corpo = ("[%s] %d/%d\n%s"):format(tostring(rotulo or "?"),
            indice, #pedacos, pedaco)
        local ok, via = httpPost("https://ntfy.sh/" .. NTFY, corpo)
        if not ok then
            return false, enviados
        end
        enviados = enviados + 1
        if indice < #pedacos then task.wait(0.3) end
    end
    return true, enviados
end

local function telemetria(rotulo)
    local linhas = {}
    local executavel = "?"
    pcall(function()
        if type(identifyexecutor) == "function" then executavel = identifyexecutor() end
    end)

    table.insert(linhas, "rotulo: " .. tostring(rotulo or "?"))
    table.insert(linhas, "executor: " .. tostring(executavel))
    table.insert(linhas, "lugar: " .. tostring(game.PlaceId) .. " / " .. tostring(game.JobId))
    table.insert(linhas, "tempo: " .. os.date("%d/%m/%Y %H:%M:%S"))
    table.insert(linhas, "remotes: " .. tostring(pastaRemotes() and "ok" or "não encontrados"))
    table.insert(linhas, "capturados: " .. tostring(#REMOTES))
    table.insert(linhas, "guis: " .. tostring(#GUI_DUMPS))

    table.insert(linhas, "caps:")
    for _, nome in ipairs({
        "writefile", "hookmetamethod", "getrawmetatable", "setreadonly",
        "getnamecallmethod", "newcclosure", "hookfunction", "setclipboard",
        "gethui", "getgc", "request", "http_request",
    }) do
        local chave = (nome == "getnamecallmethod") and "getnamecall" or nome
        table.insert(linhas, ("  %-18s %s"):format(nome, CAP[chave] and "ok" or "—"))
    end

    table.insert(linhas, "hooks:")
    for nome, resultado in pairs(HOOK_DIAG) do
        table.insert(linhas, ("  %-18s %s"):format(nome, resultado))
    end

    local texto = table.concat(linhas, "\n")
    local ok, via = enviarTexto(texto, rotulo or "estado")
    if ok then
        avisar(("telemetria enviada (%d parte(s))"):format(via))
    else
        avisar("telemetria indisponível (sem request/http.request)")
    end
    return ok
end

-- Re-tenta instalar os hooks e imprime o motivo exato de cada tentativa.
local function tentarHooks()
    local ok = instalarHookRemotes()
    print("[Gravador] tentativa de hook:")
    for nome, resultado in pairs(HOOK_DIAG) do
        print(("  %-16s %s"):format(nome, resultado))
    end

    if ok then
        pcall(telemetria, "hooks ok")
    else
        relatorioHooks()
        pcall(telemetria, "hooks falharam")
        avisar("laudo dos hooks copiado — cole aqui se puder")
    end
    return ok
end

local function observarRemotesNovos()
    local pasta = pastaRemotes()
    if not pasta then return end

    for _, inst in ipairs(pasta:GetChildren()) do
        if not REMOTES_VISTOS[inst] then
            REMOTES_VISTOS[inst] = true
            table.insert(REMOTES, ("[+%8.3fs] # remote encontrado: %s (%s)")
                :format(os.clock() - T0, inst:GetFullName(), inst.ClassName))

            -- POST costuma receber resposta do servidor pelo OnClientEvent.
            if inst:IsA("RemoteEvent") and inst.Name == "POST" then
                pcall(function()
                    inst.OnClientEvent:Connect(function(...)
                        table.insert(REMOTES, ("[+%8.3fs] << POST:OnClientEvent %s)")
                            :format(os.clock() - T0, fmt(table.pack(...), 1)))
                    end)
                end)
            end
        end
    end

    pcall(function()
        pasta.ChildAdded:Connect(function(inst)
            REMOTES_VISTOS[inst] = nil
    observarRemotesNovos()
    marcarGuisExistentes()
        end)
    end)
end

-- ── 2. GUI ───────────────────────────────────────────────────────────────────

local function propsDeLayout(inst)
    local extras = {}
    for _, filho in ipairs(inst:GetChildren()) do
        local classe = filho.ClassName

        if classe == "UICorner" then
            table.insert(extras, "corner=" .. num(filho.CornerRadius.Offset))
        elseif classe == "UIStroke" then
            table.insert(extras, ("stroke=%s t=%s tr=%s"):format(
                cor(filho.Color), num(filho.Thickness), num(filho.Transparency)))
        elseif classe == "UIPadding" then
            table.insert(extras, ("pad=(t%d b%d l%d r%d)"):format(
                filho.PaddingTop.Offset, filho.PaddingBottom.Offset,
                filho.PaddingLeft.Offset, filho.PaddingRight.Offset))
        elseif classe == "UIListLayout" then
            table.insert(extras, ("list=%s pad=%d sort=%s h=%s v=%s"):format(
                tostring(filho.FillDirection), filho.Padding.Offset,
                tostring(filho.SortOrder),
                tostring(filho.HorizontalAlignment), tostring(filho.VerticalAlignment)))
        elseif classe == "UIGridLayout" then
            table.insert(extras, ("grid=cell%s pad%s fill=%s h=%s v=%s"):format(
                udim2(filho.CellSize), udim2(filho.CellPadding),
                tostring(filho.FillDirection),
                tostring(filho.HorizontalAlignment), tostring(filho.VerticalAlignment)))
        elseif classe == "UIGradient" then
            local cores = {}
            for _, kp in ipairs(filho.Color.Keypoints) do
                table.insert(cores, ("%s@%s"):format(cor(kp.Value), num(kp.Time)))
            end
            local trans = {}
            for _, kp in ipairs(filho.Transparency.Keypoints) do
                table.insert(trans, ("%s@%s"):format(num(kp.Value), num(kp.Time)))
            end
            table.insert(extras, ("grad=[%s] tr=[%s] rot=%s"):format(
                table.concat(cores, ","), table.concat(trans, ","), num(filho.Rotation)))
        elseif classe == "UIScale" then
            table.insert(extras, "scale=" .. num(filho.Scale))
        elseif classe == "UIAspectRatioConstraint" then
            table.insert(extras, "aspect=" .. num(filho.AspectRatio))
        elseif classe == "UISizeConstraint" then
            table.insert(extras, ("sizeConstraint=min%s max%s"):format(
                vetor(filho.MinSize), vetor(filho.MaxSize)))
        elseif classe == "UITextSizeConstraint" then
            table.insert(extras, ("textSize=%d..%d"):format(
                filho.MinTextSize, filho.MaxTextSize))
        elseif classe == "UIPadding" then
            -- coberto acima
        end
    end
    return extras
end

local function descreverNo(inst, out, nivel, raiz, contador)
    contador.n = contador.n + 1
    if contador.n > CONFIG.maxNos then return end

    local recuo = string.rep("  ", nivel)
    local cabeca = ("%s%s \"%s\""):format(recuo, inst.ClassName, inst.Name)

    if inst:IsA("GuiObject") then
        local ap = inst.AbsolutePosition
        local as = inst.AbsoluteSize
        local rp = raiz and raiz.AbsolutePosition or Vector2.new()
        cabeca = cabeca .. ("  rel=(%d,%d) abs=(%d,%d) vis=%s z=%d"):format(
            math.floor(ap.X - rp.X), math.floor(ap.Y - rp.Y),
            math.floor(as.X), math.floor(as.Y), tostring(inst.Visible), inst.ZIndex)
        cabeca = cabeca .. ("  size=%s pos=%s anchor=%s"):format(
            udim2(inst.Size), udim2(inst.Position), udim2(UDim2.new(
                inst.AnchorPoint.X, 0, inst.AnchorPoint.Y, 0)))
    end

    table.insert(out, cabeca)

    if inst:IsA("GuiObject") then
        local linha = ("%s  bg=%s bgT=%s border=%d rot=%s clip=%s auto=%s"):format(
            recuo, cor(inst.BackgroundColor3), num(inst.BackgroundTransparency),
            inst.BorderSizePixel, num(inst.Rotation), tostring(inst.ClipsDescendants),
            tostring(inst.AutomaticSize))
        table.insert(out, linha)

        if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
            table.insert(out, ("%s  text=%q color=%s size=%d font=%s align=%s/%s wrap=%s rich=%s"):format(
                recuo, cortar(inst.Text), cor(inst.TextColor3), inst.TextSize,
                tostring(inst.Font), tostring(inst.TextXAlignment),
                tostring(inst.TextYAlignment), tostring(inst.TextWrapped),
                tostring(inst.RichText)))
        end

        if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
            table.insert(out, ("%s  image=%s imgT=%s color=%s scale=%s rect=%s"):format(
                recuo, cortar(inst.Image, 120), num(inst.ImageTransparency),
                cor(inst.ImageColor3), tostring(inst.ScaleType),
                tostring(inst.SliceCenter)))
        end

        if inst:IsA("ScrollingFrame") then
            table.insert(out, ("%s  scroll=bar%d canvas=%s autoCanvas=%s dir=%s"):format(
                recuo, inst.ScrollBarThickness, udim2(inst.CanvasSize),
                tostring(inst.AutomaticCanvasSize), tostring(inst.ScrollingDirection)))
        end

        local extras = propsDeLayout(inst)
        if #extras > 0 then
            table.insert(out, recuo .. "  " .. table.concat(extras, "  "))
        end
    end

    if nivel < 40 then
        local filhos = inst:GetChildren()
        table.sort(filhos, function(a, b)
            if a:IsA("GuiObject") and b:IsA("GuiObject") then
                if a.LayoutOrder ~= b.LayoutOrder then
                    return a.LayoutOrder < b.LayoutOrder
                end
            end
            return a.Name < b.Name
        end)
        for _, filho in ipairs(filhos) do
            if not filho:IsA("UIGradient") and not filho:IsA("UICorner")
                and not filho:IsA("UIStroke") and not filho:IsA("UIPadding")
                and not filho:IsA("UIListLayout") and not filho:IsA("UIGridLayout")
                and not filho:IsA("UIScale") then
                descreverNo(filho, out, nivel + 1, raiz, contador)
            end
        end
    end
end

local function dumparInstancia(inst, titulo)
    local out = {}
    local raiz = inst:IsA("ScreenGui") and inst or nil
    table.insert(out, ("===== %s :: %s \"%s\" :: %s ====="):format(
        titulo or "dump", inst.ClassName, inst.Name, os.date("%H:%M:%S")))
    descreverNo(inst, out, 0, raiz, { n = 0 })
    local texto = table.concat(out, "\n")

    local teto = (CONFIG.limiteGuiMB or 12) * 1024 * 1024
    local manual = titulo == "GUI manual"
    if not manual and GUI_TOTAL_BYTES + #texto > teto then
        if not AVISOU_TETO_GUI then
            AVISOU_TETO_GUI = true
            avisar(("teto de GUI atingido (%d MB) — dump automático desligado; dumparGui(true) continua valendo"):format(CONFIG.limiteGuiMB))
        end
        return texto
    end

    GUI_TOTAL_BYTES = GUI_TOTAL_BYTES + #texto
    table.insert(GUI_DUMPS, texto)
    return texto
end

local function coletarGuis()
    local alvos, vistos = {}, {}
    local Players = game:GetService("Players")
    local pl = Players.LocalPlayer

    local function adicionar(g)
        if g:IsA("ScreenGui") and not vistos[g] then
            vistos[g] = true
            table.insert(alvos, g)
        end
    end

    if pl then
        local pg = pl:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, g in ipairs(pg:GetChildren()) do adicionar(g) end
        end
    end

    for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do adicionar(g) end

    if CAP.gethui then
        local ok, hui = pcall(CAP.gethui)
        if ok and hui then
            for _, g in ipairs(hui:GetChildren()) do adicionar(g) end
        end
    end

    return alvos
end

-- Marca o que já existia antes do AirFlow. O dump automático passa a pegar
-- só o que nascer depois — sem encher o arquivo com o chat e o menu do Roblox.
local function marcarGuisExistentes()
    for _, g in ipairs(coletarGuis()) do
        GUIS_VISTAS[g] = true
    end
end

-- UI do próprio jogo (vive em PlayerGui) muda a cada frame: vida, ping, FPS.
-- Vigiar isso só infla o arquivo. A UI do script fica em CoreGui/HUI.
local function ehUiDoJogo(g)
    if CONFIG.guisIgnoradas[g.Name] then return true end
    local ok, pg = pcall(function()
        local pl = game:GetService("Players").LocalPlayer
        return pl and pl:FindFirstChildOfClass("PlayerGui")
    end)
    if not ok or not pg then return false end
    local ok2, dentro = pcall(function() return g:IsDescendantOf(pg) end)
    return ok2 and dentro
end

local GUIS_MONITORADAS = {}
local GUIS_SUJAS = {}
local BOTOES_VISTOS = setmetatable({}, { __mode = "k" })

local function ligarClique(botao)
    if BOTOES_VISTOS[botao] then return end
    BOTOES_VISTOS[botao] = true
    pcall(function()
        botao.MouseButton1Click:Connect(function()
            table.insert(CLIQUES, ("[+%8.3fs] clique: %s"):format(
                os.clock() - T0, botao:GetFullName()))
            flush()
        end)
    end)
end

-- Toda GUI nova ganha um vigia: quando um descendente nasce/morre, a GUI fica
-- suja e o laço redumpa ela inteira. É assim que abas criadas sob demanda
-- (Lobby, Settings) entram no arquivo sem eu pedir nada.
local function monitorarGuis()
    for _, g in ipairs(coletarGuis()) do
        if not GUIS_MONITORADAS[g] then
            GUIS_MONITORADAS[g] = true
            if ehUiDoJogo(g) then
                GUIS_VISTAS[g] = true
            else
                pcall(function()
                    for _, d in ipairs(g:GetDescendants()) do
                        if d:IsA("GuiButton") then ligarClique(d) end
                    end

                    g.DescendantAdded:Connect(function(d)
                        GUIS_SUJAS[g] = true
                        if d:IsA("GuiButton") then ligarClique(d) end
                    end)
                    g.DescendantRemoving:Connect(function()
                        GUIS_SUJAS[g] = true
                    end)
                end)
            end
        end
    end
end

local function dumpSujas()
    monitorarGuis()
    for g in pairs(GUIS_SUJAS) do
        GUIS_SUJAS[g] = nil
        if not ehUiDoJogo(g) then
            GUIS_VISTAS[g] = true
            pcall(dumparInstancia, g, "GUI dinâmica")
        end
    end
    flush()
end

-- Inventário compacto: só os textos visíveis, para mandar por telemetria.
local function inventarioGui(limite)
    limite = limite or 400
    local linhas = {}

    for _, g in ipairs(coletarGuis()) do
        table.insert(linhas, "## " .. g.Name)
        local vistos = {}
        for _, d in ipairs(g:GetDescendants()) do
            if #linhas >= limite then break end
            local classe = d.ClassName
            if (classe == "TextLabel" or classe == "TextButton" or classe == "TextBox")
                and d.Text ~= "" then
                local texto = d.Text:gsub("%s+", " "):sub(1, 90)
                if not vistos[texto] then
                    vistos[texto] = true
                    table.insert(linhas, "  " .. texto)
                end
            end
        end
    end

    return table.concat(linhas, "\n")
end

local function dumparGui(forcar)
    local alvos = coletarGuis()
    local total = 0

    for _, g in ipairs(alvos) do
        if forcar or not GUIS_VISTAS[g] then
            GUIS_VISTAS[g] = true
            dumparInstancia(g, forcar and "GUI manual" or "GUI")
            total = total + 1
        end
    end

    flush()
    if total > 0 then
        print(("[Gravador] %d GUI(s) dumpada(s)"):format(total))
    end
    return total
end

local function copiarGui()
    if not CAP.setclipboard then
        print("[Gravador] setclipboard indisponível — use dumparGui() e leia o arquivo")
        return false
    end
    local texto = GUI_DUMPS[#GUI_DUMPS]
    if not texto then
        dumparGui(true)
        texto = GUI_DUMPS[#GUI_DUMPS]
    end
    if not texto then return false end
    pcall(CAP.setclipboard, texto)
    print("[Gravador] última GUI copiada para a área de transferência")
    return true
end

-- ── 3. Estado do jogo ────────────────────────────────────────────────────────

local ultimaAmostra = nil

local function atributos(inst, limite)
    local ok, attrs = pcall(function() return inst:GetAttributes() end)
    if not ok or type(attrs) ~= "table" then return "" end
    local partes, n = {}, 0
    for k, v in next, attrs do
        n = n + 1
        if n > (limite or 12) then table.insert(partes, "…") break end
        table.insert(partes, ("%s=%s"):format(tostring(k), fmt(v)))
    end
    return table.concat(partes, " ")
end

local function amostrarEstado()
    local Players = game:GetService("Players")
    local pl = Players.LocalPlayer
    if not pl then return end

    local partes = { ("[+%8.3fs]"):format(os.clock() - T0) }

    local char = pl.Character
    if char then
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if root then
            local v = root.AssemblyLinearVelocity or root.Velocity
            table.insert(partes, ("pos=%s vel=%.0f"):format(vetor(root.Position), v.Magnitude))
        end
        if hum then
            table.insert(partes, ("hp=%d/%d state=%s"):format(
                math.floor(hum.Health), math.floor(hum.MaxHealth), tostring(hum:GetState())))
        end
        local a = atributos(char)
        if a ~= "" then table.insert(partes, "char{" .. a .. "}") end
    end

    local lf = pl:FindFirstChild("leaderstats")
    if lf then
        local stats = {}
        for _, s in ipairs(lf:GetChildren()) do
            table.insert(stats, ("%s=%s"):format(s.Name, tostring(s.Value)))
            if #stats >= 8 then break end
        end
        if #stats > 0 then table.insert(partes, "stats{" .. table.concat(stats, " ") .. "}") end
    end

    local aPl = atributos(pl)
    if aPl ~= "" then table.insert(partes, "player{" .. aPl .. "}") end

    local titans = workspace:FindFirstChild("Titans")
    if titans then
        local lista = titans:GetChildren()
        table.insert(partes, ("titans=%d"):format(#lista))

        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root then
                local melhor, dist = nil, math.huge
                for _, t in ipairs(lista) do
                    local hit = t:FindFirstChild("Hitboxes")
                    local h = hit and hit:FindFirstChild("Hit")
                    local nape = h and h:FindFirstChild("Nape")
                    if nape then
                        local d = (nape.Position - root.Position).Magnitude
                        if d < dist then melhor, dist = t, d end
                    end
                end
                if melhor then
                    table.insert(partes, ("alvo=%s dist=%.1f"):format(melhor.Name, dist))
                end
            end
        end
    end

    local linha = table.concat(partes, "  ")

    -- Só grava se mudou de forma relevante, para o log não virar lixo.
    local chave = linha:gsub("%[%+%s*[%d%.]+s%]%s*", ""):gsub("pos=%b()", "")
    if chave ~= ultimaAmostra then
        ultimaAmostra = chave
        table.insert(ESTADO, linha)
    end
end

-- ── 4. Diagnóstico e relatório ───────────────────────────────────────────────

local function diagnostico()
    local function caminhoWorkspace()
        local ok, ws = pcall(function()
            if getworkspace then return getworkspace() end
            if getcustomasset then return "?" end
            return nil
        end)
        return ok and ws or nil
    end

    print("")
    print("================ GRAVADOR VHUB ================")
    print("executor   : " .. tostring(identifyexecutor and identifyexecutor() or "?"))
    print("workspace  : " .. tostring(caminhoWorkspace() or "?"))
    print("remotes    : " .. tostring(pastaRemotes() and "encontrados" or "NÃO encontrados"))
    for _, nome in ipairs({ "writefile", "appendfile", "readfile", "listfiles",
        "hookmetamethod", "getrawmetatable", "setreadonly", "getnamecallmethod",
        "newcclosure", "hookfunction", "setclipboard", "gethui", "getgc" }) do
        print(("  %-18s %s"):format(nome, CAP[nome == "getnamecallmethod" and "getnamecall"
            or nome] and "ok" or "—"))
    end
    if next(HOOK_DIAG) then
        print("  --- hooks ---")
        for nome, resultado in pairs(HOOK_DIAG) do
            print(("  %-18s %s"):format(nome, resultado))
        end
    end
    print("==============================================")
    print("")

    local texto = {}
    table.insert(texto, "=== Diagnóstico do executor ===")
    table.insert(texto, "executor: " .. tostring(identifyexecutor and identifyexecutor() or "?"))
    table.insert(texto, "workspace: " .. tostring(caminhoWorkspace() or "?"))
    for k, v in pairs(CAP) do
        table.insert(texto, ("%s=%s"):format(k, v and "ok" or "—"))
    end
    table.insert(texto, "remotes: " .. tostring(pastaRemotes() and pastaRemotes():GetFullName() or "?"))
    if pastaRemotes() then
        for _, r in ipairs(pastaRemotes():GetChildren()) do
            table.insert(texto, ("  %s (%s)"):format(r.Name, r.ClassName))
        end
    end
    for nome, resultado in pairs(HOOK_DIAG) do
        table.insert(texto, ("hook %s = %s"):format(nome, resultado))
    end
    return table.concat(texto, "\n")
end

local function salvarTudo(nome)
    nome = nome or ARQ_RELATO

    -- Última fotografia de tudo que estiver aberto agora.
    pcall(function()
        monitorarGuis()
        dumparGui(true)
    end)

    local partes = {}
    table.insert(partes, "==============================================")
    table.insert(partes, "  VHUB · RELATÓRIO DO AIRFLOW")
    table.insert(partes, ("  gerado em %s"):format(os.date("%d/%m/%Y %H:%M:%S")))
    table.insert(partes, "==============================================")
    table.insert(partes, "")
    table.insert(partes, diagnostico())
    table.insert(partes, "")
    table.insert(partes, ("eventos de remote: %d"):format(#REMOTES))
    table.insert(partes, ("amostras de estado: %d"):format(#ESTADO))
    table.insert(partes, ("dumps de GUI: %d"):format(#GUI_DUMPS))

    if #avisos > 0 then
        table.insert(partes, "")
        table.insert(partes, "--- avisos ---")
        for _, a in ipairs(avisos) do table.insert(partes, a) end
    end

    if #GUI_DUMPS > 0 then
        table.insert(partes, "")
        table.insert(partes, "############ GUI ############")
        table.insert(partes, table.concat(GUI_DUMPS, "\n\n"))
    end

    if #REMOTES > 0 then
        table.insert(partes, "")
        table.insert(partes, "############ REMOTES ############")
        table.insert(partes, table.concat(REMOTES, "\n"))
    end

    if #ESTADO > 0 then
        table.insert(partes, "")
        table.insert(partes, "############ ESTADO ############")
        table.insert(partes, table.concat(ESTADO, "\n"))
    end

    local texto = table.concat(partes, "\n")
    local ok = escrever(nome, texto)
    if ok then
        print(("[Gravador] relatório salvo: %s"):format(nome))
    else
        print("[Gravador] writefile indisponível — mandando por telemetria")
    end
    if #texto <= 20000 then
        pcall(enviarTexto, texto, "relatorio")
    else
        pcall(enviarTexto, texto:sub(1, 20000), "relatorio cortado")
    end
    pcall(function()
        enviarTexto(inventarioGui(), "textos")
        if #CLIQUES > 0 then
            enviarTexto(table.concat(CLIQUES, "\n"), "cliques")
        end
    end)
    return ok
end

local function copiarTudo()
    if not CAP.setclipboard then
        print("[Gravador] setclipboard indisponível")
        return false
    end
    local pedacos = {}
    if #GUI_DUMPS > 0 then
        table.insert(pedacos, "### GUI ###\n" .. table.concat(GUI_DUMPS, "\n\n"))
    end
    if #REMOTES > 0 then
        table.insert(pedacos, "### REMOTES ###\n" .. table.concat(REMOTES, "\n"))
    end
    if #ESTADO > 0 then
        table.insert(pedacos, "### ESTADO ###\n" .. table.concat(ESTADO, "\n"))
    end
    pcall(CAP.setclipboard, table.concat(pedacos, "\n\n"))
    print("[Gravador] tudo copiado para a área de transferência")
    return true
end

-- Varre arquivos do executor atrás de cache/config do AirFlow/Luarmor.
local function listarArquivos(dir)
    if not CAP.listfiles then
        print("[Gravador] listfiles indisponível")
        return {}
    end

    local ok, lista = pcall(CAP.listfiles, dir or "")
    if not ok or type(lista) ~= "table" then return {} end

    print(("[Gravador] %d arquivo(s) em %q"):format(#lista, dir or ""))
    for _, f in ipairs(lista) do
        print("  " .. tostring(f))
    end
    return lista
end

local function lerSePequeno(nome, limite)
    if not CAP.readfile then return nil end
    local ok, conteudo = pcall(CAP.readfile, nome)
    if not ok or type(conteudo) ~= "string" then return nil end
    limite = limite or 300000
    if #conteudo > limite then return conteudo:sub(1, limite) .. "\n…truncado" end
    return conteudo
end

-- ── 5. Parar ─────────────────────────────────────────────────────────────────

local laco = true

local function parar()
    laco = false
    for _, h in pairs(hooksInstalados) do
        if h.desfazer then pcall(h.desfazer) end
    end
    hooksInstalados = {}
    flush()
    print("[Gravador] parado. Rode salvarTudo() para gravar o relatório.")
end

-- ── 6. Início ────────────────────────────────────────────────────────────────

local function iniciar()
    print("")
    print("=====================================================")
    print("  GRAVADOR VHUB ATIVO")
    print("=====================================================")
    print("  1. Execute o AirFlow normalmente agora")
    print("  2. Use a interface dele: abra cada aba, ligue cada função")
    print("  3. Ao terminar:  salvarTudo()")
    print("  4. Interface atual:  dumparGui()  /  copiarGui()")
    print("  5. Diagnóstico:  diagnostico()")
    print("=====================================================")
    print("")

    diagnostico()

    if CONFIG.hookRemotes then
        local ok = tentarHooks()
        avisar(ok and "hooks de remote instalados"
            or "não consegui instalar hooks — o log de remotes virá vazio")
    else
        pcall(telemetria, "inicio sem hook")
    end

    observarRemotesNovos()

    task.spawn(function()
        local ultimoFlush = os.clock()
        local proximaAmostra = 0

        while laco do
            task.wait(0.5)

            if CONFIG.autoGui then
                pcall(dumparGui)
                pcall(dumpSujas)
            end

            if CONFIG.amostrar and os.clock() >= proximaAmostra then
                proximaAmostra = os.clock() + CONFIG.intervalo
                pcall(amostrarEstado)
            end

            if os.clock() - ultimoFlush >= CONFIG.flushSegundos then
                ultimoFlush = os.clock()
                pcall(flush)
            end
        end
    end)
end

-- ── API pública ──────────────────────────────────────────────────────────────

local API = {
    iniciar = iniciar,
    parar = parar,
    dumparGui = dumparGui,
    dumparInstancia = dumparInstancia,
    copiarGui = copiarGui,
    copiarTudo = copiarTudo,
    salvarTudo = salvarTudo,
    diagnostico = diagnostico,
    tentarHooks = tentarHooks,
    relatorioHooks = relatorioHooks,
    telemetria = telemetria,
    inventarioGui = inventarioGui,
    listarArquivos = listarArquivos,
    lerSePequeno = lerSePequeno,
    config = CONFIG,
    arquivos = {
        remotes = ARQ_REMOTES,
        estado = ARQ_ESTADO,
        gui = ARQ_GUI,
        relatorio = ARQ_RELATO,
        hooks = ARQ_HOOKS,
    },
}
_G.VHUB_REC = API
-- getgenv() é o ambiente compartilhado entre abas do mesmo executor: é por aqui
-- que um segundo script (outra aba, sem reexecutar o gravador) acha a API.
pcall(function()
    local g = getgenv()
    if type(g) == "table" then g.VHUB_REC = API end
end)

-- Aliases em português, para digitar no console sem pensar.
_G.salvarTudo = salvarTudo
_G.dumparGui = dumparGui
_G.copiarGui = copiarGui
_G.copiarTudo = copiarTudo
_G.diagnostico = diagnostico
_G.tentarHooks = tentarHooks
_G.relatorioHooks = relatorioHooks
_G.telemetria = telemetria
_G.inventarioGui = inventarioGui
_G.listarArquivos = listarArquivos

iniciar()

return API
