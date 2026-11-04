--[[
    ============================================================================
    AOTR · Attack on Titan Revolution — Loader
    ============================================================================
    Formato de uso no executor:

        loadstring(game:HttpGet("<URL_DO_RAW>"))()

    Este arquivo é o STUB. Ele não contém o script — apenas o busca e executa.
    O código real fica em aotr/main.lua no mesmo repositório.

    POR QUE UM STUB E NÃO O SCRIPT INTEIRO AQUI
    -------------------------------------------
    É o mesmo desenho do AirFlow: o usuário carrega uma linha curta, e o
    conteúdo pode ser atualizado sem que ninguém precise recolar nada. A
    diferença é que aqui o que trafega é Lua legível, não uma VM cifrada.

    Vantagem prática: eu conserto um bug, faço push, e todo mundo pega a
    correção no próximo loadstring. Sem redistribuir.

    SEGURANÇA
    ---------
    Um stub que baixa e executa código remoto é, por definição, confiança no
    host. Duas mitigações reais:
      1. HTTPS obrigatório e host fixo — o HttpGet não aceita redirect para
         outro domínio sem que o executor permita.
      2. O conteúdo é Lua legível, não bytecode. Qualquer um pode abrir a URL
         no navegador e ler o que está executando. Isso é deliberado.
--]]

-- ── Configuração ─────────────────────────────────────────────────────────────
-- Substituído pelo build/publish.mjs com a URL real do repositório.

local BASE_URL = "https://raw.githubusercontent.com/ViegasAgro123/VHub/main/aotr"

-- Versão do stub. Serve para diagnosticar cache velho do executor: se o print
-- no console mostrar uma versão antiga, o HttpGet foi cacheado.
local LOADER_VERSION = "1.0.0"

-- ── Cache-buster ─────────────────────────────────────────────────────────────
-- Alguns executores cacheiam HttpGet agressivamente, e o usuário fica preso numa
-- versão antiga sem entender por quê. Um parâmetro de query com o dia faz o CDN
-- tratar como recurso novo, mantendo o cache dentro do mesmo dia.

local function cacheBust()
    local t = os.date("*t")
    return string.format("?d=%04d%02d%02d%02d", t.year, t.month, t.day, t.hour)
end

-- ── Fetch ────────────────────────────────────────────────────────────────────

local function fetch(path)
    local url = BASE_URL .. "/" .. path .. cacheBust()
    local ok, body = pcall(function()
        return game:HttpGet(url, true)
    end)
    if not ok or type(body) ~= "string" or #body < 32 then
        return nil, url
    end
    return body, url
end

-- ── Execução ─────────────────────────────────────────────────────────────────

local function fail(msg, url)
    warn("[AOTR] " .. msg)
    if url then warn("[AOTR] URL: " .. url) end
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "AOTR · Falha ao carregar",
            Text = msg,
            Duration = 8,
        })
    end)
end

print(("[AOTR] loader v%s · buscando…"):format(LOADER_VERSION))

local source, url = fetch("main.lua")
if not source then
    fail("Não foi possível baixar o script. Verifique sua conexão.", url)
    return
end

local chunk, compileErr = loadstring(source)
if not chunk then
    fail("O script baixado tem erro de sintaxe: " .. tostring(compileErr), url)
    return
end

local ok, result = pcall(chunk)
if not ok then
    fail("Erro ao executar: " .. tostring(result), url)
    return
end

-- ── Retorno ──────────────────────────────────────────────────────────────────

if type(result) == "table" then
    pcall(function()
        getgenv().AOTR = result
    end)
end

return result
