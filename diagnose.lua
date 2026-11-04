--[[
    AOTR · Diagnóstico de Ambiente
    Arquivo: build/diagnose_env.lua

    Roda isto no executor ANTES do script. Ele testa, um por um, cada recurso
    que o AOTR usa e reporta o que existe e o que falta.

    A razão de existir: um script Lua não derruba o Roblox por erro de lógica —
    o pior que acontece é uma mensagem no console. Quem derruba o processo é a
    camada do executor, quando o script chama algo que ele não implementa ou
    implementa mal. Este arquivo encontra esse ponto em 5 segundos.

    Uso:
        loadstring(game:HttpGet("https://raw.githubusercontent.com/ViegasAgro123/VHub/main/diagnose.lua"))()
--]]

local function line(label, value)
    print(string.format("%-28s %s", label, tostring(value)))
end

print("=========== DIAGNOSTICO DE AMBIENTE ===========")
print("")

-- ── 1. Executor ──────────────────────────────────────────────────────────────

print("[1] EXECUTOR")
line("identifyexecutor", (function()
    local ok, v = pcall(function() return identifyexecutor and identifyexecutor() end)
    return ok and v or "AUSENTE"
end)())
line("getgenv", getgenv ~= nil)
line("getfenv", getfenv ~= nil)
line("loadstring", loadstring ~= nil)
line("HttpGet", game.HttpGet ~= nil)
line("request", (request or http_request) ~= nil)
print("")

-- ── 2. Serviços que o script usa ─────────────────────────────────────────────

print("[2] SERVICOS")
for _, name in ipairs({
    "Players", "RunService", "TweenService", "UserInputService",
    "VirtualUser", "HttpService", "StarterGui", "ReplicatedStorage",
    "Workspace", "VirtualInputManager",
}) do
    local ok, svc = pcall(function() return game:GetService(name) end)
    line(name, ok and (svc and "ok" or "nil") or "ERRO")
end
print("")

-- ── 3. Globais ───────────────────────────────────────────────────────────────

print("[3] GLOBAIS")
line("game", game ~= nil)
line("workspace", workspace ~= nil)
line("Instance", Instance ~= nil)
line("task", task ~= nil)
line("task.wait", task and task.wait ~= nil)
line("task.spawn", task and task.spawn ~= nil)
line("typeof", typeof ~= nil)
line("Enum", Enum ~= nil)
print("")

-- ── 4. Datatypes ─────────────────────────────────────────────────────────────

print("[4] DATATYPES")
line("Color3", Color3 ~= nil)
line("Color3.fromRGB", Color3 and Color3.fromRGB ~= nil)
line("UDim2", UDim2 ~= nil)
line("UDim2.fromOffset", UDim2 and UDim2.fromOffset ~= nil)
line("UDim2.fromScale", UDim2 and UDim2.fromScale ~= nil)
line("Vector3", Vector3 ~= nil)
line("Vector2", Vector2 ~= nil)
line("CFrame", CFrame ~= nil)
line("CFrame.lookAt", CFrame and CFrame.lookAt ~= nil)
line("TweenInfo", TweenInfo ~= nil)
line("ColorSequence", ColorSequence ~= nil)
line("NumberSequence", NumberSequence ~= nil)
print("")

-- ── 5. O LIMITE DE 20 KEYPOINTS ──────────────────────────────────────────────

print("[5] SEQUENCES (o bug que derrubou antes)")

local function trySeq(n)
    local seq = {}
    for i = 0, n - 1 do
        local t = i / (n - 1)
        table.insert(seq, ColorSequenceKeypoint.new(t, Color3.fromRGB(255, 0, 0)))
    end
    local ok, err = pcall(function() return ColorSequence.new(seq) end)
    return ok, err
end

for _, n in ipairs({ 2, 10, 20, 21, 24 }) do
    local ok, err = trySeq(n)
    line(("ColorSequence com %d"):format(n), ok and "OK" or ("FALHOU: " .. tostring(err)))
end
print("")

-- ── 6. Propriedades de instância que o script seta ───────────────────────────

print("[6] INSTANCE")
local function tryProp(class, prop, value)
    local ok, err = pcall(function()
        local inst = Instance.new(class)
        inst[prop] = value
        inst:Destroy()
    end)
    return ok, err
end

local frame = nil
pcall(function() frame = Instance.new("Frame") end)

if frame then
    for _, p in ipairs({
        "BackgroundTransparency", "BorderSizePixel", "ClipsDescendants",
        "AutomaticSize", "ZIndex",
    }) do
        local ok, err = tryProp("Frame", p, p == "AutomaticSize" and Enum.AutomaticSize.Y or 0)
        line("Frame." .. p, ok and "OK" or ("FALHOU: " .. tostring(err)))
    end
    frame:Destroy()
end

local sb = nil
pcall(function()
    sb = Instance.new("ScrollingFrame")
    sb.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sb:Destroy()
end)
line("ScrollingFrame.AutomaticCanvasSize", sb ~= nil)

local g = nil
pcall(function()
    g = Instance.new("UIGradient")
    g.Rotation = 90
    g:Destroy()
end)
line("UIGradient", g ~= nil)
print("")

-- ── 7. O jogo ────────────────────────────────────────────────────────────────

print("[7] JOGO")
line("PlaceId", game.PlaceId)
line("GameId", game.GameId)
line("JobId", game.JobId)

local titans = workspace:FindFirstChild("Titans")
line("workspace.Titans", titans and "ENCONTRADO" or "ausente")

if titans then
    local n = #titans:GetChildren()
    line("  filhos", n)
    for i, t in ipairs(titans:GetChildren()) do
        if i > 5 then break end
        local hitboxes = t:FindFirstChild("Hitboxes")
        local hit = hitboxes and hitboxes:FindFirstChild("Hit")
        local nape = hit and hit:FindFirstChild("Nape")
        local hum = t:FindFirstChildOfClass("Humanoid")
        line("  " .. t.Name, ("Hitboxes=%s Hit=%s Nape=%s Humanoid=%s"):format(
            hitboxes and "sim" or "nao",
            hit and "sim" or "nao",
            nape and "sim" or "nao",
            hum and "sim" or "nao"))
    end
end

local rs = game:GetService("ReplicatedStorage")
local assets = rs:FindFirstChild("Assets")
local remotes = assets and assets:FindFirstChild("Remotes")
line("Assets.Remotes", remotes and "ENCONTRADO" or "ausente")
if remotes then
    line("  GET", remotes:FindFirstChild("GET") and "sim" or "nao")
    line("  POST", remotes:FindFirstChild("POST") and "sim" or "nao")
end
print("")

-- ── 8. Atributos do jogador ──────────────────────────────────────────────────

print("[8] JOGADOR")
local lp = game:GetService("Players").LocalPlayer
line("LocalPlayer", lp and lp.Name or "nil")
if lp then
    line("Character", lp.Character and lp.Character.Name or "nil")
    for _, attr in ipairs({ "Exploiter", "Blacklisted", "Level", "Prestige", "Refills" }) do
        line("  " .. attr, tostring(lp:GetAttribute(attr)))
    end
end
print("")

-- ── 9. Teste de GUI ──────────────────────────────────────────────────────────

print("[9] GUI")
local ok, err = pcall(function()
    local pg = lp:WaitForChild("PlayerGui", 5)
    if not pg then error("PlayerGui nao apareceu em 5s") end
    local sg = Instance.new("ScreenGui")
    sg.Name = "AOTR_Teste"
    sg.ResetOnSpawn = false
    sg.Parent = pg
    local f = Instance.new("Frame")
    f.Size = UDim2.fromOffset(100, 100)
    f.Parent = sg
    task.wait(0.2)
    sg:Destroy()
end)
line("criar e destruir ScreenGui", ok and "OK" or ("FALHOU: " .. tostring(err)))

print("")
print("=========== FIM ===========")
print("Se chegou aqui sem fechar o Roblox, o ambiente esta OK")
print("e o problema esta em algo especifico do script.")
