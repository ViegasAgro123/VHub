--[[
    VHub · Extrator de Script
    Arquivo: diagnose/extract.lua

    Captura o código de OUTRO script que esteja rodando no mesmo executor.

    COMO FUNCIONA
    -------------
    Um script protegido por VM (Luraph, MoonSec) precisa, em algum momento,
    virar algo que o Roblox execute. Esse momento é o ponto fraco.

    Três portas de captura, em ordem de eficácia:

      1. loadstring / load  — todo script passa por aqui para virar chunk.
         Interceptamos e lemos o que passa.

      2. debug.getinfo       — dado um chunk já compilado, recupera a fonte.
         Requer que o executor exponha debug.getinfo com .source.

      3. getfenv             — a VM cria ambientes isolados. Navegando por eles
         dá para achar o chunk vivo.

    O AirFlow é Luraph, então a porta 1 é a mais provável de funcionar: ele
    chama loadstring no bootstrapper da Luarmor.

    USO
    ---
    Cole isto no executor ANTES de executar o AirFlow:

        loadstring(game:HttpGet("https://raw.githubusercontent.com/ViegasAgro123/VHub/main/diagnose/extract.lua"))()

    Depois execute o AirFlow normalmente. Cada chunk capturado é salvo em
    arquivo e resumido no console (F9).

    No fim, use a função salvarTudo() para gravar um único arquivo com tudo.
--]]

local CAPTURED = {}
local MAX_CAPTURE = 40

local function now()
    return os.date("%H:%M:%S")
end

local function safeFileName(s)
    return (tostring(s):gsub("[^%w%-_%.]", "_")):sub(1, 60)
end

-- ── Porta 1: interceptar loadstring ──────────────────────────────────────────

local originalLoadstring = loadstring
local originalLoad = load

local function capture(source, origem)
    if type(source) ~= "string" then return end
    if #source < 40 then return end

    -- Evita capturar o mesmo chunk duas vezes.
    for _, c in ipairs(CAPTURED) do
        if c.source == source then return end
    end
    if #CAPTURED >= MAX_CAPTURE then return end

    table.insert(CAPTURED, {
        source = source,
        origem = origem,
        quando = now(),
        tamanho = #source,
    })

    local idx = #CAPTURED
    print(("[Extrator] #%d  %s  %d bytes  (%s)"):format(
        idx, origem, #source, now()))

    -- Salva em arquivo, se o executor permitir.
    pcall(function()
        if writefile then
            local nome = ("vhub_capture_%02d_%s.lua"):format(idx, safeFileName(origem))
            writefile(nome, source)
            print(("            salvo: %s"):format(nome))
        end
    end)
end

if originalLoadstring then
    loadstring = function(source, chunkname)
        capture(source, chunkname or "loadstring")
        return originalLoadstring(source, chunkname)
    end
    print("[Extrator] loadstring interceptado")
end

if originalLoad then
    load = function(chunk, chunkname, ...)
        if type(chunk) == "string" then
            capture(chunk, chunkname or "load")
        end
        return originalLoad(chunk, chunkname, ...)
    end
    print("[Extrator] load interceptado")
end

-- ── Porta 2: hook em debug.getinfo ───────────────────────────────────────────
-- Alguns scripts chamam debug.getinfo para verificar quem os chamou. Se o
-- executor expõe hookfunction, aproveitamos para inspecionar o que passa.

pcall(function()
    if hookfunction and debug and debug.getinfo then
        local original = debug.getinfo
        debug.getinfo = function(...)
            local info = original(...)
            if type(info) == "table" and info.source and type(info.source) == "string" then
                local src = info.source
                if #src > 200 and not src:find("^=") then
                    capture(src, "debug.getinfo:" .. tostring(info.what or "?"))
                end
            end
            return info
        end
        print("[Extrator] debug.getinfo observado")
    end
end)

-- ── Porta 3: varredura de ambiente ───────────────────────────────────────────
-- Percorre globais e ambientes procurando strings que pareçam código Lua.
-- Útil quando o script já rodou e o chunk está vivo em algum lugar.

local function pareceLua(s)
    if type(s) ~= "string" or #s < 200 then return false end
    local amostra = s:sub(1, 4000)
    -- Heurística: código Lua tem essas palavras-chave em profusão.
    local hits = 0
    for _, kw in ipairs({ "local ", "function", "then", "end", "return", "=" }) do
        if amostra:find(kw, 1, true) then hits = hits + 1 end
    end
    -- E não deve ser uma tabela de bytecode (que é cheia de \ddd).
    local escapes = select(2, amostra:gsub("\\%d%d?%d?", ""))
    return hits >= 4 and escapes < (#amostra / 20)
end

function _G.vasculharAmbiente()
    print("[Extrator] vasculhando ambiente…")
    local achados = 0

    local function varrer(tabela, prefixo, profundidade)
        if profundidade > 3 then return end
        local ok, iter = pcall(function() return pairs(tabela) end)
        if not ok or not iter then return end

        for k, v in iter do
            if type(v) == "string" and pareceLua(v) then
                capture(v, prefixo .. "." .. tostring(k))
                achados = achados + 1
            elseif type(v) == "table" and v ~= _G and profundidade < 3 then
                pcall(varrer, v, prefixo .. "." .. tostring(k), profundidade + 1)
            end
        end
    end

    pcall(varrer, _G, "_G", 0)
    print(("[Extrator] %d chunk(s) encontrados na varredura"):format(achados))
    return achados
end

-- ── Relatório e salvamento ───────────────────────────────────────────────────

function _G.listarCapturas()
    print(("[Extrator] %d captura(s):"):format(#CAPTURED))
    for i, c in ipairs(CAPTURED) do
        print(("  #%d  %-32s  %7d bytes  %s"):format(
            i, c.origem, c.tamanho, c.quando))
    end
    return CAPTURED
end

function _G.salvarTudo(nome)
    nome = nome or "vhub_capturas.txt"
    if not writefile then
        print("[Extrator] writefile indisponível — não dá para salvar")
        return false
    end

    local partes = {
        "=== Capturas do extrator VHub ===\n",
        ("Total: %d\n\n"):format(#CAPTURED),
    }
    for i, c in ipairs(CAPTURED) do
        table.insert(partes, ("\n\n===== #%d  %s  (%d bytes) =====\n\n"):format(
            i, c.origem, c.tamanho))
        table.insert(partes, c.source)
    end

    local ok = pcall(writefile, nome, table.concat(partes))
    if ok then
        print(("[Extrator] salvo em %s"):format(nome))
    else
        print("[Extrator] falha ao salvar")
    end
    return ok
end

-- Expõe uma versão que copia o maior chunk capturado para a área de transferência.
function _G.copiarMaior()
    local maior, idx = nil, 0
    for i, c in ipairs(CAPTURED) do
        if not maior or c.tamanho > maior.tamanho then maior, idx = c, i end
    end
    if not maior then
        print("[Extrator] nada capturado ainda")
        return
    end
    if setclipboard then
        pcall(setclipboard, maior.source)
        print(("[Extrator] #%d (%d bytes) copiado para a área de transferência"):format(
            idx, maior.tamanho))
    else
        print("[Extrator] setclipboard indisponível")
    end
    return maior
end

-- ── Instruções ───────────────────────────────────────────────────────────────

print("")
print("=====================================================")
print("  EXTRATOR VHUB ATIVO")
print("=====================================================")
print("  1. Execute o AirFlow normalmente agora")
print("  2. Cada chunk capturado aparece aqui")
print("  3. Ao terminar, rode:  salvarTudo()")
print("     ou copie o maior:   copiarMaior()")
print("  4. Se nada aparecer, rode:  vasculharAmbiente()")
print("=====================================================")
print("")
