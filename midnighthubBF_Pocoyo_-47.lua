local P   = game:GetService("Players")
local TS  = game:GetService("TweenService")
local RS  = game:GetService("ReplicatedStorage")
local plr = P.LocalPlayer
local vel = 300
velocidadeConfig = vel

local Boud      = true
local pSats     = 10
local ChooseWP  = "Melee"
local bringCount = 0
local PosMon = nil -- posição do mob que tá sendo farmado agora; o Bring puxa os outros pra cá
local CurrentTarget = nil -- o mob que tá sendo farmado agora (o Bring força ele pra baixo do player)
local BringEnemy -- forward declaration (definida mais abaixo, chamada aqui dentro do kill)
local ServerHop -- forward declaration (definida mais abaixo, na seção de Server Hop)

-- ===== Auto Save de Configurações =====
-- Salva toda alteração de Toggle/Slider/Dropdown num .json no workspace do
-- executor, e carrega de volta quando o script roda de novo.
local HttpS       = game:GetService("HttpService")
local ConfigDir   = "MidNightHub"
local ConfigPath  = ConfigDir .. "/" .. plr.Name .. "-BloxFruit.json"
local SavedConfig = {}

local function ensureConfigFolder()
    pcall(function()
        if not isfolder(ConfigDir) then makefolder(ConfigDir) end
    end)
end

local function loadSavedConfig()
    ensureConfigFolder()
    pcall(function()
        if isfile(ConfigPath) then
            local decoded = HttpS:JSONDecode(readfile(ConfigPath))
            if type(decoded) == "table" then SavedConfig = decoded end
        end
    end)
end

local function saveConfig()
    pcall(function()
        ensureConfigFolder()
        writefile(ConfigPath, HttpS:JSONEncode(SavedConfig))
    end)
end

-- Chama toda vez que um Toggle/Slider/Dropdown muda de valor
local function setConfig(key, value)
    SavedConfig[key] = value
    saveConfig()
end

-- Usado no "Default" de cada controle: retorna o valor salvo, ou o padrão
-- caso ainda não exista nada salvo pra essa chave.
local function getConfig(key, default)
    if SavedConfig[key] == nil then return default end
    return SavedConfig[key]
end

loadSavedConfig()

notween = function(cf)
    local r = getRoot(); if r then r.CFrame = cf end
end

local function statsSetings(stat, amount)
    if plr.Data.Points.Value == 0 then return end
    local m = { Melee="Melee", Defense="Defense", Sword="Sword", Gun="Gun", Devil="Demon Fruit" }
    if m[stat] then RS.Remotes.CommF_:InvokeServer("AddPoint", m[stat], amount) end
end

local function GetConnectionEnemies(name)
    local function scan(folder)
        for _, v in pairs(folder:GetChildren()) do
            if v:IsA("Model") then
                local ok = typeof(name) == "table" and table.find(name, v.Name) or v.Name == name
                if ok then
                    local h = v:FindFirstChild("Humanoid")
                    if h and h.Health > 0 then return v end
                end
            end
        end
    end
    return scan(RS) or scan(workspace.Enemies)
end

local function killMob(mob, active)
    if not mob or not active then return end
    pcall(function()
        local isNewTarget = not mob:GetAttribute("Locked")
        if isNewTarget then
            mob:SetAttribute("Locked", mob.HumanoidRootPart.CFrame)
        end
        PosMon = mob:GetAttribute("Locked").Position
        CurrentTarget = mob
        if BringEnemy then pcall(BringEnemy) end

        if isNewTarget then
            -- só na primeira vez que engaja esse mob: posiciona o player.
            -- Depois disso o player fica parado e o Bring traz o mob até embaixo dele.
            local c    = getChar()
            local tool = c and c:FindFirstChildOfClass("Tool")
            if not tool then return end
            if tool.ToolTip == "Blox Fruit" or doubleAttackEnabled then
                notween((mob.HumanoidRootPart.CFrame * CFrame.new(0,7,0)) * CFrame.Angles(0,math.rad(90),0))
            else
                notween((mob.HumanoidRootPart.CFrame * CFrame.new(0,27,0)) * CFrame.Angles(0,math.rad(180),0))
            end
        end
    end)
end

local function printBeltName(data)
    if type(data) == "table" and data.Quest and data.Quest.BeltName then
        return data.Quest.BeltName
    end
end

local function checkQuesta()
    local net = RS.Modules.Net
    local rf  = net and net:FindFirstChild("RF/DragonHunter")
    if not rf then return false, nil, 0, 0 end
    pcall(function() rf:InvokeServer({ [1] = { Context = "RequestQuest" } }) end)
    local ok, data = pcall(function() return rf:InvokeServer({ [1] = { Context = "Check" } }) end)
    if not ok or not data or not data.Text then return false, nil, 0, 0 end
    local text = tostring(data.Text)
    if string.find(text, "Defeat") then
        local mob   = string.find(text, "Hydra") and "Hydra Enforcer" or "Venomous Assailant"
        local count = tonumber(string.sub(text, 8, 9)) or 0
        return true, mob, count, 1
    elseif string.find(text, "Destroy") then
        return true, nil, 10, 2
    end
    return false, nil, 0, 0
end

local function getChar() return plr.Character end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function addBC()
    local root = getRoot()
    if not root or root:FindFirstChild("BC") then return end
    local bc = Instance.new("BodyVelocity")
    bc.Name     = "BC"
    bc.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bc.Velocity = Vector3.new(0, 0, 0)
    bc.Parent   = root
end

local function addHL()
    local c = getChar()
    if not c or c:FindFirstChild("HL") then return end
    local hl = Instance.new("Highlight")
    hl.Name                = "HL"
    hl.Enabled             = true
    hl.FillColor           = Color3.fromRGB(255, 165, 0)
    hl.OutlineColor        = Color3.fromRGB(255, 0, 0)
    hl.FillTransparency    = 1
    hl.OutlineTransparency = 1
    hl.Parent              = c
end

local function noCollide()
    local c = getChar()
    if not c then return end
    for _, d in pairs(c:GetDescendants()) do
        if d:IsA("BasePart") then d.CanCollide = false end
    end
end

local function applyMods()
    pcall(function()
        addBC(); addHL(); noCollide()
        local hum = getHum()
        if hum and hum.Sit then hum.Sit = false end
    end)
end

local function clearMods()
    pcall(function()
        local root = getRoot()
        if root then
            local bc = root:FindFirstChild("BC")
            if bc then bc:Destroy() end
        end
        local c = getChar()
        if c then
            for _, d in pairs(c:GetDescendants()) do
                if d:IsA("BasePart") then d.CanCollide = true end
            end
        end
    end)
end

local st       = false
local activeTw = nil

-- Solta o "segurar no ar" (BodyVelocity) quando não tem alvo pra tweenar agora,
-- assim o personagem cai/volta ao normal em vez de ficar preso flutuando depois
-- de matar o mob. Só solta se nenhum outro modo de farm precisar do st ligado.
local function releaseHoldIfIdle()
    if not (_G["AutoFarm_Level"] or _G["AutoFarm_Bone"] or _G["AutoFarm_Tyrant"]
        or _G["FarmTyrant"] or _G["FarmPhaBinh"]) then
        st = false
        clearMods()
    end
end

_tp = function(cf)
    if not st then return end
    local c    = getChar()
    local root = getRoot()
    local hum  = getHum()
    if not c or not root then return end

    local dist = (cf.Position - root.Position).Magnitude
    if dist == 0 then return end

    local ti = TweenInfo.new(dist / vel, Enum.EasingStyle.Linear)
    local tw = TS:Create(root, ti, {CFrame = cf})

    if hum and hum.Sit then
        root.CFrame = CFrame.new(root.Position.X, cf.Y, root.Position.Z)
    end

    activeTw = tw
    tw:Play()
    tw.Completed:Connect(function()
        if activeTw == tw then activeTw = nil end
    end)
    return tw
end

local function eq(toolName)
    if not toolName then return end
    local tool = plr.Backpack:FindFirstChild(toolName)
    if not tool then return end
    local hum = getHum()
    if hum then hum:EquipTool(tool) end
end

local function getWeapon()
    for _, v in pairs(plr.Backpack:GetChildren()) do
        if v:IsA("Tool") and tostring(v.ToolTip) == ChooseWP then return v.Name end
    end
    local c = getChar()
    if c then
        for _, v in pairs(c:GetChildren()) do
            if v:IsA("Tool") and tostring(v.ToolTip) == ChooseWP then return v.Name end
        end
    end
    return "Combat"
end

local Config = {
    AttackDistance = 65,
    AttackCooldown = 0.05,
    ComboReset     = 0.15,
    MaxCombo       = 4,
    AttackMobs     = true,
    AttackPlayers  = true,
    AutoClick      = false,
    HitboxParts    = { "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "RightHand", "LeftHand" }
}

local fastAttackEnabled   = true
local doubleAttackEnabled = false

local Ms, NQ, QL, NM, CFQ, CFM, NX = nil, nil, nil, nil, nil, nil, nil
local CheckMS = {}

local function inTable(t, v)
    for _, i in pairs(t) do if i == v then return true end end
    return false
end

local mundox = {
    [2753915549]    = "World1",
    [85211729168715] = "World1",
    [4442272183]    = "World2",
    [79091703265657] = "World2",
    [7449423635]    = "World3",
    [100117331123089] = "World3"
}

function CheckLv()
    local lv = _G["TyrantForceLv"] or plr.Data.Level.Value

    local world = mundox[game.PlaceId]
    if world == nil then
        local map = workspace:FindFirstChild("Map")
        if map then
            if map:FindFirstChild("TikiOutpost") then
                world = "World3"
            else
                for _, n in ipairs({ "Cafe","CursedShip","Kingdom","SecondSea","SeaOfTreats","RainbowMist","GreenZone","FloatingTurtle","HauntedCastle2" }) do
                    if map:FindFirstChild(n) then world = "World2"; break end
                end
            end
        end

        if world == nil then
            if lv >= 1500 then
                world = "World3"
            elseif lv >= 700 then
                world = "World2"
            else
                world = "World1"
            end
        end
    end

    local clamped = false

    if world == "World1" and lv >= 700 then
        lv = 699; clamped = true
    elseif world == "World2" and lv >= 1500 then
        lv = 1499; clamped = true
    elseif world == "World2" and lv < 700 then
        lv = 700; clamped = true
    elseif world == "World3" and lv < 1500 then
        lv = 1500; clamped = true
    end

    CheckMS = {}

    if lv <= 9 then
        Ms="Bandit" NQ="BanditQuest1" QL=1 NM="Bandit"
        CFQ=CFrame.new(1059.37195,15.4495068,1550.4231)
        CFM=CFrame.new(1353.44885,3.40935516,1376.92029) NX=10

    elseif lv>=10 and lv<=14 then
        Ms="Monkey" NQ="JungleQuest" QL=1 NM="Monkey"
        CFQ=CFrame.new(-1604.12012,36.8521118,154.23732)
        CFM=CFrame.new(-1443.765,61.742,-50.498) NX=15

    elseif lv>=15 and lv<=29 then
        Ms="Gorilla" NQ="JungleQuest" QL=2 NM="Gorilla"
        CFQ=CFrame.new(-1604.12012,36.8521118,154.23732)
        CFM=CFrame.new(-1142.848,4.522,-648.452) NX=30

    elseif lv>=30 and lv<=39 then
        Ms="Pirate" NQ="BuggyQuest1" QL=1 NM="Pirate"
        CFQ=CFrame.new(-1139.59717,4.75205183,3825.16211)
        CFM=CFrame.new(-1213.372,4.674,3910.169) NX=40

    elseif lv>=40 and lv<=59 then
        Ms="Brute" NQ="BuggyQuest1" QL=2 NM="Brute"
        CFQ=CFrame.new(-1139.59717,4.75205183,3825.16211)
        CFM=CFrame.new(-1147.198,64.303,4339.257) NX=60

    elseif lv>=60 and lv<=74 then
        Ms="Desert Bandit" NQ="DesertQuest" QL=1 NM="Desert Bandit"
        CFQ=CFrame.new(894.488647,5.14000702,4392.43359)
        CFM=CFrame.new(932.788818,6.8503746,4488.24609) NX=75

    elseif lv>=75 and lv<=89 then
        Ms="Desert Officer" NQ="DesertQuest" QL=2 NM="Desert Officer"
        CFQ=CFrame.new(894.488647,5.14000702,4392.43359)
        CFM=CFrame.new(1617.07886,1.5542295,4295.54932) NX=90

    elseif lv>=90 and lv<=99 then
        Ms="Snow Bandit" NQ="SnowQuest" QL=1 NM="Snow Bandit"
        CFQ=CFrame.new(1389.74451,86.6520844,-1298.90796)
        CFM=CFrame.new(1412.92346,55.3503647,-1260.62036) NX=100

    elseif lv>=100 and lv<=119 then
        Ms="Snowman" NQ="SnowQuest" QL=2 NM="Snowman"
        CFQ=CFrame.new(1389.74451,86.6520844,-1298.90796)
        CFM=CFrame.new(1376.86401,97.2779999,-1396.93115) NX=120

    elseif lv>=120 and lv<=149 then
        Ms="Chief Petty Officer" NQ="MarineQuest2" QL=1 NM="Chief Petty Officer"
        CFQ=CFrame.new(-5039.58643,27.3500385,4324.68018)
        CFM=CFrame.new(-4882.8623,22.6520386,4255.53516) NX=150

    elseif lv>=150 and lv<=174 then
        Ms="Sky Bandit" NQ="SkyQuest" QL=1 NM="Sky Bandit"
        CFQ=CFrame.new(-4839.53027,716.368591,-2619.44165)
        CFM=CFrame.new(-4959.51367,365.39267,-2974.56812) NX=175

    elseif lv>=175 and lv<=189 then
        Ms="Dark Master" NQ="SkyQuest" QL=2 NM="Dark Master"
        CFQ=CFrame.new(-4839.53027,716.368591,-2619.44165)
        CFM=CFrame.new(-5079.98096,376.477356,-2194.17139) NX=190

    elseif lv>=190 and lv<=209 then
        Ms="Prisoner" NQ="PrisonerQuest" QL=1 NM="Prisoner"
        CFQ=CFrame.new(5308.93115,1.65517521,475.120514)
        CFM=CFrame.new(5433.39307,88.678093,514.986877) NX=210

    elseif lv>=210 and lv<=249 then
        Ms="Dangerous Prisoner" NQ="PrisonerQuest" QL=2 NM="Dangerous Prisoner"
        CFQ=CFrame.new(5308.93115,1.65517521,475.120514)
        CFM=CFrame.new(5433.39307,88.678093,514.986877) NX=250

    elseif lv>=250 and lv<=274 then
        Ms="Toga Warrior" NQ="ColosseumQuest" QL=1 NM="Toga Warrior"
        CFQ=CFrame.new(-1576.11743,7.38933945,-2983.30762)
        CFM=CFrame.new(-1779.97583,44.6077499,-2736.35474) NX=275

    elseif lv>=275 and lv<=299 then
        Ms="Gladiator" NQ="ColosseumQuest" QL=2 NM="Gladiator"
        CFQ=CFrame.new(-1576.11743,7.38933945,-2983.30762)
        CFM=CFrame.new(-1274.75903,58.1895943,-3188.16309) NX=300

    elseif lv>=300 and lv<=324 then
        Ms="Military Soldier" NQ="MagmaQuest" QL=1 NM="Military Soldier"
        CFQ=CFrame.new(-5316.55859,12.2370615,8517.2998)
        CFM=CFrame.new(-5363.01123,41.5056877,8548.47266) NX=325

    elseif lv>=325 and lv<=374 then
        Ms="Military Spy" NQ="MagmaQuest" QL=2 NM="Military Spy"
        CFQ=CFrame.new(-5316.55859,12.2370615,8517.2998)
        CFM=CFrame.new(-5787.99023,120.864456,8762.25293) NX=375

    elseif lv>=375 and lv<=399 then
        Ms="Fishman Warrior" NQ="FishmanQuest" QL=1 NM="Fishman Warrior"
        CFQ=CFrame.new(61122.5625,18.4716396,1568.16504)
        CFM=CFrame.new(60946.6094,48.6735229,1525.91687) NX=400

    elseif lv>=400 and lv<=449 then
        Ms="Fishman Commando" NQ="FishmanQuest" QL=2 NM="Fishman Commando"
        CFQ=CFrame.new(61122.5625,18.4716396,1568.16504)
        CFM=CFrame.new(61902.7383,18.4828358,1478.33936) NX=450

    elseif lv>=450 and lv<=474 then
        Ms="God's Guard" NQ="SkyExp1Quest" QL=1 NM="God's Guards"
        CFQ=CFrame.new(-4721.71436,845.277161,-1954.20105)
        CFM=CFrame.new(-4716.95703,853.089722,-1933.925427) NX=475

    elseif lv>=475 and lv<=524 then
        Ms="Shanda" NQ="SkyExp1Quest" QL=2 NM="Shandas"
        CFQ=CFrame.new(-7859.09814,5544.19043,-381.476196)
        CFM=CFrame.new(-7904.57373,5584.37646,-459.62973) NX=525

    elseif lv>=525 and lv<=549 then
        Ms="Royal Squad" NQ="SkyExp2Quest" QL=1 NM="Royal Squad"
        CFQ=CFrame.new(-7906.81592,5634.6626,-1411.99194)
        CFM=CFrame.new(-7555.04199,5606.90479,-1303.24744) NX=550

    elseif lv>=550 and lv<=624 then
        Ms="Royal Soldier" NQ="SkyExp2Quest" QL=2 NM="Royal Soldier"
        CFQ=CFrame.new(-7906.81592,5634.6626,-1411.99194)
        CFM=CFrame.new(-7837.31152,5649.65186,-1791.08582) NX=625

    elseif lv>=625 and lv<=649 then
        Ms="Galley Pirate" NQ="FountainQuest" QL=1 NM="Galley Pirate"
        CFQ=CFrame.new(5259.81982,37.3500175,4050.0293)
        CFM=CFrame.new(5569.80518,38.5269432,3849.01196) NX=650

    elseif lv>=650 and lv<=699 then
        Ms="Galley Captain" NQ="FountainQuest" QL=2 NM="Galley Captain"
        CFQ=CFrame.new(5259.81982,37.3500175,4050.0293)
        CFM=CFrame.new(5782.90186,94.5326462,4716.78174) NX=700

    elseif lv>=700 and lv<=724 then
        Ms="Raider" NQ="Area1Quest" QL=1 NM="Raider"
        CFQ=CFrame.new(-429.543518,71.7699966,1836.18188)
        CFM=CFrame.new(-728.32672,52.779319,2345.77051) NX=725

    elseif lv>=725 and lv<=774 then
        Ms="Mercenary" NQ="Area1Quest" QL=2 NM="Mercenary"
        CFQ=CFrame.new(-429.543518,71.7699966,1836.18188)
        CFM=CFrame.new(-1004.32440,80.158866,1424.61938) NX=775

    elseif lv>=775 and lv<=799 then
        Ms="Swan Pirate" NQ="Area2Quest" QL=1 NM="Swan Pirate"
        CFQ=CFrame.new(638.43811,71.769989,918.282898)
        CFM=CFrame.new(1068.66430,137.61428,1322.10607) NX=800

    elseif lv>=800 and lv<=874 then
        Ms="Factory Staff" NQ="Area2Quest" QL=2 NM="Factory Staff"
        CFQ=CFrame.new(632.698608,73.1055908,918.666321)
        CFM=CFrame.new(73.078674,81.863441,-27.470672) NX=875

    elseif lv>=875 and lv<=899 then
        Ms="Marine Lieutenant" NQ="MarineQuest3" QL=1 NM="Marine Lieutenant"
        CFQ=CFrame.new(-2440.79639,71.7140732,-3216.06812)
        CFM=CFrame.new(-2821.37231,75.897277,-3070.08911) NX=900

    elseif lv>=900 and lv<=949 then
        Ms="Marine Captain" NQ="MarineQuest3" QL=2 NM="Marine Captain"
        CFQ=CFrame.new(-2440.79639,71.7140732,-3216.06812)
        CFM=CFrame.new(-1861.23107,80.176582,-3254.69750) NX=950

    elseif lv>=950 and lv<=974 then
        Ms="Zombie" NQ="ZombieQuest" QL=1 NM="Zombie"
        CFQ=CFrame.new(-5497.06152,47.5923004,-795.237061)
        CFM=CFrame.new(-5657.77685,78.969734,-928.687011) NX=975

    elseif lv>=975 and lv<=999 then
        Ms="Vampire" NQ="ZombieQuest" QL=2 NM="Vampire"
        CFQ=CFrame.new(-5497.06152,47.5923004,-795.237061)
        CFM=CFrame.new(-6037.66796,32.184638,-1340.65979) NX=1000

    elseif lv>=1000 and lv<=1049 then
        Ms="Snow Trooper" NQ="SnowMountainQuest" QL=1 NM="Snow Trooper"
        CFQ=CFrame.new(609.858826,400.119904,-5372.25928)
        CFM=CFrame.new(549.14733,427.387054,-5563.69873) NX=1050

    elseif lv>=1050 and lv<=1099 then
        Ms="Winter Warrior" NQ="SnowMountainQuest" QL=2 NM="Winter Warrior"
        CFQ=CFrame.new(609.858826,400.119904,-5372.25928)
        CFM=CFrame.new(1142.74511,475.639801,-5199.41650) NX=1100

    elseif lv>=1100 and lv<=1124 then
        Ms="Lab Subordinate" NQ="IceSideQuest" QL=1 NM="Lab Subordinate"
        CFQ=CFrame.new(-6064.06885,15.2422857,-4902.97852)
        CFM=CFrame.new(-5707.47167,15.951709,-4513.39208) NX=1125

    elseif lv>=1125 and lv<=1174 then
        Ms="Horned Warrior" NQ="IceSideQuest" QL=2 NM="Horned Warrior"
        CFQ=CFrame.new(-6064.06885,15.2422857,-4902.97852)
        CFM=CFrame.new(-6341.36669,15.951770,-5723.16210) NX=1175

    elseif lv>=1175 and lv<=1199 then
        Ms="Magma Ninja" NQ="FireSideQuest" QL=1 NM="Magma Ninja"
        CFQ=CFrame.new(-5428.03174,15.0622921,-5299.43457)
        CFM=CFrame.new(-5449.67285,76.658744,-5808.20068) NX=1200

    elseif lv>=1200 and lv<=1249 then
        Ms="Lava Pirate" NQ="FireSideQuest" QL=2 NM="Lava Pirate"
        CFQ=CFrame.new(-5428.03174,15.0622921,-5299.43457)
        CFM=CFrame.new(-5213.33154,49.737880,-4701.45117) NX=1250

    elseif lv>=1250 and lv<=1274 then
        Ms="Ship Deckhand" NQ="ShipQuest1" QL=1 NM="Ship Deckhand"
        CFQ=CFrame.new(1037.80127,125.092171,32911.6016)
        CFM=CFrame.new(1212.01110,150.792053,33059.24609) NX=1275

    elseif lv>=1275 and lv<=1299 then
        Ms="Ship Engineer" NQ="ShipQuest1" QL=2 NM="Ship Engineer"
        CFQ=CFrame.new(1037.80127,125.092171,32911.6016)
        CFM=CFrame.new(919.47863,43.544013,32779.96875) NX=1300

    elseif lv>=1300 and lv<=1324 then
        Ms="Ship Steward" NQ="ShipQuest2" QL=1 NM="Ship Steward"
        CFQ=CFrame.new(968.80957,125.092171,33244.125)
        CFM=CFrame.new(919.43853,129.555999,33436.03515) NX=1325

    elseif lv>=1325 and lv<=1349 then
        Ms="Ship Officer" NQ="ShipQuest2" QL=2 NM="Ship Officer"
        CFQ=CFrame.new(968.80957,125.092171,33244.125)
        CFM=CFrame.new(1036.01794,181.439041,33315.72656) NX=1350

    elseif lv>=1350 and lv<=1374 then
        Ms="Arctic Warrior" NQ="FrostQuest" QL=1 NM="Arctic Warrior"
        CFQ=CFrame.new(5667.6582,26.7997818,-6486.08984)
        CFM=CFrame.new(5966.24609,62.970020,-6179.38281) NX=1375

    elseif lv>=1375 and lv<=1424 then
        Ms="Snow Lurker" NQ="FrostQuest" QL=2 NM="Snow Lurker"
        CFQ=CFrame.new(5667.6582,26.7997818,-6486.08984)
        CFM=CFrame.new(5407.07373,69.194374,-6880.88037) NX=1425

    elseif lv>=1425 and lv<=1449 then
        Ms="Sea Soldier" NQ="ForgottenQuest" QL=1 NM="Sea Soldier"
        CFQ=CFrame.new(-3054.44458,235.544281,-10142.8193)
        CFM=CFrame.new(-3028.22363,64.674514,-9775.42675) NX=1450

    elseif lv>=1450 and lv<=1499 then
        Ms="Water Fighter" NQ="ForgottenQuest" QL=2 NM="Water Fighter"
        CFQ=CFrame.new(-3054.44458,235.544281,-10142.8193)
        CFM=CFrame.new(-3352.90136,285.015563,-10534.84179) NX=1500

    elseif lv>=1500 and lv<=1524 then
        Ms="Pirate Millionaire" NQ="PiratePortQuest" QL=1 NM="Pirate Millionaire"
        CFQ=CFrame.new(-712.82727,98.577049,5711.95410)
        CFM=CFrame.new(-712.82727,98.577049,5711.95410) NX=1525

    elseif lv>=1525 and lv<=1574 then
        Ms="Pistol Billionaire" NQ="PiratePortQuest" QL=2 NM="Pistol Billionaire"
        CFQ=CFrame.new(-723.43316,147.429061,5931.99316)
        CFM=CFrame.new(-723.43316,147.429061,5931.99316) NX=1575

    elseif lv>=1575 and lv<=1599 then
        Ms="Dragon Crew Warrior" NQ="DragonCrewQuest" QL=1 NM="Dragon Crew Warrior"
        CFQ=CFrame.new(6735.12061,127.107239,-711.085754)
        CFM=CFrame.new(6735.12061,127.107239,-711.085754) NX=1600

    elseif lv>=1600 and lv<=1624 then
        Ms="Dragon Crew Archer" NQ="DragonCrewQuest" QL=2 NM="Dragon Crew Archer"
        CFQ=CFrame.new(6955.89746,546.665893,309.040130)
        CFM=CFrame.new(6955.89746,546.665893,309.040130) NX=1625

    elseif lv>=1625 and lv<=1649 then
        Ms="Hydra Enforcer" NQ="VenomCrewQuest" QL=1 NM="Hydra Enforcer"
        CFQ=CFrame.new(4620.61572,1002.29547,399.086883)
        CFM=CFrame.new(4620.61572,1002.29547,399.086883) NX=1650

    elseif lv>=1650 and lv<=1699 then
        Ms="Venomous Assailant" NQ="VenomCrewQuest" QL=2 NM="Venomous Assailant"
        CFQ=CFrame.new(4697.59180,1100.65137,946.401978)
        CFM=CFrame.new(4697.59180,1100.65137,946.401978) NX=1700

    elseif lv>=1700 and lv<=1724 then
        Ms="Marine Commodore" NQ="MarineTreeIsland" QL=1 NM="Marine Commodore"
        CFQ=CFrame.new(2180.54126,27.8156815,-6741.5498)
        CFM=CFrame.new(2286.00781,73.133918,-7159.80908) NX=1725

    elseif lv>=1725 and lv<=1774 then
        Ms="Marine Rear Admiral" NQ="MarineTreeIsland" QL=2 NM="Marine Rear Admiral"
        CFQ=CFrame.new(2179.98828,28.731239,-6740.05517)
        CFM=CFrame.new(3656.77368,160.524063,-7001.59863) NX=1775

    elseif lv>=1775 and lv<=1799 then
        Ms="Fishman Raider" NQ="DeepForestIsland3" QL=1 NM="Fishman Raider"
        CFQ=CFrame.new(-10581.6563,330.872955,-8761.18652)
        CFM=CFrame.new(-10407.52636,331.762634,-8368.51660) NX=1800

    elseif lv>=1800 and lv<=1824 then
        Ms="Fishman Captain" NQ="DeepForestIsland3" QL=2 NM="Fishman Captain"
        CFQ=CFrame.new(-10581.6563,330.872955,-8761.18652)
        CFM=CFrame.new(-10994.70117,352.381408,-9002.11035) NX=1825

    elseif lv>=1825 and lv<=1849 then
        Ms="Forest Pirate" NQ="DeepForestIsland" QL=1 NM="Forest Pirate"
        CFQ=CFrame.new(-13234.04,331.488495,-7625.40137)
        CFM=CFrame.new(-13274.47851,332.378143,-7769.58056) NX=1850

    elseif lv>=1850 and lv<=1899 then
        Ms="Mythological Pirate" NQ="DeepForestIsland" QL=2 NM="Mythological Pirate"
        CFQ=CFrame.new(-13234.04,331.488495,-7625.40137)
        CFM=CFrame.new(-13680.60742,501.081542,-6991.18945) NX=1900

    elseif lv>=1900 and lv<=1924 then
        Ms="Jungle Pirate" NQ="DeepForestIsland2" QL=1 NM="Jungle Pirate"
        CFQ=CFrame.new(-12680.3818,389.971039,-9902.01953)
        CFM=CFrame.new(-12256.16015,331.738281,-10485.83691) NX=1925

    elseif lv>=1925 and lv<=1974 then
        Ms="Musketeer Pirate" NQ="DeepForestIsland2" QL=2 NM="Musketeer Pirate"
        CFQ=CFrame.new(-12680.3818,389.971039,-9902.01953)
        CFM=CFrame.new(-13457.90429,391.545654,-9859.17773) NX=1975

    elseif lv>=1975 and lv<=1999 then
        Ms="Reborn Skeleton" NQ="HauntedQuest1" QL=1 NM="Reborn Skeleton"
        CFQ=CFrame.new(-9479.2168,141.215088,5566.09277)
        CFM=CFrame.new(-8763.72363,165.722991,6159.86181) NX=2000

    elseif lv>=2000 and lv<=2024 then
        Ms="Living Zombie" NQ="HauntedQuest1" QL=2 NM="Living Zombie"
        CFQ=CFrame.new(-9479.2168,141.215088,5566.09277)
        CFM=CFrame.new(-10144.13183,138.626678,5838.08886) NX=2025

    elseif lv>=2025 and lv<=2049 then
        Ms="Demonic Soul" NQ="HauntedQuest2" QL=1 NM="Demonic Soul"
        CFQ=CFrame.new(-9516.99316,172.017181,6078.46533)
        CFM=CFrame.new(-9505.87207,172.104827,6158.99316) NX=2050

    elseif lv>=2050 and lv<=2074 then
        Ms="Possessed Mummy" NQ="HauntedQuest2" QL=2 NM="Possessed Mummy"
        CFQ=CFrame.new(-9516.99316,172.017181,6078.46533)
        CFM=CFrame.new(-9582.02246,6.251527,6205.47851) NX=2075

    elseif lv>=2075 and lv<=2099 then
        Ms="Peanut Scout" NQ="NutsIslandQuest" QL=1 NM="Peanut Scout"
        CFQ=CFrame.new(-2104.39086,38.104167,-10194.21875)
        CFM=CFrame.new(-2143.24194,47.721984,-10029.99511) NX=2100

    elseif lv>=2100 and lv<=2124 then
        Ms="Peanut President" NQ="NutsIslandQuest" QL=2 NM="Peanut President"
        CFQ=CFrame.new(-2104.39086,38.104167,-10194.21875)
        CFM=CFrame.new(-1859.35400,38.103168,-10422.42968) NX=2125

    elseif lv>=2125 and lv<=2149 then
        Ms="Ice Cream Chef" NQ="IceCreamIslandQuest" QL=1 NM="Ice Cream Chef"
        CFQ=CFrame.new(-820.64825,65.819526,-10965.79589)
        CFM=CFrame.new(-872.24658,65.819572,-10919.95703) NX=2150

    elseif lv>=2150 and lv<=2199 then
        Ms="Ice Cream Commander" NQ="IceCreamIslandQuest" QL=2 NM="Ice Cream Commander"
        CFQ=CFrame.new(-820.64825,65.819526,-10965.79589)
        CFM=CFrame.new(-558.06103,112.048957,-11290.77441) NX=2200

    elseif lv>=2200 and lv<=2224 then
        Ms="Cookie Crafter" NQ="CakeQuest1" QL=1 NM="Cookie Crafter"
        CFQ=CFrame.new(-2021.32007,37.7982254,-12028.7295)
        CFM=CFrame.new(-2374.13671,37.798263,-12125.30859) NX=2225

    elseif lv>=2225 and lv<=2249 then
        Ms="Cake Guard" NQ="CakeQuest1" QL=2 NM="Cake Guard"
        CFQ=CFrame.new(-2021.32007,37.7982254,-12028.7295)
        CFM=CFrame.new(-1598.30700,43.773197,-12244.58105) NX=2250

    elseif lv>=2250 and lv<=2274 then
        Ms="Baking Staff" NQ="CakeQuest2" QL=1 NM="Baking Staff"
        CFQ=CFrame.new(-1927.91602,37.7981339,-12842.5391)
        CFM=CFrame.new(-1887.80993,77.618507,-12998.35058) NX=2275

    elseif lv>=2275 and lv<=2299 then
        Ms="Head Baker" NQ="CakeQuest2" QL=2 NM="Head Baker"
        CFQ=CFrame.new(-1927.91602,37.7981339,-12842.5391)
        CFM=CFrame.new(-2216.18823,82.884521,-12869.29394) NX=2300

    elseif lv>=2300 and lv<=2324 then
        Ms="Cocoa Warrior" NQ="ChocQuest1" QL=1 NM="Cocoa Warrior"
        CFQ=CFrame.new(233.22836,29.876001,-12201.23339)
        CFM=CFrame.new(-21.55328,80.574996,-12352.38769) NX=2325

    elseif lv>=2325 and lv<=2349 then
        Ms="Chocolate Bar Battler" NQ="ChocQuest1" QL=2 NM="Chocolate Bar Battler"
        CFQ=CFrame.new(233.22836,29.876001,-12201.23339)
        CFM=CFrame.new(582.59057,77.188095,-12463.16210) NX=2350

    elseif lv>=2350 and lv<=2374 then
        Ms="Sweet Thief" NQ="ChocQuest2" QL=1 NM="Sweet Thief"
        CFQ=CFrame.new(150.50663,30.693693,-12774.50292)
        CFM=CFrame.new(165.18847,76.058853,-12600.83691) NX=2375

    elseif lv>=2375 and lv<=2399 then
        Ms="Candy Rebel" NQ="ChocQuest2" QL=2 NM="Candy Rebel"
        CFQ=CFrame.new(150.50663,30.693693,-12774.50292)
        CFM=CFrame.new(134.86563,77.247680,-12876.54785) NX=2400

    elseif lv>=2400 and lv<=2449 then
        Ms="Candy Pirate" NQ="CandyQuest1" QL=1 NM="Candy Pirate"
        CFQ=CFrame.new(-1150.04003,20.378934,-14446.33496)
        CFM=CFrame.new(-1310.50036,26.016523,-14562.40429) NX=2450

    elseif lv>=2450 and lv<=2474 then
        Ms="Isle Outlaw" NQ="TikiQuest1" QL=1 NM="Isle Outlaw"
        CFQ=CFrame.new(-16548.8164,55.6059914,-172.8125)
        CFM=CFrame.new(-16479.90039,226.611740,-300.31143) NX=2475

    elseif lv>=2475 and lv<=2499 then
        Ms="Island Boy" NQ="TikiQuest1" QL=2 NM="Island Boy"
        CFQ=CFrame.new(-16548.8164,55.6059914,-172.8125)
        CFM=CFrame.new(-16849.39648,192.865051,-150.78532) NX=2500

    elseif lv>=2500 and lv<=2524 then
        Ms="Sun-kissed Warrior" NQ="TikiQuest2" QL=1 NM="Sun-kissed Warrior"
        CFQ=CFrame.new(-16538,55,1049)
        CFM=CFrame.new(-16347,64,984) NX=2525

    elseif lv>=2525 and lv<=2550 then
        Ms="Isle Champion" NQ="TikiQuest2" QL=2 NM="Isle Champion"
        CFQ=CFrame.new(-16541.0215,57.3082275,1051.46118)
        CFM=CFrame.new(-16602.10156,130.387344,1087.24560) NX=2551

    elseif lv>=2551 and lv<=2574 then
        Ms="Serpent Hunter" NQ="TikiQuest3" QL=1 NM="Serpent Hunter"
        CFQ=CFrame.new(-16679.4785,176.7473,1474.3995)
        CFM=CFrame.new(-16679.4785,176.7473,1474.3995) NX=2575

    elseif lv>=2575 and lv<=2599 then
        Ms="Skull Slayer" NQ="TikiQuest3" QL=2 NM="Skull Slayer"
        CFQ=CFrame.new(-16759.5898,71.2837,1595.3399)
        CFM=CFrame.new(-16759.5898,71.2837,1595.3399) NX=2600

    elseif lv>=2600 and lv<=2624 then
        Ms="Reef Bandit" NQ="SubmergedQuest1" QL=1 NM="Reef Bandit"
        CFQ=CFrame.new(10882.264,-2086.322,10034.226)
        CFM=CFrame.new(10736.6191,-2087.8439,9338.4882) NX=2625

    elseif lv>=2625 and lv<=2649 then
        Ms="Coral Pirate" NQ="SubmergedQuest1" QL=2 NM="Coral Pirate"
        CFQ=CFrame.new(10882.264,-2086.322,10034.226)
        CFM=CFrame.new(10965.1025,-2158.8842,9177.2597) NX=2650

    elseif lv>=2650 and lv<=2674 then
        Ms="Sea Chanter" NQ="SubmergedQuest2" QL=1 NM="Sea Chanter"
        CFQ=CFrame.new(10882.264,-2086.322,10034.226)
        CFM=CFrame.new(10621.0342,-2087.844,10102.0332) NX=2675

    elseif lv>=2675 and lv<=2699 then
        Ms="Ocean Prophet" NQ="SubmergedQuest2" QL=2 NM="Ocean Prophet"
        CFQ=CFrame.new(10882.264,-2086.322,10034.226)
        CFM=CFrame.new(11056.1445,-2001.6717,10117.4493) NX=2700

    elseif lv>=2700 and lv<=2724 then
        Ms="High Disciple" NQ="SubmergedQuest3" QL=1 NM="High Disciple"
        CFQ=CFrame.new(9636.52441,-1992.19507,9609.52832)
        CFM=CFrame.new(9828.08789,-1940.90893,9693.06347) NX=2725

    elseif lv>=2725 then
        Ms="Grand Devotee" NQ="SubmergedQuest3" QL=2 NM="Grand Devotee"
        CFQ=CFrame.new(9636.52441,-1992.19507,9609.52832)
        CFM=CFrame.new(9557.58496,-1928.04040,9859.18261) NX=9999
    end

    if clamped then NX = 9999 end
end

local function spawnMob()
    local root = getRoot()
    if not root then return end
    for _, v in pairs(workspace["_WorldOrigin"].EnemyRegions:GetChildren()) do
        if (v.Position - root.Position).Magnitude <= 500 then
            RS.Remotes.Location:FireServer(v)
            return
        end
    end
end

local submPortalCF = CFrame.new(-16266.6376953125, 25.22066879272461, 1371.8131103515625)
local function getFarmWorld()
    local world = mundox[game.PlaceId]
    if world == nil then
        local map = workspace:FindFirstChild("Map")
        if map then
            if map:FindFirstChild("TikiOutpost") then
                world = "World3"
            else
                for _, n in ipairs({ "Cafe","CursedShip","Kingdom","SecondSea","SeaOfTreats","RainbowMist","GreenZone","FloatingTurtle","HauntedCastle2" }) do
                    if map:FindFirstChild(n) then world = "World2"; break end
                end
            end
        end
        if world == nil then
            local lv = plr.Data.Level.Value
            if lv >= 1500 then world = "World3"
            elseif lv >= 700 then world = "World2"
            else world = "World1" end
        end
    end
    return world
end

local function farm()
    local lv = plr.Data.Level.Value
    local farmWorld = getFarmWorld()
    if lv >= 2600 and not _G["_submEntered"] and farmWorld == "World3" and not _G["TyrantForceLv"] then
        local root = getRoot()
        local submAreaPos = Vector3.new(10658.1962890625, -1939.4412841796875, 9715.228515625)
        if root and (root.Position - submAreaPos).Magnitude > 1250 then
            repeat task.wait(0.1)
                if not _G["AutoFarm_Level"] then return end
                _tp(submPortalCF)
            until not _G["AutoFarm_Level"]
                or not getRoot()
                or (getRoot().Position - submPortalCF.Position).Magnitude <= 10
            if not _G["AutoFarm_Level"] then return end
            task.wait(0.5)
            pcall(function()
                game:GetService("ReplicatedStorage")
                    :WaitForChild("Modules")
                    :WaitForChild("Net")
                    :WaitForChild("RF/SubmarineWorkerSpeak")
                    :InvokeServer("TravelToSubmergedIsland")
            end)
            task.wait(3)
        end
        _G["_submEntered"] = true
        return
    end
    if plr.PlayerGui.Main.Quest.Visible == true and Ms ~= nil then
        if (_G["TyrantForceLv"] or plr.Data.Level.Value) >= NX then
            RS.Remotes.CommF_:InvokeServer("AbandonQuest")
            return
        end
        if not string.find(plr.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, NM) then
            RS.Remotes.CommF_:InvokeServer("AbandonQuest")
            return
        end

        local spawned = inTable(CheckMS, Ms)
        if not spawned then
            _tp(CFM)
            if (CFM.Position - getRoot().Position).Magnitude <= 15 then
                _tp(CFM * CFrame.new(0, 15, 0))
                spawnMob()
                table.insert(CheckMS, Ms)
            end
        else
            if not workspace.Enemies:FindFirstChild(Ms) then
                if workspace["_WorldOrigin"].EnemySpawns:FindFirstChild(NM) then
                    for _, v in pairs(workspace["_WorldOrigin"].EnemySpawns:GetChildren()) do
                        if v.Name == NM and not workspace.Enemies:FindFirstChild(Ms) then
                            repeat task.wait(0.1)
                                _tp(v.CFrame * CFrame.new(0, 15, 0))
                            until not _G["AutoFarm_Level"]
                                or (v.Position - getRoot().Position).Magnitude <= 16
                                or workspace.Enemies:FindFirstChild(Ms)
                        end
                    end
                else
                    _tp(CFM * CFrame.new(0, 10, 0))
                end
            end
            if workspace.Enemies:FindFirstChild(Ms) then
                for _, v in pairs(workspace.Enemies:GetChildren()) do
                    if v.Name == Ms and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                        if v.Humanoid:FindFirstChild("Animator") then
                            v.Humanoid.Animator:Destroy()
                        end
                        repeat task.wait()
                            if not _G["AutoFarm_Level"] then break end
                            pcall(function()
                                local isNewTarget = not v:GetAttribute("Locked")
                                if isNewTarget then
                                    v:SetAttribute("Locked", v.HumanoidRootPart.CFrame)
                                end
                                PosMon = v:GetAttribute("Locked").Position
                                CurrentTarget = v
                                if BringEnemy then pcall(BringEnemy) end

                                local char = getChar()
                                if not char then return end
                                local cur = char:FindFirstChildOfClass("Tool")
                                if not cur or cur.ToolTip ~= ChooseWP then
                                    local preferred = nil
                                    for _, t in pairs(plr.Backpack:GetChildren()) do
                                        if t:IsA("Tool") and t.ToolTip == ChooseWP then preferred = t; break end
                                    end
                                    if preferred then
                                        if cur then cur.Parent = plr.Backpack end
                                        preferred.Parent = char
                                    elseif not cur then
                                        local any = plr.Backpack:FindFirstChildOfClass("Tool")
                                        if any then any.Parent = char end
                                    end
                                end
                                local tool = char:FindFirstChildOfClass("Tool")
                                if not tool then return end

                                if isNewTarget then
                                    -- só na primeira vez: posiciona o player perto do mob;
                                    -- depois disso ele fica parado e o Bring traz o mob até ele
                                    local hrp = v:FindFirstChild("HumanoidRootPart")
                                    if not hrp then return end
                                    if tool.ToolTip == "Blox Fruit" or doubleAttackEnabled then
                                        _tp((hrp.CFrame * CFrame.new(0, 7, 0)) * CFrame.Angles(0, math.rad(90), 0))
                                    else
                                        _tp((hrp.CFrame * CFrame.new(0, 27, 0)) * CFrame.Angles(0, math.rad(180), 0))
                                    end
                                end
                            end)
                        until not _G["AutoFarm_Level"]
                            or not v.Parent
                            or v.Humanoid.Health <= 0
                            or plr.PlayerGui.Main.Quest.Visible == false
                    end
                end
            elseif RS:FindFirstChild(Ms) then
                _tp(RS:FindFirstChild(Ms).HumanoidRootPart.CFrame * CFrame.new(0, 20, 0))
            end
        end

    elseif plr.PlayerGui.Main.Quest.Visible == false then
        CheckLv()
        repeat task.wait(0.1)
            if not _G["AutoFarm_Level"] then break end
            _tp(CFQ)
            local root = getRoot()
            if CFQ and root and (CFQ.Position - root.Position).Magnitude <= 3 then
                RS.Remotes.CommF_:InvokeServer("StartQuest", NQ, QL)
                RS.Remotes.CommF_:InvokeServer("SetSpawnPoint")
                task.wait(2)
                break
            end
        until not _G["AutoFarm_Level"]
            or plr.PlayerGui.Main.Quest.Visible == true
    end
end

local boneMobs      = { "Reborn Skeleton", "Living Zombie", "Demonic Soul", "Possessed Mummy" }
local boneKillOrder = { "Reborn Skeleton", "Living Zombie", "Demonic Soul" }
local boneKillIdx   = 1
local boneKillCount = 0
local boneNPC    = CFrame.new(-9516.99316, 172.01718, 6078.46533)
local boneIdle   = CFrame.new(-9495.6806640625, 453.58624267578, 5977.3486328125)
local boneQuests = {
    { "StartQuest", "HauntedQuest2", 2 },
    { "StartQuest", "HauntedQuest2", 1 },
    { "StartQuest", "HauntedQuest1", 1 },
    { "StartQuest", "HauntedQuest1", 2 }
}

local function findBoneEnemy()
    local target = boneKillOrder[boneKillIdx]
    local function scan(folder)
        for _, v in pairs(folder:GetChildren()) do
            if v:IsA("Model") and v.Name == target then
                local hum = v:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then return v end
            end
        end
    end
    return scan(RS) or scan(workspace.Enemies)
end

local function setFarmActive(active, mode)
    if not active then
        if activeTw then activeTw:Cancel(); activeTw = nil end
        clearMods()
    end

    st               = active
    Config.AutoClick = active

    _G["AutoFarm_Level"]  = false
    _G["AutoFarm_Bone"]   = false
    _G["AutoFarm_Tyrant"] = false
    _G["_submEntered"]    = false

    if active then
        CheckMS = {}
        if mode == "Auto Farm (Nível)" then
            _G["AutoFarm_Level"] = true
        elseif mode == "Tyrant of Skyes" then
            _G["AutoFarm_Tyrant"] = true
        else
            _G["AutoFarm_Bone"] = true
            boneKillIdx   = 1
            boneKillCount = 0
        end
    end
end

task.spawn(function()
    game:GetService("RunService").Stepped:Connect(function()
        if st then pcall(applyMods) end
    end)
end)

task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            if Boud and not plr.Character:FindFirstChild("HasBuso") then
                RS.Remotes.CommF_:InvokeServer("Buso")
            end
        end)
    end
end)

local function getBringFilter()
    if _G["AutoFarm_Level"] then
        return Ms and {[Ms] = true} or nil
    elseif _G["AutoFarm_Bone"] then
        return {
            ["Reborn Skeleton"] = true,
            ["Living Zombie"]   = true,
            ["Demonic Soul"]    = true,
            ["Possessed Mummy"] = true,
        }
    elseif _G["AutoFarm_Tyrant"] or _G["FarmTyrant"] then
        return {
            ["Sun-kissed Warrior"] = true,
            ["Isle Champion"]      = true,
            ["Serpent Hunter"]     = true,
            ["Skull Slayer"]       = true,
        }
    elseif _G["AutoMaterial"] then
        return _G.CurrentMaterialFilter
    end
    return nil
end

local TweenInfoBring = TweenInfo.new(0.45, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

local function isRaidMobBring(mob)
    local n = mob.Name:lower()
    if n:find("raid") or n:find("microchip") or n:find("island") then return true end
    if mob:GetAttribute("IsRaid") or mob:GetAttribute("RaidMob") or mob:GetAttribute("IsBoss") then return true end
    local hum = mob:FindFirstChild("Humanoid")
    if hum and hum.WalkSpeed == 0 then return true end
    if mob.Parent and tostring(mob.Parent):lower():find("_worldorigin") then return true end
    return false
end

BringEnemy = function()
    if not (bringCount > 0 and st and not _G["AutoEliteQuest"]) then return end

    local char = plr.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    pcall(function() sethiddenproperty(plr, "SimulationRadius", math.huge) end)

    local filter = getBringFilter()
    local R = hrp.Position
    local r = 2
    local n = bringCount

    -- altura embaixo do player (mesmo offset usado pro player subir em cima do mob, invertido)
    local heightOffset = (ChooseWP == "Blox Fruit" or doubleAttackEnabled) and 7 or 27

    -- junta os mobs elegíveis (filtrados pela função ativa) dentro do raio de detecção
    local candidates = {}
    for _, mob in pairs(workspace.Enemies:GetChildren()) do
        if filter and not filter[mob.Name] then continue end

        local hum  = mob:FindFirstChild("Humanoid")
        local root = mob:FindFirstChild("HumanoidRootPart")

        if hum and root and hum.Health > 0 and not isRaidMobBring(mob) then
            local dist = (root.Position - R).Magnitude
            if dist <= 235 then
                table.insert(candidates, { mob = mob, hum = hum, root = root, dist = dist })
            end
        end
    end

    -- o mob que tá sendo farmado agora vira o primeiro da lista (fica bem embaixo
    -- do player); os outros preenchem o resto das vagas, mais perto primeiro
    table.sort(candidates, function(a, b)
        if a.mob == CurrentTarget then return true end
        if b.mob == CurrentTarget then return false end
        return a.dist < b.dist
    end)

    for i = 0, math.min(n, #candidates) - 1 do
        local entry = candidates[i + 1]
        local root  = entry.root
        local isCurrent = entry.mob == CurrentTarget

        -- o alvo atual vai direto embaixo do player (sem espalhar em círculo);
        -- os extras se distribuem num pequeno círculo ao redor desse ponto
        local ox, oz = 0, 0
        if not isCurrent then
            local theta = (2 * math.pi * i) / n
            ox, oz = r * math.cos(theta), r * math.sin(theta)
        end

        -- P_i = (R_x + ox, R_y - heightOffset, R_z + oz) — força o mob embaixo do player
        local targetPos = Vector3.new(R.X + ox, R.Y - heightOffset, R.Z + oz)

        -- "coleira": o mob fica livre (IA/animação/ataque normais, sem travar/ancorar).
        -- Só puxa de volta com tween quando ele já se afastou do lugar dele perto de você.
        local driftDist = (root.Position - targetPos).Magnitude
        if driftDist > 6 and not root:GetAttribute("Tweening") then
            root:SetAttribute("Tweening", true)
            local tween = TS:Create(root, TweenInfoBring, { CFrame = CFrame.new(targetPos) })
            tween:Play()
            tween.Completed:Once(function()
                if root then root:SetAttribute("Tweening", false) end
            end)
        end
    end
end

-- Sem loop próprio: o BringEnemy só é chamado de dentro do killMob/killMobInline/
-- farm() (ou seja, só quando tá realmente matando mob). Assim ele não fica puxando
-- nada durante a etapa de pegar missão ou viajar até o boss/level.

task.spawn(function()
    while task.wait(0.1) do
        if _G["AutoFarm_Level"] then
            pcall(farm)
        end
    end
end)

local function getQuestGui()
    local main = plr.PlayerGui:FindFirstChild("Main")
    return main and main:FindFirstChild("Quest")
end

task.spawn(function()
    while task.wait(0.5) do
        if not _G["AutoFarm_Bone"] then continue end

        pcall(function()
            if not getRoot() then return end

            local questGui = getQuestGui()
            local hasQuest = questGui and questGui.Visible

            if _G["AcceptQuestB"] and not hasQuest then
                repeat
                    task.wait(0.5)
                    if not _G["AutoFarm_Bone"] then return end
                    local r = getRoot()
                    if not r then return end
                    _tp(boneNPC)
                until not _G["AutoFarm_Bone"]
                    or (boneNPC.Position - (getRoot() and getRoot().Position or boneNPC.Position)).Magnitude <= 50
                if not _G["AutoFarm_Bone"] then return end
                RS.Remotes.CommF_:InvokeServer(table.unpack(boneQuests[math.random(1, #boneQuests)]))
                task.wait(1)
                return
            end

            local enemy = findBoneEnemy()
            if enemy then
                local hum = enemy:FindFirstChild("Humanoid")
                local hrp = enemy:FindFirstChild("HumanoidRootPart")
                if not hum or not hrp then return end
                local anim = hum:FindFirstChild("Animator")
                if anim then anim:Destroy() end

                repeat
                    task.wait()
                    if not _G["AutoFarm_Bone"] then break end
                    local r = getRoot()
                    if not r then break end
                    if not enemy.Parent or hum.Health <= 0 then break end
                    local qg = getQuestGui()
                    if qg and not qg.Visible then break end
                    if (hrp.Position - r.Position).Magnitude > 20 then
                        _tp(hrp.CFrame * CFrame.new(0, 17, 0))
                    end
                    eq(getWeapon())
                until not _G["AutoFarm_Bone"]
                    or not enemy.Parent
                    or hum.Health <= 0
                if _G["AutoFarm_Bone"] and (not enemy.Parent or hum.Health <= 0) then
                    boneKillCount = boneKillCount + 1
                    if boneKillCount >= 6 then
                        boneKillCount = 0
                        boneKillIdx = (boneKillIdx % #boneKillOrder) + 1
                    end
                end
            else
                _tp(boneIdle)
                task.wait(2)
            end
        end)
    end
end)

local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local Workspace           = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Modules     = ReplicatedStorage:WaitForChild("Modules")
local Net         = Modules:WaitForChild("Net")

local RegisterAttack  = Net:WaitForChild("RE/RegisterAttack")
local RegisterHit     = Net:WaitForChild("RE/RegisterHit")
local ShootGunEvent   = Net:WaitForChild("RE/ShootGunEvent")
local ValidatorRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Validator2")

local CachedRemote, CachedRemoteId = nil, nil
local RemoteFolders = {
    ReplicatedStorage:WaitForChild("Util"),
    ReplicatedStorage:WaitForChild("Common"),
    ReplicatedStorage:WaitForChild("Remotes"),
    ReplicatedStorage:WaitForChild("Assets"),
    ReplicatedStorage:WaitForChild("FX"),
}
for _, folder in ipairs(RemoteFolders) do
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("RemoteEvent") and obj:GetAttribute("Id") then
            CachedRemote = obj; CachedRemoteId = obj:GetAttribute("Id")
        end
    end
    folder.ChildAdded:Connect(function(child)
        if child:IsA("RemoteEvent") and child:GetAttribute("Id") then
            CachedRemote = child; CachedRemoteId = child:GetAttribute("Id")
        end
    end)
end

local FastAttack = {}
FastAttack.__index = FastAttack

function FastAttack.new()
    local self = setmetatable({}, FastAttack)
    self.LastAttack = 0; self.Combo = 0; self.LastCombo = 0; self.LastShoot = 0
    self.CurrentTargetPart = nil; self.Connections = {}; self.SwappingTools = false
    pcall(function()
        self.CombatFlags   = require(Modules.Flags).COMBAT_REMOTE_THREAD
        self.ShootFunction = getupvalue(require(ReplicatedStorage.Controllers.CombatController).Attack, 9)
        local PS = LocalPlayer.PlayerScripts:FindFirstChildOfClass("LocalScript")
        if PS and getsenv then self.SendHitsToServer = getsenv(PS)._G.SendHitsToServer end
    end)
    return self
end

function FastAttack:IsAlive(Character)
    local H = Character and Character:FindFirstChild("Humanoid")
    return H and H.Health > 0
end

function FastAttack:IsValidTool(Tool)
    if not Tool then return false end
    return table.find({"Melee","Sword","Gun","Blox Fruit"}, Tool.ToolTip)
end

function FastAttack:IsStunned(Character, Humanoid, ToolType)
    local Stun = Character:FindFirstChild("Stun")
    local Busy = Character:FindFirstChild("Busy")
    if Humanoid.Sit and (ToolType == "Sword" or ToolType == "Melee") then return true end
    if Stun and Stun.Value > 0 then return true end
    if Busy and Busy.Value then return true end
    return false
end

function FastAttack:GetCombo()
    if (tick() - self.LastCombo) > Config.ComboReset then self.Combo = 0 end
    self.Combo += 1
    if self.Combo > Config.MaxCombo then self.Combo = 1 end
    self.LastCombo = tick()
    return self.Combo
end

function FastAttack:GetTargets(Character, Distance)
    local Targets = {}
    local CharPos = Character:GetPivot().Position
    local function Scan(Folder)
        for _, Enemy in ipairs(Folder:GetChildren()) do
            if Enemy ~= Character and self:IsAlive(Enemy) then
                local Root = Enemy:FindFirstChild("HumanoidRootPart")
                if Root and (CharPos - Root.Position).Magnitude <= Distance then
                    for _, PN in ipairs(Config.HitboxParts) do
                        local Part = Enemy:FindFirstChild(PN)
                        if Part and Part:IsA("BasePart") then
                            table.insert(Targets, {Enemy, Part})
                            if not self.CurrentTargetPart then self.CurrentTargetPart = Part end
                        end
                    end
                end
            end
        end
    end
    if Config.AttackMobs    then pcall(Scan, Workspace.Enemies)    end
    if Config.AttackPlayers then
        local chars = Workspace:FindFirstChild("Characters")
        if chars then pcall(Scan, chars) end
    end
    return Targets
end

function FastAttack:GetClosestEnemy(Character, Distance)
    local ClosestPart, ClosestMag = nil, math.huge
    for _, Data in ipairs(self:GetTargets(Character, Distance)) do
        local Mag = (Character:GetPivot().Position - Data[2].Position).Magnitude
        if Mag < ClosestMag then ClosestMag = Mag; ClosestPart = Data[2] end
    end
    return ClosestPart
end

function FastAttack:GetValidator()
    local v1=getupvalue(self.ShootFunction,15) local v2=getupvalue(self.ShootFunction,13)
    local v3=getupvalue(self.ShootFunction,16) local v4=getupvalue(self.ShootFunction,17)
    local v5=getupvalue(self.ShootFunction,14) local v6=getupvalue(self.ShootFunction,12)
    local counter=getupvalue(self.ShootFunction,18)
    local temp=v6*v2
    local result=(v5*v2+v6*v1)%v3
    result=(result*v3+temp)%v4
    v5=math.floor(result/v3); v6=result-(v5*v3); counter+=1
    setupvalue(self.ShootFunction,14,v5) setupvalue(self.ShootFunction,12,v6)
    setupvalue(self.ShootFunction,18,counter)
    return math.floor(result/v4*16777215), counter
end

function FastAttack:Shoot(TargetPosition)
    if not self.ShootFunction then return end
    local Character = LocalPlayer.Character
    if not self:IsAlive(Character) then return end
    local Tool = Character:FindFirstChildOfClass("Tool")
    if not Tool or Tool.ToolTip ~= "Gun" then return end
    local Cooldown = Tool:FindFirstChild("Cooldown")
    if (tick() - self.LastShoot) < (Cooldown and Cooldown.Value or 0.3) then return end
    Tool:SetAttribute("LocalTotalShots", (Tool:GetAttribute("LocalTotalShots") or 0) + 1)
    ValidatorRemote:FireServer(self:GetValidator())
    ShootGunEvent:FireServer(TargetPosition)
    self.LastShoot = tick()
end

function FastAttack:AttackMelee(Character)
    self.CurrentTargetPart = nil
    local Targets = self:GetTargets(Character, Config.AttackDistance)
    if self.CurrentTargetPart then
        RegisterAttack:FireServer(0)
        if self.CombatFlags and self.SendHitsToServer then
            self.SendHitsToServer(self.CurrentTargetPart, Targets)
        else
            RegisterHit:FireServer(self.CurrentTargetPart, Targets)
        end
        if CachedRemote and CachedRemoteId then
            pcall(function()
                cloneref(CachedRemote):FireServer(
                    string.gsub("RE/RegisterHit", ".", function(cb)
                        return string.char(bit32.bxor(string.byte(cb),
                            math.floor(Workspace:GetServerTimeNow()/10%10)+1))
                    end),
                    bit32.bxor(CachedRemoteId+909090, Net.seed:InvokeServer()*2),
                    self.CurrentTargetPart, Targets
                )
            end)
        end
    end
end

function FastAttack:AttackFruit(Character, Tool, Combo)
    local Targets = self:GetTargets(Character, Config.AttackDistance)
    if not Targets[1] then return end
    local charPos   = Character:GetPivot().Position
    local targetPos = Targets[1][2].Position
    local flat = Vector3.new(targetPos.X - charPos.X, 0, targetPos.Z - charPos.Z)
    local dir = flat.Magnitude > 0.001 and flat.Unit or Character:GetPivot().LookVector
    Tool.LeftClickRemote:FireServer(dir, Combo)
end

function FastAttack:FindFruitTool()
    for _, v in pairs(LocalPlayer.Backpack:GetChildren()) do
        if v:IsA("Tool") and v.ToolTip == "Blox Fruit" then return v end
    end
    local c = LocalPlayer.Character
    if c then
        for _, v in pairs(c:GetChildren()) do
            if v:IsA("Tool") and v.ToolTip == "Blox Fruit" then return v end
        end
    end
end

function FastAttack:Attack()
    if not Config.AutoClick and not fastAttackEnabled and not doubleAttackEnabled then return end
    if (tick() - self.LastAttack) < Config.AttackCooldown then return end
    local Character = LocalPlayer.Character
    if not Character or not self:IsAlive(Character) then return end
    local Humanoid = Character:FindFirstChild("Humanoid")
    local Tool     = Character:FindFirstChildOfClass("Tool")
    if not Humanoid or not self:IsValidTool(Tool) then return end
    local ToolType = Tool.ToolTip
    if self:IsStunned(Character, Humanoid, ToolType) then return end
    local Combo = self:GetCombo()
    self.LastAttack = tick()

    if ToolType == "Gun" then
        local Closest = self:GetClosestEnemy(Character, 120)
        if Closest then self:Shoot(Closest.Position) end
        return
    end

    if doubleAttackEnabled then
        self:AttackMelee(Character)
        local fruitTool = self:FindFruitTool()
        if fruitTool then
            local lcr = fruitTool:FindFirstChild("LeftClickRemote", true)
            if lcr then
                local Targets = self:GetTargets(Character, Config.AttackDistance)
                if Targets[1] then
                    local charPos   = Character:GetPivot().Position
                    local targetPos = Targets[1][2].Position
                    local flat = Vector3.new(targetPos.X - charPos.X, 0, targetPos.Z - charPos.Z)
                    local dir = flat.Magnitude > 0.001 and flat.Unit or Character:GetPivot().LookVector
                    lcr:FireServer(dir, Combo)
                end
            end
        end
    elseif ToolType == "Blox Fruit" then
        if Tool:FindFirstChild("LeftClickRemote") then self:AttackFruit(Character, Tool, Combo) end
    else
        self:AttackMelee(Character)
    end
end

local AttackHandler = FastAttack.new()

table.insert(AttackHandler.Connections, RunService.Stepped:Connect(function()
    pcall(function() AttackHandler:Attack() end)
end))

for _, Object in pairs(getgc(true)) do
    if typeof(Object) == "function" and iscclosure(Object) then
        local FN = debug.getinfo(Object).name
        if FN == "Attack" or FN == "attack" or FN == "RegisterHit" then
            hookfunction(Object, function(...)
                AttackHandler:Attack()
                return Object(...)
            end)
        end
    end
end

local tyrantPos = Vector3.new(-16268.287, 152.616, 1390.773)
local tyrantMobsToKill = { "Sun-kissed Warrior", "Isle Champion", "Serpent Hunter", "Skull Slayer" }
local tyrantMobSpawns = {
    ["Sun-kissed Warrior"] = CFrame.new(-16347, 64, 984),
    ["Isle Champion"]      = CFrame.new(-16602.10156, 130.387344, 1087.24560),
    ["Serpent Hunter"]     = CFrame.new(-16679.4785, 176.7473, 1474.3995),
    ["Skull Slayer"]       = CFrame.new(-16759.5898, 71.2837, 1595.3399),
}
local tyrantSummonPositions = {
    CFrame.new(-16332.526367188, 158.07200622559, 1440.3249511719),
    CFrame.new(-16288.609375,    158.16700744629, 1470.3680419922),
    CFrame.new(-16245.412109375, 158.43699645996, 1463.3659667969),
    CFrame.new(-16212.46875,     158.16700744629, 1466.3439941406),
    CFrame.new(-16211.946289062, 158.07200622559, 1322.3979492188),
    CFrame.new(-16260.921875,    154.92100524902, 1323.6159667969),
    CFrame.new(-16297.059570312, 159.32299804688, 1317.2239990234),
    CFrame.new(-16335.096679688, 159.33399963379, 1324.8859863281)
}

local function checkEyes()
    local ok, islandModel = pcall(function()
        return workspace["Map"]["TikiOutpost"]["IslandModel"]
    end)
    if not ok or not islandModel then return 0, false end
    local chunks = islandModel:FindFirstChild("IslandChunks")
    local e      = chunks and chunks:FindFirstChild("E")
    local eyes   = {
        islandModel:FindFirstChild("Eye1"),
        islandModel:FindFirstChild("Eye2"),
        e and e:FindFirstChild("Eye3"),
        e and e:FindFirstChild("Eye4")
    }
    local count = 0
    for _, eye in ipairs(eyes) do
        if eye and eye.Transparency ~= 1 then count += 1 end
    end
    return count, count == 4
end

local function pressKey(key)
    local vim = game:GetService("VirtualInputManager")
    vim:SendKeyEvent(true, key, false, game)
    task.wait(0.05)
    vim:SendKeyEvent(false, key, false, game)
end

local function useWeaponSkills(tooltip, flagKey)
    local char = getChar()
    if not (char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0) then return end

    for _, t in pairs(char:GetChildren()) do
        if t:IsA("Tool") then t.Parent = plr.Backpack end
    end
    task.wait(0.05)
    for _, tool in pairs(plr.Backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.ToolTip == tooltip then
            tool.Parent = char
            task.wait(0.12)
            for _, key in ipairs({ "Z", "X", "C", "V", "F" }) do
                if not _G[flagKey or "FarmPhaBinh"] then break end
                pcall(function() pressKey(key) end)
                task.wait(0.12)
            end
            tool.Parent = plr.Backpack
            break
        end
    end
end

task.spawn(function()
    while task.wait(0.1) do
        if _G["FarmTyrant"] then
            pcall(function()
                local root = getRoot()
                if not root then return end
                if (root.Position - tyrantPos).Magnitude > 5 then
                    _tp(CFrame.new(tyrantPos))
                    repeat task.wait()
                    until not _G["FarmTyrant"]
                        or (getRoot() and (getRoot().Position - tyrantPos).Magnitude <= 5)
                end
                local tyrant = workspace.Enemies:FindFirstChild("Tyrant of the Skies")
                if tyrant and tyrant:FindFirstChild("Humanoid") and tyrant.Humanoid.Health > 0 then
                    repeat
                        if not _G["FarmTyrant"] then break end
                        killMob(tyrant, _G["FarmTyrant"])
                        task.wait()
                    until not _G["FarmTyrant"] or not tyrant.Parent or tyrant.Humanoid.Health <= 0
                    return
                end
                for _, mobName in ipairs(tyrantMobsToKill) do
                    if not _G["FarmTyrant"] then break end
                    for _, mob in pairs(workspace.Enemies:GetChildren()) do
                        if not _G["FarmTyrant"] then break end
                        if mob and mob.Name == mobName
                            and mob:FindFirstChild("HumanoidRootPart")
                            and mob:FindFirstChild("Humanoid")
                            and mob.Humanoid.Health > 0 then
                            repeat
                                if not _G["FarmTyrant"] then break end
                                pcall(function()
                                    if not mob:GetAttribute("Locked") then
                                        mob:SetAttribute("Locked", mob.HumanoidRootPart.CFrame)
                                    end
                                    local char = getChar()
                                    if not char then return end
                                    if not char:FindFirstChildOfClass("Tool") then
                                        local preferred = nil
                                        for _, t in pairs(plr.Backpack:GetChildren()) do
                                            if t:IsA("Tool") and t.ToolTip == ChooseWP then preferred = t; break end
                                        end
                                        local tool = preferred or plr.Backpack:FindFirstChildOfClass("Tool")
                                        if tool then tool.Parent = char end
                                    end
                                    local tool = char:FindFirstChildOfClass("Tool")
                                    if not tool then return end
                                    local hrp = mob:FindFirstChild("HumanoidRootPart")
                                    if not hrp then return end
                                    if tool.ToolTip == "Blox Fruit" or doubleAttackEnabled then
                                        _tp((hrp.CFrame * CFrame.new(0, 7, 0)) * CFrame.Angles(0, math.rad(90), 0))
                                    else
                                        _tp((hrp.CFrame * CFrame.new(0, 27, 0)) * CFrame.Angles(0, math.rad(180), 0))
                                    end
                                end)
                                task.wait()
                            until not _G["FarmTyrant"] or not mob.Parent or mob.Humanoid.Health <= 0
                        end
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        if _G["FarmPhaBinh"] then
            pcall(function()
                local char = getChar()
                local root = getRoot()
                if not (char and root and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0) then return end
                for _, cf in ipairs(tyrantSummonPositions) do
                    if not _G["FarmPhaBinh"] then break end
                    _tp(cf)
                    local arrived = false
                    local t = tick()
                    while tick() - t < 12 and not arrived and _G["FarmPhaBinh"] do
                        root = getRoot()
                        if not root then break end
                        if (root.Position - cf.Position).Magnitude <= 3 then
                            arrived = true
                            break
                        end
                        task.wait(0.1)
                    end
                    if _G["FarmPhaBinh"] and arrived then
                        useWeaponSkills("Melee")
                        useWeaponSkills("Sword")
                        useWeaponSkills("Gun")
                    end
                end
            end)
        end
    end
end)

local function killMobInline(mob, flagKey, orbit)
    local isNewTarget = not mob:GetAttribute("Locked")
    if isNewTarget then
        mob:SetAttribute("Locked", mob.HumanoidRootPart.CFrame)
    end
    PosMon = mob:GetAttribute("Locked").Position
    CurrentTarget = mob
    if BringEnemy then pcall(BringEnemy) end
    local char = getChar()
    if not char then return end
    local cur = char:FindFirstChildOfClass("Tool")
    if not cur or cur.ToolTip ~= ChooseWP then
        local preferred = nil
        for _, t in pairs(plr.Backpack:GetChildren()) do
            if t:IsA("Tool") and t.ToolTip == ChooseWP then preferred = t; break end
        end
        if preferred then
            if cur then cur.Parent = plr.Backpack end
            preferred.Parent = char
        elseif not cur then
            local any = plr.Backpack:FindFirstChildOfClass("Tool")
            if any then any.Parent = char end
        end
    end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    local hrp = mob:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if orbit then
        local angle = (tick() * 4) % (2 * math.pi)
        local radius = 25
        local bossPos = hrp.Position
        local targetPos = bossPos + Vector3.new(math.cos(angle) * radius, 15, math.sin(angle) * radius)
        _tp(CFrame.new(targetPos, bossPos + Vector3.new(0, 15, 0)))
    elseif isNewTarget then
        -- só na primeira vez: posiciona o player perto do mob; depois disso
        -- ele fica parado e o Bring traz o mob até ele
        if tool.ToolTip == "Blox Fruit" or doubleAttackEnabled then
            _tp((hrp.CFrame * CFrame.new(0, 7, 0)) * CFrame.Angles(0, math.rad(90), 0))
        else
            _tp((hrp.CFrame * CFrame.new(0, 27, 0)) * CFrame.Angles(0, math.rad(180), 0))
        end
    end
end

task.spawn(function()
    while task.wait(0.1) do
        if not _G["AutoFarm_Tyrant"] then continue end
        pcall(function()

            local tyrant = workspace.Enemies:FindFirstChild("Tyrant of the Skies")
            if tyrant and tyrant:FindFirstChild("Humanoid") and tyrant.Humanoid.Health > 0 then
                repeat
                    if not _G["AutoFarm_Tyrant"] then break end
                    pcall(killMobInline, tyrant, "AutoFarm_Tyrant", true)
                    task.wait()
                until not _G["AutoFarm_Tyrant"] or not tyrant.Parent or tyrant.Humanoid.Health <= 0
                return
            end

            if checkEyes() < 4 then
                for _, mobName in ipairs(tyrantMobsToKill) do
                    if not _G["AutoFarm_Tyrant"] or checkEyes() >= 4 then break end

                    local spawnCF = tyrantMobSpawns[mobName]
                    if spawnCF then
                        _tp(spawnCF)
                        local t0 = tick()
                        repeat task.wait(0.2)
                        until not _G["AutoFarm_Tyrant"] or not getRoot()
                            or (getRoot().Position - spawnCF.Position).Magnitude <= 30
                            or tick() - t0 > 15
                        task.wait(0.5)
                    end
                    for _, mob in pairs(workspace.Enemies:GetChildren()) do
                        if not _G["AutoFarm_Tyrant"] or checkEyes() >= 4 then break end
                        if mob.Name == mobName
                            and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0
                            and mob:FindFirstChild("HumanoidRootPart") then
                            repeat
                                if not _G["AutoFarm_Tyrant"] or checkEyes() >= 4 then break end
                                pcall(killMobInline, mob, "AutoFarm_Tyrant")
                                task.wait()
                            until not _G["AutoFarm_Tyrant"] or not mob.Parent
                                or mob.Humanoid.Health <= 0 or checkEyes() >= 4
                        end
                    end
                end
                return
            end

            repeat

                local guitar = nil
                for _, t in pairs(plr.Backpack:GetChildren()) do
                    if t:IsA("Tool") and t.Name == "Skull Guitar" then guitar = t; break end
                end
                if not guitar then
                    local char = getChar()
                    if char then
                        for _, t in pairs(char:GetChildren()) do
                            if t:IsA("Tool") and t.Name == "Skull Guitar" then guitar = t; break end
                        end
                    end
                end
                if guitar then
                    local char = getChar()
                    if char then
                        for _, t in pairs(char:GetChildren()) do
                            if t:IsA("Tool") then t.Parent = plr.Backpack end
                        end
                        task.wait(0.05)
                        guitar.Parent = char
                        task.wait(0.1)
                    end
                end
                for _, cf in ipairs(tyrantSummonPositions) do
                    if not _G["AutoFarm_Tyrant"] then break end
                    if workspace.Enemies:FindFirstChild("Tyrant of the Skies") then break end
                    _tp(cf)
                    local arrived = false
                    local t = tick()
                    while tick() - t < 12 and not arrived and _G["AutoFarm_Tyrant"] do
                        local root = getRoot()
                        if not root then break end
                        if (root.Position - cf.Position).Magnitude <= 3 then
                            arrived = true; break
                        end
                        task.wait(0.1)
                    end
                    if _G["AutoFarm_Tyrant"] and arrived then
                        if guitar then
                            local vim = game:GetService("VirtualInputManager")
                            for _ = 1, 5 do
                                if not _G["AutoFarm_Tyrant"] then break end
                                local ch = getChar()
                                if ch and not ch:FindFirstChild("Skull Guitar") then
                                    for _, t in pairs(ch:GetChildren()) do
                                        if t:IsA("Tool") then t.Parent = plr.Backpack end
                                    end
                                    task.wait(0.05)
                                    guitar.Parent = ch
                                    task.wait(0.05)
                                end
                                vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                                task.wait(0.05)
                                vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                                task.wait(0.3)
                            end
                        else
                            useWeaponSkills("Melee",      "AutoFarm_Tyrant")
                            useWeaponSkills("Sword",      "AutoFarm_Tyrant")
                            useWeaponSkills("Blox Fruit", "AutoFarm_Tyrant")
                            useWeaponSkills("Gun",        "AutoFarm_Tyrant")
                        end
                    end
                end
            until not _G["AutoFarm_Tyrant"] or workspace.Enemies:FindFirstChild("Tyrant of the Skies")

            if not _G["AutoFarm_Tyrant"] then return end
            local root = getRoot()
            if root and (root.Position - tyrantPos).Magnitude > 5 then
                _tp(CFrame.new(tyrantPos))
                local t2 = tick()
                repeat task.wait(); root = getRoot()
                until not _G["AutoFarm_Tyrant"] or not root
                    or (root.Position - tyrantPos).Magnitude <= 5
                    or tick() - t2 > 10
            end
            local tw = tick()
            repeat task.wait(0.5)
            until not _G["AutoFarm_Tyrant"]
                or workspace.Enemies:FindFirstChild("Tyrant of the Skies")
                or tick() - tw > 20
            local tyrantNew = workspace.Enemies:FindFirstChild("Tyrant of the Skies")
            if tyrantNew and tyrantNew:FindFirstChild("Humanoid") and tyrantNew.Humanoid.Health > 0 then
                repeat
                    if not _G["AutoFarm_Tyrant"] then break end
                    pcall(killMobInline, tyrantNew, "AutoFarm_Tyrant", true)
                    task.wait()
                until not _G["AutoFarm_Tyrant"] or not tyrantNew.Parent or tyrantNew.Humanoid.Health <= 0
            end
        end)
    end
end)

print("On Tropa")

local tyrantHopVisited       = {}
local TYRANT_HOP_FILE        = "midnight_tyrantvhop.json"
local _tyrantHopStartPending = false
local tyrantHopToggleRef     = nil
local _farmSetTyrantActive   = nil
local _farmSetTyrantStop     = nil

pcall(function()
    if isfile and isfile(TYRANT_HOP_FILE) then
        if readfile(TYRANT_HOP_FILE) == "1" then
            _tyrantHopStartPending = true
        end
        if writefile then writefile(TYRANT_HOP_FILE, "") end
    end
end)

local function tyrantServerIsGood()
    local ok, found = pcall(function()
        return workspace.Enemies:FindFirstChild("Tyrant of the Skies")
    end)
    if ok and found then return true end
    local eyeCount = 0
    pcall(function() eyeCount = checkEyes() end)
    return eyeCount >= 3
end

local function tyrantHopGetServers(cursor)
    local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    if cursor then url = url .. "&cursor=" .. cursor end
    local ok, resp = pcall(function() return game:HttpGet(url) end)
    if not ok then return nil end
    local ok2, data = pcall(function() return game:GetService("HttpService"):JSONDecode(resp) end)
    return ok2 and data or nil
end

local function tyrantHopSetQueue()
    local queue = queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
    if not queue then return end
    local src
    pcall(function() src = getscriptsource(script) end)
    if not (src and #src > 0) and isfile and isfile("midnighthubBFmain.lua") then
        src = readfile("midnighthubBFmain.lua")
    end
    if src and #src > 0 then
        pcall(function() if writefile then writefile(TYRANT_HOP_FILE, "1") end end)
        queue("repeat task.wait() until game:IsLoaded()\n" .. src)
    end
end

local function tyrantHopTeleport(serverId)
    tyrantHopSetQueue()
    pcall(function()
        game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", serverId)
    end)
end

local function tyrantHopDoHop()
    local cursor = nil
    for _ = 1, 5 do
        if not _G["TyrantHop"] then return end
        local data = tyrantHopGetServers(cursor)
        if not data or not data.data then break end
        table.sort(data.data, function(a, b) return (a.playing or 0) < (b.playing or 0) end)
        for _, server in ipairs(data.data) do
            if not _G["TyrantHop"] then return end
            local slots = (server.maxPlayers or 0) - (server.playing or 0)
            if slots >= 1 and server.id ~= game.JobId and not tyrantHopVisited[server.id] then
                tyrantHopVisited[server.id] = true
                tyrantHopTeleport(server.id)
                task.wait(12)
                return
            end
        end
        cursor = data.nextPageCursor
        if not cursor then break end
    end
    tyrantHopVisited = {}
end

task.spawn(function()
    local tyrantFarmActive = false
    local tyrantWasSeen    = false
    while task.wait(2) do
        if not _G["TyrantHop"] then
            if tyrantFarmActive then
                tyrantFarmActive = false
                tyrantWasSeen    = false
                pcall(function() if _farmSetTyrantStop then _farmSetTyrantStop() end end)
            end
            continue
        end
        pcall(function()
            if tyrantFarmActive then
                local tyrantAlive = false
                pcall(function()
                    tyrantAlive = workspace.Enemies:FindFirstChild("Tyrant of the Skies") ~= nil
                end)
                if tyrantAlive then
                    tyrantWasSeen = true
                elseif tyrantWasSeen then

                    tyrantFarmActive = false
                    tyrantWasSeen    = false
                    pcall(function() if _farmSetTyrantStop then _farmSetTyrantStop() end end)
                    tyrantHopDoHop()
                end
            else
                if tyrantServerIsGood() then
                    tyrantFarmActive = true
                    tyrantWasSeen    = false
                    if _farmSetTyrantActive then _farmSetTyrantActive() end
                else
                    tyrantHopDoHop()
                end
            end
        end)
    end
end)

if _tyrantHopStartPending then
    task.spawn(function()
        task.wait(4)
        _G["TyrantHop"] = true
        local t0 = tick()
        repeat task.wait(0.5) until tyrantHopToggleRef ~= nil or tick() - t0 > 15
        pcall(function() if tyrantHopToggleRef then tyrantHopToggleRef:Set(true) end end)
    end)
end

if getgenv().Library then getgenv().Library:Unload() end
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/nightmereki-lab/TESTS/refs/heads/main/Library.lua"
))()

local Window = Library:CreateWindow({
    Name               = "Midnight Hub",
    SubName            = "Auto Farm",
    WatermarkEnabled   = true,
    WatermarkText      = "Midnight Hub",
    SettingsTabEnabled = false
})

local StatusPage   = Window:Page({ Name = "Status",   Icon = "activity" })
local FarmPage     = Window:Page({ Name = "Farm",     Icon = "swords"   })
local SettingsPage = Window:Page({ Name = "Settings Farm", Icon = "settings" })
local MiscPage     = Window:Page({ Name = "Misc",     Icon = "shield"   })

do
    local BossesSection = StatusPage:Section({ Name = "Bosses" })
    local eH = BossesSection:AddLabel("Elite Hunter: Carregando...")
    local dK = BossesSection:AddLabel("Dough King: Carregando...")
    local rI = BossesSection:AddLabel("rip_indra True Form: Carregando...")
    local tS   = BossesSection:AddLabel("Tyrant of the Skies: Carregando...")
    local eyeS = BossesSection:AddLabel("Tyrant Eyes: Carregando...")

    local IlhasSection = StatusPage:Section({ Name = "Ilhas" })
    local fI = IlhasSection:AddLabel("Frozen Dimension: Carregando...")
    local pH = IlhasSection:AddLabel("Prehistoric Island: Carregando...")
    local mI = IlhasSection:AddLabel("Mirage Island: Carregando...")

    local MarSection = StatusPage:Section({ Name = "Mar" })
    local sS = MarSection:AddLabel("Sea Atual: Carregando...")
    local gT = MarSection:AddLabel("Hora: Carregando...")

    local ServerSection = StatusPage:Section({ Name = "Server Info" })
    local labelServerTime  = ServerSection:AddLabel("Server Uptime: --:--:--")
    local labelScriptTime  = ServerSection:AddLabel("Script Uptime: --:--:--")
    local labelPlayerCount = ServerSection:AddLabel("Players: --")

    local _scriptStartTime = tick()

    local function formatUptime(seconds)
        local s = math.floor(seconds)
        local h = math.floor(s / 3600)
        local m = math.floor((s % 3600) / 60)
        local sec = s % 60
        return string.format("%02d:%02d:%02d", h, m, sec)
    end

    task.spawn(function()
        while task.wait(1) do
            pcall(function()
                local ws = workspace
                local rs = RS

                local eHtxt = "Elite Hunter: " .. (
                    (rs:FindFirstChild("Diablo") or rs:FindFirstChild("Deandre") or rs:FindFirstChild("Urban")
                    or ws.Enemies:FindFirstChild("Diablo") or ws.Enemies:FindFirstChild("Deandre")
                    or ws.Enemies:FindFirstChild("Urban")) and "✅" or "❌")
                pcall(function() eH:SetText(eHtxt) end)

                local dKtxt = "Dough King: " .. (
                    (rs:FindFirstChild("Dough King") or ws.Enemies:FindFirstChild("Dough King")) and "✅" or "❌")
                pcall(function() dK:SetText(dKtxt) end)

                local rItxt = "rip_indra True Form: " .. (
                    (rs:FindFirstChild("rip_indra True Form") or ws.Enemies:FindFirstChild("rip_indra")) and "✅" or "❌")
                pcall(function() rI:SetText(rItxt) end)

                local tStxt = "Tyrant of the Skies: " .. (ws.Enemies:FindFirstChild("Tyrant of the Skies") and "✅" or "❌")
                pcall(function() tS:SetText(tStxt) end)

                local eyeCount, eyeReady = checkEyes()
                pcall(function() eyeS:SetText("Tyrant Eyes: " .. eyeCount .. "/4 " .. (eyeReady and "✅" or "❌")) end)

                local fItxt = "Frozen Dimension: " .. (ws._WorldOrigin.Locations:FindFirstChild("Frozen Dimension") and "✅" or "❌")
                pcall(function() fI:SetText(fItxt) end)

                local pHtxt = "Prehistoric Island: " .. (ws._WorldOrigin.Locations:FindFirstChild("Prehistoric Island") and "✅" or "❌")
                pcall(function() pH:SetText(pHtxt) end)

                local mItxt = "Mirage Island: " .. (ws._WorldOrigin.Locations:FindFirstChild("Mirage Island") and "✅" or "❌")
                pcall(function() mI:SetText(mItxt) end)

                local world = mundox[game.PlaceId]
                local sea = world == "World1" and "Mar 1" or world == "World2" and "Mar 2" or world == "World3" and "Mar 3" or "Desconhecido"
                pcall(function() sS:SetText("Você está no: " .. sea) end)

                local t = game:GetService("Lighting").ClockTime
                local h = math.floor(t)
                pcall(function() gT:SetText(string.format("Hora: %02d:%02d", h, math.floor((t-h)*60))) end)

                pcall(function()
                    local serverAge = workspace:GetServerTimeNow()
                    labelServerTime:SetText("Server Uptime: " .. formatUptime(serverAge))
                end)
                pcall(function()
                    labelScriptTime:SetText("Script Uptime: " .. formatUptime(tick() - _scriptStartTime))
                end)
                pcall(function()
                    local count = #game:GetService("Players"):GetPlayers()
                    labelPlayerCount:SetText("Players: " .. count)
                end)
            end)
        end
    end)
end

do
    local FarmSection     = FarmPage:Section({ Name = "Configuração" })
    local currentFarmMode = getConfig("Modo de Farm", "Auto Farm (Nível)")
    local farmIsActive    = false
    local farmToggleRef   = nil

    FarmSection:AddDropdown({
        Name = "Modo de Farm", Flag = "farm_mode",
        Items = { "Auto Farm (Nível)", "Bone Farm (Haunted Castle)", "Tyrant of Skyes" },
        Default = currentFarmMode,
        Callback = function(v)
            currentFarmMode = v
            setConfig("Modo de Farm", v)
            if farmIsActive then setFarmActive(true, v) end
        end
    })

    farmToggleRef = FarmSection:AddToggle({
        Name = "Farm", Flag = "farm_active", Default = getConfig("Farm", false),
        Callback = function(v)
            setConfig("Farm", v)
            farmIsActive = v
            setFarmActive(v, currentFarmMode)
        end
    })

    _farmSetTyrantActive = function()
        currentFarmMode = "Tyrant of Skyes"
        farmIsActive    = true
        setFarmActive(true, "Tyrant of Skyes")
    end

    _farmSetTyrantStop = function()
        farmIsActive = false
        setFarmActive(false, "Tyrant of Skyes")
    end

    FarmSection:AddToggle({
        Name = "Auto Quest (Bone Farm)", Flag = "accept_quest_bone", Default = getConfig("Auto Quest (Bone Farm)", false),
        Callback = function(v)
            setConfig("Auto Quest (Bone Farm)", v)
            _G["AcceptQuestB"] = v
        end
    })

    FarmSection:AddButton({
        Name = "Ir para Haunted Castle",
        Callback = function()
            local root = getRoot()
            if root then root.CFrame = boneIdle end
        end
    })
end

do
    local ChestSection = FarmPage:Section({ Name = "Chest Farm" })

    local _chestActive = false
    local _chestLoop   = nil

    local function farmChests()
        while _chestActive do
            pcall(function()
                local chestFolder = workspace:FindFirstChild("ChestModels")
                if not chestFolder then
                    task.wait(2)
                    return
                end

                local chests = chestFolder:GetChildren()
                if #chests == 0 then
                    task.wait(2)
                    return
                end

                for _, chest in pairs(chests) do
                    if not _chestActive then break end

                    local targetPart = chest:IsA("BasePart") and chest
                        or chest:FindFirstChildWhichIsA("BasePart")
                    if not targetPart then continue end

                    local root = getRoot()
                    if not root then break end

                    local dist = (root.Position - targetPart.Position).Magnitude
                    if dist > 3 then
                        local duration = math.max(dist / vel, 0.3)
                        local ti = TweenInfo.new(duration, Enum.EasingStyle.Linear)
                        local tw = TS:Create(root, ti, {
                            CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 3, 0))
                        })
                        tw:Play()
                        tw.Completed:Wait()
                    end

                    task.wait(0.15)
                end

                task.wait(1)
            end)
        end
    end

    ChestSection:AddToggle({
        Name = "Auto Farm Chest", Flag = "chest_farm_active", Default = getConfig("Auto Farm Chest", false),
        Callback = function(v)
            setConfig("Auto Farm Chest", v)
            _chestActive = v
            if v then
                Library:Notify({ Name = "Chest Farm", Content = "Auto Farm Chest ativado!", Time = 3 })
                _chestLoop = task.spawn(farmChests)
            else
                Library:Notify({ Name = "Chest Farm", Content = "Auto Farm Chest desativado.", Time = 2 })
                if _chestLoop then
                    task.cancel(_chestLoop)
                    _chestLoop = nil
                end
            end
        end
    })

    ChestSection:AddLabel("Caminho: workspace.ChestModels")
end

do
    local TyrantSection = FarmPage:Section({ Name = "Tyrant of the Skies" })

    TyrantSection:AddToggle({
        Name = "Auto Farm Boss", Flag = "farm_tyrant", Default = getConfig("Auto Farm Boss", false),
        Callback = function(v)
            setConfig("Auto Farm Boss", v)
            _G["FarmTyrant"] = v
        end
    })

    TyrantSection:AddToggle({
        Name = "Auto Summon Boss", Flag = "summon_tyrant", Default = getConfig("Auto Summon Boss", false),
        Callback = function(v)
            setConfig("Auto Summon Boss", v)
            _G["FarmPhaBinh"] = v
        end
    })

    tyrantHopToggleRef = TyrantSection:AddToggle({
        Name = "Tyrant of Skyes [Hop]", Flag = "tyrant_hop", Default = getConfig("Tyrant of Skyes [Hop]", false),
        Callback = function(v)
            setConfig("Tyrant of Skyes [Hop]", v)
            _G["TyrantHop"] = v
        end
    })
end

do
    local EliteQuestSection = FarmPage:Section({ Name = "Elite Quest" })

    local eliteMobNames = { "Diablo", "Urban", "Deandre" }

    local function findEliteQuestMob()
        for _, mobName in ipairs(eliteMobNames) do
            for _, e in pairs(workspace.Enemies:GetChildren()) do
                if string.find(e.Name, mobName) then
                    local hum = e:FindFirstChild("Humanoid")
                    if hum and hum.Health > 0 and e:FindFirstChild("HumanoidRootPart") then
                        return e
                    end
                end
            end
        end
    end

    local function eliteEquipWeapon()
        local char = getChar()
        local cur  = char and char:FindFirstChildOfClass("Tool")
        if cur and cur.ToolTip == ChooseWP then return end
        for _, t in pairs(plr.Backpack:GetChildren()) do
            if t:IsA("Tool") and t.ToolTip == ChooseWP then
                if cur then cur.Parent = plr.Backpack end
                t.Parent = char
                break
            end
        end
    end

    -- Local do NPC que dá a quest do Elite Hunter
    local eliteQuestGiverCF = CFrame.new(
        -5420.08447, 313.745392, -2825.41699,
        -0.950180948, 2.49574214e-07, -0.311698824,
        1.78921567e-07, 1, 2.55266741e-07,
        0.311698824, 1.86779943e-07, -0.950180948
    )

    -- Força visitar o NPC de quest primeiro, mesmo que já exista uma quest ativa
    -- (é resetado pra true toda vez que o toggle é ligado de novo).
    local eliteVisitedGiver = false

    task.spawn(function()
        while task.wait(0.15) do
            if _G["AutoEliteQuest"] then
                pcall(function()
                    -- O "st" liga o Stepped hook (applyMods/addBC) que já existe no hub:
                    -- ele cria um BodyVelocity que anula a gravidade/física do character.
                    -- Sem isso, o _tp até seta o CFrame, mas a física puxa de volta no
                    -- mesmo frame e parece que o personagem "não sai do lugar".
                    st = true

                    if not eliteVisitedGiver then
                        local root = getRoot()
                        if root and (root.Position - eliteQuestGiverCF.Position).Magnitude > 8 then
                            st = true
                            _tp(eliteQuestGiverCF)
                        else
                            eliteVisitedGiver = true
                        end
                        return
                    end

                    if plr.PlayerGui.Main.Quest.Visible == true then
                        local title = plr.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text
                        if string.find(title, "Diablo") or string.find(title, "Urban") or string.find(title, "Deandre") then
                            local mob = findEliteQuestMob()
                            if mob then
                                repeat
                                    if not _G["AutoEliteQuest"] then break end
                                    st = true
                                    eliteEquipWeapon()
                                    local hrp = mob:FindFirstChild("HumanoidRootPart")
                                    if hrp then
                                        _tp((hrp.CFrame * CFrame.new(0, 27, 0)) * CFrame.Angles(0, math.rad(180), 0))
                                    end
                                    task.wait()
                                until not _G["AutoEliteQuest"] or not mob.Parent
                                    or mob.Humanoid.Health <= 0
                                    or plr.PlayerGui.Main.Quest.Visible == false
                                releaseHoldIfIdle()
                            else
                                -- o mob ainda não carregou em workspace.Enemies; antes disso
                                -- ele existe na raiz do ReplicatedStorage. É preciso ir até lá
                                -- pra fazer ele carregar de verdade (não spawna sozinho).
                                local markerRoot = nil
                                for _, mobName in ipairs(eliteMobNames) do
                                    local marker = RS:FindFirstChild(mobName)
                                    if marker and marker:FindFirstChild("HumanoidRootPart") then
                                        markerRoot = marker.HumanoidRootPart
                                        break
                                    end
                                end
                                if markerRoot then
                                    repeat
                                        if not _G["AutoEliteQuest"] then break end
                                        st = true
                                        _tp(markerRoot.CFrame * CFrame.new(2, 20, 2))
                                        task.wait(0.1)
                                    until not _G["AutoEliteQuest"]
                                        or not markerRoot.Parent
                                        or findEliteQuestMob() ~= nil
                                        or (getRoot() and (getRoot().Position - markerRoot.Position).Magnitude <= 20)
                                    releaseHoldIfIdle()
                                end
                            end
                        end
                    else
                        if _G["AutoEliteQuest"] then
                            st = true
                            RS.Remotes.CommF_:InvokeServer("EliteHunter")
                        end
                    end
                end)
            end
        end
    end)

    EliteQuestSection:AddToggle({
        Name = "Auto Elite Quest", Flag = "auto_elite_quest", Default = getConfig("Auto Elite Quest", false),
        Callback = function(v)
            setConfig("Auto Elite Quest", v)
            _G["AutoEliteQuest"] = v
            if v then
                st = true
                -- só visita o NPC de novo se a quest AINDA NÃO estiver ativa
                local questActive = false
                pcall(function()
                    questActive = plr.PlayerGui.Main.Quest.Visible == true
                end)
                eliteVisitedGiver = questActive
            elseif not (_G["AutoFarm_Level"] or _G["AutoFarm_Bone"] or _G["AutoFarm_Tyrant"]
                or _G["FarmTyrant"] or _G["FarmPhaBinh"]) then
                st = false
                clearMods()
            end
        end
    })

    -- Elite Quest Hop: se o mob (Diablo/Urban/Deandre) não tiver em spawn nesse
    -- servidor, troca de servidor via Server Hop. Assim que trocar, verifica de
    -- novo se o mob tá em spawn (isso acontece automaticamente quando o script
    -- recarrega no novo servidor, já que o toggle fica salvo na config).
    task.spawn(function()
        while task.wait(1) do
            if _G["AutoEliteQuestHop"] then
                pcall(function()
                    local mob = findEliteQuestMob()
                    local markerExists = false
                    if not mob then
                        for _, mobName in ipairs(eliteMobNames) do
                            if RS:FindFirstChild(mobName) then
                                markerExists = true
                                break
                            end
                        end
                    end
                    if mob or markerExists then
                        -- mob disponível (já em spawn ou pelo menos carregável): deixa o
                        -- Auto Elite Quest normal cuidar
                        _G["AutoEliteQuest"] = true
                    else
                        -- sem mob disponível de jeito nenhum nesse servidor: troca de servidor
                        _G["AutoEliteQuest"] = false
                        if ServerHop then
                            task.spawn(ServerHop)
                            task.wait(10)
                        end
                    end
                end)
            end
        end
    end)

    EliteQuestSection:AddToggle({
        Name = "Elite Quest Hop", Flag = "elite_quest_hop", Default = getConfig("Elite Quest Hop", false),
        Callback = function(v)
            setConfig("Elite Quest Hop", v)
            _G["AutoEliteQuestHop"] = v
            if not v then
                _G["AutoEliteQuest"] = false
            end
        end
    })
end

do
    local RaidSection = FarmPage:Section({ Name = "Pirate Raid" })

    local raidTargetCF = CFrame.new(
        -5496.17432, 313.768921, -2841.53027,
        0.924894512, 7.37058015e-09, 0.380223751,
        3.5881019e-08, 1, -1.06665446e-07,
        -0.380223751, 1.12297109e-07, 0.924894512
    )
    local raidCheckCF = CFrame.new(-5539.3115234375, 313.80053710938, -2972.3723144531)

    local raidEnemyList = {
        "Galley Pirate", "Galley Captain", "Raider", "Mercenary", "Vampire",
        "Zombie", "Snow Trooper", "Winter Warrior", "Lab Subordinate",
        "Horned Warrior", "Magma Ninja", "Lava Pirate", "Ship Deckhand",
        "Ship Engineer", "Ship Steward", "Ship Officer", "Arctic Warrior",
        "Snow Lurker", "Sea Soldier", "Water Fighter",
    }

    task.spawn(function()
        while task.wait(0.15) do
            if _G["AutoPirateRaid"] then
                pcall(function()
                    st = true
                    local root = getRoot()
                    if not root then return end

                    if (raidCheckCF.Position - root.Position).Magnitude <= 500 then
                        -- já tá na área do raid: procura os mobs em workspace.Enemies
                        -- e fica em cima de cada um; o auto attack cuida do dano.
                        for _, e in pairs(workspace.Enemies:GetChildren()) do
                            if e:FindFirstChild("HumanoidRootPart") and e:FindFirstChild("Humanoid")
                                and e.Humanoid.Health > 0
                                and (e.HumanoidRootPart.Position - root.Position).Magnitude <= 2000 then
                                repeat
                                    if not _G["AutoPirateRaid"] then break end
                                    st = true
                                    local char = getChar()
                                    local cur  = char and char:FindFirstChildOfClass("Tool")
                                    if not cur or cur.ToolTip ~= ChooseWP then
                                        for _, t in pairs(plr.Backpack:GetChildren()) do
                                            if t:IsA("Tool") and t.ToolTip == ChooseWP then
                                                if cur then cur.Parent = plr.Backpack end
                                                t.Parent = char
                                                break
                                            end
                                        end
                                    end
                                    _tp((e.HumanoidRootPart.CFrame * CFrame.new(0, 27, 0)) * CFrame.Angles(0, math.rad(180), 0))
                                    task.wait()
                                until not _G["AutoPirateRaid"] or not e.Parent
                                    or e.Humanoid.Health <= 0
                                    or not workspace.Enemies:FindFirstChild(e.Name)
                                releaseHoldIfIdle()
                            end
                        end
                    else
                        -- ainda longe da área: tweena até o CFrame do raid pra fazer
                        -- os mobs carregarem de verdade em workspace.Enemies.
                        for _, enemyName in ipairs(raidEnemyList) do
                            if RS:FindFirstChild(enemyName) then
                                st = true
                                _tp(raidTargetCF)
                                break
                            end
                        end
                    end
                end)
            end
        end
    end)

    RaidSection:AddToggle({
        Name = "Auto Pirate Raid", Flag = "auto_pirate_raid", Default = getConfig("Auto Pirate Raid", false),
        Callback = function(v)
            setConfig("Auto Pirate Raid", v)
            _G["AutoPirateRaid"] = v
            if v then
                st = true
            elseif not (_G["AutoFarm_Level"] or _G["AutoFarm_Bone"] or _G["AutoFarm_Tyrant"]
                or _G["FarmTyrant"] or _G["FarmPhaBinh"] or _G["AutoEliteQuest"]) then
                st = false
                clearMods()
            end
        end
    })
end

do
    local WeaponSection = SettingsPage:Section({ Name = "Arma & Velocidade" })

    ChooseWP = getConfig("Tipo de Arma", ChooseWP)

    local weaponDropdownRef = WeaponSection:AddDropdown({
        Name = "Tipo de Arma", Flag = "weapon_select",
        Items = { "Melee", "Sword", "Blox Fruit", "Gun" },
        Default = ChooseWP,
        Callback = function(v)
            setConfig("Tipo de Arma", v)
            ChooseWP = v
        end
    })
    pcall(function() weaponDropdownRef:Set(ChooseWP) end)

    WeaponSection:AddSlider({
        Name = "Velocidade do Tween", Flag = "tween_vel",
        Min = 50, Max = 1000, Default = getConfig("Velocidade do Tween", 300), Suffix = " st/s",
        Callback = function(v)
            setConfig("Velocidade do Tween", v)
            vel = v; velocidadeConfig = v
        end
    })
    vel = getConfig("Velocidade do Tween", vel)
    velocidadeConfig = vel

    local BringSection = SettingsPage:Section({ Name = "Bring (Puxar Inimigos)" })

    BringSection:AddSlider({
        Name = "Quantidade de Bring (⚠️ RISK )", Flag = "bring_count",
        Min = 0, Max = 5, Default = getConfig("Quantidade de Bring (⚠️ RISK )", 2), Suffix = " mobs",
        Callback = function(v)
            setConfig("Quantidade de Bring (⚠️ RISK )", v)
            bringCount = v
        end
    })
    bringCount = getConfig("Quantidade de Bring (⚠️ RISK )", bringCount)

    local HakiSection = SettingsPage:Section({ Name = "Haki" })

    HakiSection:AddToggle({
        Name = "Auto Haki Armamento", Flag = "auto_buso", Default = getConfig("Auto Haki Armamento", true),
        Callback = function(v)
            setConfig("Auto Haki Armamento", v)
            Boud = v
        end
    })
    Boud = getConfig("Auto Haki Armamento", Boud)

    HakiSection:AddToggle({
        Name = "Auto Spawn Point", Flag = "auto_spawn_pt", Default = getConfig("Auto Spawn Point", false),
        Callback = function(v)
            setConfig("Auto Spawn Point", v)
            if v then pcall(function() RS.Remotes.CommF_:InvokeServer("SetSpawnPoint") end) end
        end
    })

    local FastAttackSection = SettingsPage:Section({ Name = "Fast Attack" })

    local fastToggle, doubleToggle

    fastToggle = FastAttackSection:AddToggle({
        Name = "Fast Attack", Flag = "fast_attack_manual", Default = getConfig("Fast Attack", true),
        Callback = function(v)
            setConfig("Fast Attack", v)
            fastAttackEnabled = v
            if v then
                doubleAttackEnabled = false
                setConfig("Double Click (Fruta + Melee)", false)
                if doubleToggle then pcall(function() doubleToggle:Set(false) end) end
            end
        end
    })
    fastAttackEnabled = getConfig("Fast Attack", true)

    doubleToggle = FastAttackSection:AddToggle({
        Name = "Double Click (Fruta + Melee)", Flag = "double_attack", Default = getConfig("Double Click (Fruta + Melee)", false),
        Callback = function(v)
            setConfig("Double Click (Fruta + Melee)", v)
            doubleAttackEnabled = v
            if v then
                fastAttackEnabled = false
                setConfig("Fast Attack", false)
                if fastToggle then pcall(function() fastToggle:Set(false) end) end
            end
        end
    })
    doubleAttackEnabled = getConfig("Double Click (Fruta + Melee)", false)

    local StatsSection = SettingsPage:Section({ Name = "Status Points" })

    StatsSection:AddSlider({
        Name = "Quantidade por upgrade", Flag = "stat_amount",
        Min = 1, Max = 1000, Default = getConfig("Quantidade por upgrade", 10),
        Callback = function(v)
            setConfig("Quantidade por upgrade", v)
            pSats = v
        end
    })
    pSats = getConfig("Quantidade por upgrade", pSats)

    StatsSection:AddToggle({
        Name = "Auto Melee", Flag = "auto_melee", Default = getConfig("Auto Melee", false),
        Callback = function(v)
            setConfig("Auto Melee", v)
            _G["Auto_Melee"] = v
        end
    })

    StatsSection:AddToggle({
        Name = "Auto Sword", Flag = "auto_sword", Default = getConfig("Auto Sword", false),
        Callback = function(v)
            setConfig("Auto Sword", v)
            _G["Auto_Sword"] = v
        end
    })

    StatsSection:AddToggle({
        Name = "Auto Gun", Flag = "auto_gun", Default = getConfig("Auto Gun", false),
        Callback = function(v)
            setConfig("Auto Gun", v)
            _G["Auto_Gun"] = v
        end
    })

    StatsSection:AddToggle({
        Name = "Auto Blox Fruit", Flag = "auto_blox_fruit", Default = getConfig("Auto Blox Fruit", false),
        Callback = function(v)
            setConfig("Auto Blox Fruit", v)
            _G["Auto_DevilFruit"] = v
        end
    })

    StatsSection:AddToggle({
        Name = "Auto Defense", Flag = "auto_defense", Default = getConfig("Auto Defense", false),
        Callback = function(v)
            setConfig("Auto Defense", v)
            _G["Auto_Defense"] = v
        end
    })
end

do
    local antiLagAtivo = false
    local conexoes     = {}
    local loopAntiLag  = nil
    local L2 = game:GetService("Lighting")
    local W2 = game:GetService("Workspace")
    local P2 = game:GetService("Players")
    local R2 = game:GetService("RunService")

    local function remAnim(obj)
        if obj:IsA("Humanoid") then
            pcall(function()
                for _, tr in pairs(obj:GetPlayingAnimationTracks()) do
                    pcall(function() tr:Stop(); tr:Destroy() end)
                end
            end)
        end
        if obj:IsA("AnimationController") then
            pcall(function()
                for _, tr in pairs(obj:GetPlayingAnimationTracks()) do tr:Stop(); tr:Destroy() end
                obj:Destroy()
            end)
        end
        if obj:IsA("AnimationTrack") or obj:IsA("Animation") then
            pcall(function() obj:Destroy() end)
        end
    end

    local function remTex(obj)
        pcall(function()
            if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                obj.Material = Enum.Material.Plastic; obj.Reflectance = 0
                if obj:IsA("MeshPart") then obj.TextureID = "" end
            end
            if obj:IsA("Decal") or obj:IsA("Texture") then obj:Destroy() end
            if obj:IsA("SpecialMesh") and obj.MeshType ~= Enum.MeshType.Head then
                obj.TextureId = ""; obj.MeshId = ""
            end
            if obj:IsA("SurfaceAppearance") then obj:Destroy() end
        end)
    end

    local function limpar(obj)
        pcall(function()
            remAnim(obj); remTex(obj)
            if obj:IsA("BasePart") then obj.CastShadow = false end
        end)
    end

    local function ativarAntiLag()
        if antiLagAtivo then return end
        antiLagAtivo = true
        for _, e in pairs(L2:GetChildren()) do
            if e:IsA("PostEffect") or e:IsA("Sky") or e:IsA("Atmosphere") then e:Destroy() end
        end
        L2.GlobalShadows = false; L2.FogEnd = 9e9; L2.Brightness = 1; L2.ClockTime = 14
        for _, i in pairs(W2:GetDescendants()) do limpar(i) end
        local c1 = W2.DescendantAdded:Connect(function(n) if antiLagAtivo then task.wait(); limpar(n) end end)
        local c2 = R2.Stepped:Connect(function()
            if not antiLagAtivo then return end
            for _, jp in pairs(P2:GetPlayers()) do
                if jp.Character and jp.Character:FindFirstChild("Humanoid") then
                    for _, tr in pairs(jp.Character.Humanoid:GetPlayingAnimationTracks()) do
                        pcall(function() tr:Stop(); tr:Destroy() end)
                    end
                end
            end
        end)
        table.insert(conexoes, c1); table.insert(conexoes, c2)
        loopAntiLag = task.spawn(function()
            while antiLagAtivo do
                task.wait(3)
                for _, i in pairs(W2:GetDescendants()) do pcall(function() remTex(i) end) end
            end
        end)
    end

    local function desativarAntiLag()
        if not antiLagAtivo then return end
        antiLagAtivo = false
        for _, c in pairs(conexoes) do pcall(function() c:Disconnect() end) end
        conexoes = {}
        if loopAntiLag then task.cancel(loopAntiLag); loopAntiLag = nil end
    end

    local MiscSection = MiscPage:Section({ Name = "Performance" })

    MiscSection:AddToggle({
        Name = "Anti Lag / Mobile", Flag = "anti_lag", Default = getConfig("Anti Lag / Mobile", false),
        Callback = function(v)
            setConfig("Anti Lag / Mobile", v)
            if v then ativarAntiLag() else desativarAntiLag() end
        end
    })

    -- Link raw do script (GitHub, etc.) usado pra recarregar o hub sozinho.
    -- Troque pelo link real do seu script hospedado.
    local AUTO_EXEC_URL = "https://raw.githubusercontent.com/Dev-pocoyoJS/MidNightHub/main/midnighthubBF.lua"

    MiscSection:AddToggle({
        Name = "Auto Execute", Flag = "auto_execute", Default = getConfig("Auto Execute", false),
        Callback = function(v)
            setConfig("Auto Execute", v)
            pcall(function()
                if not queue_on_teleport then
                    Library:Notify({
                        Name = "Auto Execute",
                        Content = "Seu executor não suporta queue_on_teleport.",
                        Time = 4
                    })
                    return
                end
                if v then
                    queue_on_teleport(([[loadstring(game:HttpGet("%s"))()]]):format(AUTO_EXEC_URL))
                    Library:Notify({
                        Name = "Auto Execute",
                        Content = "Ativado! Script recarrega sozinho ao trocar de servidor.",
                        Time = 4
                    })
                else
                    queue_on_teleport("")
                end
            end)
        end
    })

    if getConfig("Auto Execute", false) then
        pcall(function()
            if queue_on_teleport then
                queue_on_teleport(([[loadstring(game:HttpGet("%s"))()]]):format(AUTO_EXEC_URL))
            end
        end)
    end
end

do

    local _miscScreenGui = Instance.new("ScreenGui")
    _miscScreenGui.Name = "MidnightScreenFX"
    _miscScreenGui.IgnoreGuiInset = true
    _miscScreenGui.ResetOnSpawn = false
    _miscScreenGui.DisplayOrder = 999999
    _miscScreenGui.Parent = plr:WaitForChild("PlayerGui")

    local _miscFrame = Instance.new("Frame")
    _miscFrame.Size = UDim2.new(1, 0, 1, 0)
    _miscFrame.Position = UDim2.new(0, 0, 0, 0)
    _miscFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    _miscFrame.BackgroundTransparency = 0
    _miscFrame.BorderSizePixel = 0
    _miscFrame.Visible = false
    _miscFrame.Parent = _miscScreenGui

    local VisualSection = MiscPage:Section({ Name = "Visual" })

    VisualSection:AddToggle({
        Name = "Black Screen", Flag = "misc_black_screen", Default = false,
        Callback = function(v)
            if v then
                _miscFrame.Visible = true
                _miscFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            else
                _miscFrame.Visible = false
            end
        end
    })

    VisualSection:AddToggle({
        Name = "White Screen", Flag = "misc_white_screen", Default = getConfig("White Screen", false),
        Callback = function(v)
            setConfig("White Screen", v)
            if v then
                _miscFrame.Visible = true
                _miscFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            else
                _miscFrame.Visible = false
            end
        end
    })

    VisualSection:AddButton({
        Name = "Fullbright",
        Callback = function()
            local L = game:GetService("Lighting")
            L.Ambient = Color3.new(1, 1, 1)
            L.Brightness = 5
            L.FogEnd = 1e9
            Library:Notify({ Name = "Fullbright", Content = "Fullbright ativado!", Time = 3 })
        end
    })

    VisualSection:AddButton({
        Name = "Remove Fog",
        Callback = function()
            local L = game:GetService("Lighting")
            if L:FindFirstChild("LightingLayers") then L.LightingLayers:Destroy() end
            if L:FindFirstChild("SeaTerrorCC") then L.SeaTerrorCC:Destroy() end
            if L:FindFirstChild("FantasySky") then L.FantasySky:Destroy() end
            L.FogEnd = 1e9
            Library:Notify({ Name = "Remove Fog", Content = "Fog removida!", Time = 3 })
        end
    })

    local UtilSection = MiscPage:Section({ Name = "Utility" })

    UtilSection:AddToggle({
        Name = "No Clip", Flag = "misc_noclip", Default = getConfig("No Clip", false),
        Callback = function(v)
            setConfig("No Clip", v)
            _G._miscNoClip = v
            if v then
                task.spawn(function()
                    while _G._miscNoClip do
                        pcall(function()
                            local char = plr.Character
                            if char then
                                for _, p in pairs(char:GetDescendants()) do
                                    if p:IsA("BasePart") then p.CanCollide = false end
                                end
                            end
                        end)
                        task.wait(0.1)
                    end
                end)
            end
        end
    })

    UtilSection:AddToggle({
        Name = "Walk on Water", Flag = "misc_walk_water", Default = getConfig("Walk on Water", false),
        Callback = function(v)
            setConfig("Walk on Water", v)
            pcall(function()
                local e = game:GetService("Workspace").Map["WaterBase-Plane"]
                if v then
                    e.Size = Vector3.new(1000, 112, 1000)
                else
                    e.Size = Vector3.new(1000, 80, 1000)
                end
            end)
        end
    })

    UtilSection:AddToggle({
        Name = "Disable Notifications", Flag = "misc_disable_notif", Default = getConfig("Disable Notifications", false),
        Callback = function(v)
            setConfig("Disable Notifications", v)
            _G._miscDisableNotif = v
        end
    })

    local _serverHopAtivo = false
    local visited = {}
    local _serverHopStatusLabel = nil

    local function setupQueue()

    end

    local function saveCache()

    end

    local function getServers(cursor)
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=25"
        if cursor then url = url .. "&cursor=" .. cursor end
        local ok, res = pcall(function()
            return game:HttpGet(url)
        end)
        if not ok or not res then return nil end
        local parsed = nil
        pcall(function() parsed = game:GetService("HttpService"):JSONDecode(res) end)
        return parsed
    end

    local function executarTeleporte(serverId)
        setupQueue()
        local ok, err = pcall(function()
            game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", serverId)
        end)
        if not ok then
            warn("[MIDNIGHTHUB] Teleporte falhou:", err)
        end
    end

    ServerHop = function()
        if _serverHopAtivo then return false end
        _serverHopAtivo = true

        if _serverHopStatusLabel then
            pcall(function() _serverHopStatusLabel:SetText("🔍 Buscando servidor...") end)
        end
        Library:Notify({ Name = "Server Hop", Content = "🔍 Buscando servidor...", Time = 3 })

        local cursor = nil

        for pagina = 1, 5 do
            local data = getServers(cursor)
            if not data or not data.data then break end

            table.sort(data.data, function(a, b)
                return (a.playing or 0) < (b.playing or 0)
            end)

            for _, server in ipairs(data.data) do
                local slots = (server.maxPlayers or 0) - (server.playing or 0)
                if slots >= 2 and server.id ~= game.JobId and not visited[server.id] then
                    visited[server.id] = true
                    saveCache()

                    Library:Notify({ Name = "Server Hop", Content = "🚀 Trocando servidor...", Time = 3 })

                    local jobAntes = game.JobId
                    executarTeleporte(server.id)
                    task.wait(8)

                    if game.JobId ~= jobAntes then
                        _serverHopAtivo = false
                        return true
                    end

                    warn("[MIDNIGHTHUB] Servidor cheio ou falhou, tentando próximo...")
                end
            end

            cursor = data.nextPageCursor
            if not cursor then break end
        end

        _serverHopAtivo = false
        Library:Notify({ Name = "Server Hop", Content = "❌ Sem servidores disponíveis", Time = 4 })
        return false
    end

    UtilSection:AddButton({
        Name = "Server Hop",
        Callback = function()
            if _serverHopAtivo then
                Library:Notify({ Name = "Server Hop", Content = "⏳ Já está em andamento...", Time = 2 })
                return
            end
            task.spawn(ServerHop)
        end
    })

    task.spawn(function()
        while task.wait(0.5) do
            pcall(function()
                if _G._miscDisableNotif then
                    game:GetService("ReplicatedStorage").Assets.GUI.DamageCounter.Enabled = false
                    plr.PlayerGui.Notifications.Enabled = false
                else
                    game:GetService("ReplicatedStorage").Assets.GUI.DamageCounter.Enabled = true
                    plr.PlayerGui.Notifications.Enabled = true
                end
            end)
        end
    end)
end

local _raid_isTeleporting = false

local function _raid_WaitHRP(q0)
    if not q0 then return end
    return q0.Character:WaitForChild("HumanoidRootPart", 9)
end

local function _raid_CheckNearestTeleporter(aI)
    local vcspos = aI.Position
    local minDist = math.huge
    local chosenTeleport = nil
    local y = game.PlaceId

    local TableLocations = {}

    if y == 2753915549 then
        TableLocations = {
            ["Sky3"] = Vector3.new(-7894, 5547, -380),
            ["Sky3Exit"] = Vector3.new(-4607, 874, -1667),
            ["UnderWater"] = Vector3.new(61163, 11, 1819),
            ["Underwater City"] = Vector3.new(61165.19140625, 0.18704631924629211, 1897.379150390625),
            ["Pirate Village"] = Vector3.new(-1242.4625244140625, 4.787059783935547, 3901.282958984375),
            ["UnderwaterExit"] = Vector3.new(4050, -1, -1814)
        }
    elseif y == 4442272183 then
        TableLocations = {
            ["Swan Mansion"] = Vector3.new(-390, 332, 673),
            ["Swan Room"] = Vector3.new(2285, 15, 905),
            ["Cursed Ship"] = Vector3.new(923, 126, 32852),
            ["Zombie Island"] = Vector3.new(-6509, 83, -133)
        }
    elseif y == 7449423635 then
        TableLocations = {
            ["Floating Turtle"] = Vector3.new(-12462, 375, -7552),
            ["Hydra Island"] = Vector3.new(5657.88623046875, 1013.0790405273438, -335.4996337890625),
            ["Mansion"] = Vector3.new(-12462, 375, -7552),
            ["Castle"] = Vector3.new(-5036, 315, -3179),
            ["Dimensional Shift"] = Vector3.new(-2097.3447265625, 4776.24462890625, -15013.4990234375),
            ["Beautiful Pirate"] = Vector3.new(5319, 23, -93),
            ["Temple of Time"] = Vector3.new(28286, 14897, 103)
        }
    end

    for _, v in pairs(TableLocations) do
        local dist = (v - vcspos).Magnitude
        if dist < minDist then
            minDist = dist
            chosenTeleport = v
        end
    end

    local playerPos = game.Players.LocalPlayer.Character.HumanoidRootPart.Position
    if minDist <= (vcspos - playerPos).Magnitude then
        return chosenTeleport
    end
end

local function _raid_requestEntrance(teleportPos)
    game.ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", teleportPos)
    local char = game.Players.LocalPlayer.Character.HumanoidRootPart
    char.CFrame = char.CFrame + Vector3.new(0, 50, 0)
    task.wait(0.5)
end

local function topos_raid(Pos)
    local plr2 = game.Players.LocalPlayer
    if plr2.Character and plr2.Character.Humanoid.Health > 0 and plr2.Character:FindFirstChild("HumanoidRootPart") then
        local Distance = (Pos.Position - plr2.Character.HumanoidRootPart.Position).Magnitude
        if not Pos then return end
        local nearestTeleport = _raid_CheckNearestTeleporter(Pos)
        if nearestTeleport then
            _raid_requestEntrance(nearestTeleport)
        end
        if not plr2.Character:FindFirstChild("PartTele") then
            local PartTele = Instance.new("Part", plr2.Character)
            PartTele.Size = Vector3.new(10, 1, 10)
            PartTele.Name = "PartTele"
            PartTele.Anchored = true
            PartTele.Transparency = 1
            PartTele.CanCollide = true
            PartTele.CFrame = _raid_WaitHRP(plr2).CFrame
            PartTele:GetPropertyChangedSignal("CFrame"):Connect(function()
                if not _raid_isTeleporting then return end
                task.wait()
                if plr2.Character and plr2.Character:FindFirstChild("HumanoidRootPart") then
                    _raid_WaitHRP(plr2).CFrame = PartTele.CFrame
                end
            end)
        end
        _raid_isTeleporting = true
        local Tween = game:GetService("TweenService"):Create(
            plr2.Character.PartTele,
            TweenInfo.new(Distance / 360, Enum.EasingStyle.Linear),
            {CFrame = Pos}
        )
        Tween:Play()
        Tween.Completed:Connect(function(status)
            if status == Enum.PlaybackState.Completed then
                if plr2.Character:FindFirstChild("PartTele") then
                    plr2.Character.PartTele:Destroy()
                end
                _raid_isTeleporting = false
            end
        end)
    end
end

local function _raid_EquipWeapon(ToolSe)
    if game.Players.LocalPlayer.Backpack:FindFirstChild(ToolSe) then
        local Tool = game.Players.LocalPlayer.Backpack:FindFirstChild(ToolSe)
        wait(0.1)
        game.Players.LocalPlayer.Character.Humanoid:EquipTool(Tool)
    end
end

function IsIslandRaid(cu)
    if game:GetService("Workspace")["_WorldOrigin"].Locations:FindFirstChild("Island " .. cu) then
        local min = 4500
        for r, v in pairs(game:GetService("Workspace")["_WorldOrigin"].Locations:GetChildren()) do
            if v.Name == "Island " .. cu and
                (v.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude < min then
                min = (v.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            end
        end
        for r, v in pairs(game:GetService("Workspace")["_WorldOrigin"].Locations:GetChildren()) do
            if v.Name == "Island " .. cu and
                (v.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= min then
                return v
            end
        end
    end
end

function getNextIsland()
    TableIslandsRaid = {5, 4, 3, 2, 1}
    for r, v in pairs(TableIslandsRaid) do
        if IsIslandRaid(v) and (IsIslandRaid(v).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 4500 then
            return IsIslandRaid(v)
        end
    end
end

function attackNearbyEnemies()

    for _, v in pairs(game.Players.LocalPlayer.Backpack:GetChildren()) do
        if v:IsA("Tool") and v.ToolTip == "Melee" then
            game.Players.LocalPlayer.Character.Humanoid:EquipTool(v)
            break
        end
    end

    local enemies = {}
    for _, v in pairs(game:GetService("Workspace").Enemies:GetChildren()) do
        if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
            local distance = (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            if distance <= 1000 then
                table.insert(enemies, v)
            end
        end
    end
    for _, enemy in pairs(enemies) do
        repeat
            if enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 then
                _raid_EquipWeapon(ChooseWP)
                topos_raid(enemy.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0))
                wait(0.1)
            end
        until not enemy:FindFirstChild("Humanoid") or enemy.Humanoid.Health <= 0
    end
end

spawn(function()
    while wait() do
        if _G.AutoRaidNextIsland then
            attackNearbyEnemies()
            if getNextIsland() then
                spawn(topos_raid(getNextIsland().CFrame * CFrame.new(0, 60, 0)), 1)
            end
        end
    end
end)

local SelectChip = "Flame"
spawn(function()
    while wait() do
        if _G.AutoBuyChip then
            pcall(function()
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("RaidsNpc", "Select", SelectChip)
            end)
        end
    end
end)

local AutoAwakenAbilities = false
spawn(function()
    while task.wait() do
        if AutoAwakenAbilities then
            pcall(function()
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Awakener", "Awaken")
            end)
        end
    end
end)

local FruitListLowBeli = {
    "Rocket-Rocket","Spin-Spin","Chop-Chop","Spring-Spring","Bomb-Bomb",
    "Smoke-Smoke","Spike-Spike","Flame-Flame","Falcon-Falcon","Ice-Ice",
    "Sand-Sand","Dark-Dark","Ghost-Ghost","Diamond-Diamond","Light-Light",
    "Rubber-Rubber","Creation-Creation"
}
spawn(function()
    while wait(0.1) do
        if _G.Autofruit then
            pcall(function()
                for _, fruit in pairs(FruitListLowBeli) do
                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadFruit", fruit)
                end
            end)
        end
    end
end)

do
    local RaidSection = FarmPage:Section({ Name = "Auto Raid" })

    RaidSection:AddToggle({
        Name = "Auto Farm Raid Next Island", Flag = "auto_raid_next_island", Default = getConfig("Auto Farm Raid Next Island", false),
        Callback = function(v)
            setConfig("Auto Farm Raid Next Island", v)
            _G.AutoRaidNextIsland = v
        end
    })
    RaidSection:AddLabel("Requer estar dentro de uma Raid ativa")

    RaidSection:AddDropdown({
        Name = "Chip da Raid", Flag = "select_chip_raid",
        Items = {"Flame","Ice","Sand","Dark","Light","Magma","Quake","Buddha","Spider","Phoenix","Rumble","Dough"},
        Default = getConfig("Chip da Raid", "Flame"),
        Callback = function(v)
            setConfig("Chip da Raid", v)
            SelectChip = v
        end
    })
    SelectChip = getConfig("Chip da Raid", "Flame")
    RaidSection:AddToggle({
        Name = "Auto Buy Chip", Flag = "auto_buy_chip", Default = getConfig("Auto Buy Chip", false),
        Callback = function(v)
            setConfig("Auto Buy Chip", v)
            _G.AutoBuyChip = v
        end
    })
    RaidSection:AddToggle({
        Name = "Awakener Fruit", Flag = "awakener_fruit", Default = getConfig("Awakener Fruit", false),
        Callback = function(v)
            setConfig("Awakener Fruit", v)
            AutoAwakenAbilities = v
        end
    })
    RaidSection:AddToggle({
        Name = "Auto Get Fruit Low Beli", Flag = "auto_get_fruit_low_beli", Default = getConfig("Auto Get Fruit Low Beli", false),
        Callback = function(v)
            setConfig("Auto Get Fruit Low Beli", v)
            _G.Autofruit = v
        end
    })
end

do
    local MaterialSection = FarmPage:Section({ Name = "Material" })

    local materialWorldId = mundox[game.PlaceId]

    local MaterialListsByWorld = {
        World1 = { "Leather + Scrap Metal", "Angel Wings", "Magma Ore", "Fish Tail" },
        World2 = { "Leather + Scrap Metal", "Radioactive Material", "Ectoplasm", "Mystic Droplet", "Magma Ore", "Vampire Fang" },
        World3 = { "Scrap Metal", "Demonic Wisp", "Conjured Cocoa", "Dragon Scale", "Gunpowder", "Fish Tail", "Mini Tusk" },
    }

    -- material -> mobs que dropam ele + local pra ir + (se precisar) pedir entrada numa área fechada
    local MaterialData = {
        World1 = {
            ["Angel Wings"] = {
                mobs = { "Shanda", "Royal Squad", "Royal Soldier", "Wysper", "Thunder God" },
                pos  = CFrame.new(-4698, 845, -1912),
                entrance = { pos = Vector3.new(-4607.82275, 872.54248, -1667.55688), dist = 10000 },
            },
            ["Leather + Scrap Metal"] = {
                mobs = { "Brute", "Pirate" },
                pos  = CFrame.new(-1145, 15, 4350),
            },
            ["Magma Ore"] = {
                mobs = { "Military Soldier", "Military Spy", "Magma Admiral" },
                pos  = CFrame.new(-5815, 84, 8820),
            },
            ["Fish Tail"] = {
                mobs = { "Fishman Warrior", "Fishman Commando", "Fishman Lord" },
                pos  = CFrame.new(61123, 19, 1569),
                entrance = { pos = Vector3.new(61163.8515625, 5.342342376709, 1819.7841796875), dist = 17000 },
            },
        },
        World2 = {
            ["Leather + Scrap Metal"] = {
                mobs = { "Marine Captain" },
                pos  = CFrame.new(-2010.5059814453, 73.001159667969, -3326.6208496094),
            },
            ["Magma Ore"] = {
                mobs = { "Magma Ninja", "Lava Pirate" },
                pos  = CFrame.new(-5428, 78, -5959),
            },
            ["Ectoplasm"] = {
                mobs = { "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer" },
                pos  = CFrame.new(911.35827636719, 125.95812988281, 33159.5390625),
                entrance = { pos = Vector3.new(923.21252441406, 126.9760055542, 32852.83203125), dist = 1000 },
            },
            ["Mystic Droplet"] = {
                mobs = { "Water Fighter" },
                pos  = CFrame.new(-3385, 239, -10542),
            },
            ["Radioactive Material"] = {
                mobs = { "Factory Staff" },
                pos  = CFrame.new(295, 73, -56),
            },
            ["Vampire Fang"] = {
                mobs = { "Vampire" },
                pos  = CFrame.new(-6033, 7, -1317),
            },
        },
        World3 = {
            ["Scrap Metal"] = {
                mobs = { "Jungle Pirate", "Forest Pirate" },
                pos  = CFrame.new(-11975.78515625, 331.77340698242, -10620.030273438),
            },
            ["Fish Tail"] = {
                mobs = { "Fishman Raider", "Fishman Captain" },
                pos  = CFrame.new(-10993, 332, -8940),
            },
            ["Conjured Cocoa"] = {
                mobs = { "Chocolate Bar Battler", "Cocoa Warrior" },
                pos  = CFrame.new(620.63446044922, 78.936447143555, -12581.369140625),
            },
            ["Dragon Scale"] = {
                mobs = { "Dragon Crew Archer", "Dragon Crew Warrior" },
                pos  = CFrame.new(6594, 383, 139),
            },
            ["Gunpowder"] = {
                mobs = { "Pistol Billionaire" },
                pos  = CFrame.new(-84.855690002441, 85.620613098145, 6132.0087890625),
            },
            ["Mini Tusk"] = {
                mobs = { "Mythological Pirate" },
                pos  = CFrame.new(-13545, 470, -6917),
            },
            ["Demonic Wisp"] = {
                mobs = { "Demonic Soul" },
                pos  = CFrame.new(-9495.6806640625, 453.58624267578, 5977.3486328125),
            },
        },
    }

    local materialItems = MaterialListsByWorld[materialWorldId] or {}

    MaterialSection:AddDropdown({
        Name = "Select Material", Flag = "select_material",
        Items = materialItems, Default = getConfig("Select Material", materialItems[1] or ""),
        Callback = function(v)
            setConfig("Select Material", v)
            _G.SelectMaterial = v
        end
    })
    _G.SelectMaterial = getConfig("Select Material", materialItems[1] or "")

    local function materialEquipWeapon()
        local char = getChar()
        local cur  = char and char:FindFirstChildOfClass("Tool")
        if cur and cur.ToolTip == ChooseWP then return end
        for _, t in pairs(plr.Backpack:GetChildren()) do
            if t:IsA("Tool") and t.ToolTip == ChooseWP then
                if cur then cur.Parent = plr.Backpack end
                t.Parent = char
                break
            end
        end
    end

    local function findMaterialMob(info)
        for _, e in pairs(workspace.Enemies:GetChildren()) do
            for _, mobName in ipairs(info.mobs) do
                if string.find(e.Name, mobName) then
                    local hum = e:FindFirstChild("Humanoid")
                    if hum and hum.Health > 0 and e:FindFirstChild("HumanoidRootPart") then
                        return e
                    end
                end
            end
        end
    end

    task.spawn(function()
        while task.wait(0.15) do
            if _G["AutoMaterial"] then
                pcall(function()
                    st = true
                    local worldData = MaterialData[materialWorldId]
                    local info = worldData and worldData[_G.SelectMaterial]
                    if not info then
                        _G.CurrentMaterialFilter = nil
                        return
                    end

                    -- expõe a lista de mobs desse material pro sistema de Bring puxar vários de uma vez
                    local filterTbl = {}
                    for _, m in ipairs(info.mobs) do filterTbl[m] = true end
                    _G.CurrentMaterialFilter = filterTbl

                    -- se a área é fechada (tipo Navio Assombrado), pede entrada quando longe
                    if info.entrance then
                        local root = getRoot()
                        if root and (root.Position - info.entrance.pos).Magnitude >= info.entrance.dist then
                            pcall(function()
                                RS.Remotes.CommF_:InvokeServer("requestEntrance", info.entrance.pos)
                            end)
                        end
                    end

                    local mob = findMaterialMob(info)
                    if mob then
                        repeat
                            if not _G["AutoMaterial"] then break end
                            st = true
                            materialEquipWeapon()
                            local hrp = mob:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                _tp((hrp.CFrame * CFrame.new(0, 27, 0)) * CFrame.Angles(0, math.rad(180), 0))
                            end
                            task.wait()
                        until not _G["AutoMaterial"] or not mob.Parent or mob.Humanoid.Health <= 0
                        releaseHoldIfIdle()
                    else
                        -- sem mob por perto ainda: vai até o ponto de farm desse material
                        st = true
                        _tp(info.pos)
                    end
                end)
            end
        end
    end)

    MaterialSection:AddToggle({
        Name = "Auto Farm", Flag = "auto_material_farm", Default = getConfig("Auto Farm", false),
        Callback = function(v)
            setConfig("Auto Farm", v)
            _G["AutoMaterial"] = v
            if v then
                st = true
            elseif not (_G["AutoFarm_Level"] or _G["AutoFarm_Bone"] or _G["AutoFarm_Tyrant"]
                or _G["FarmTyrant"] or _G["FarmPhaBinh"] or _G["AutoEliteQuest"] or _G["AutoPirateRaid"]) then
                st = false
                clearMods()
            end
        end
    })
end

local TeleportPage = Window:Page({ Name = "Teleport", Icon = "map-pin" })

local IslandsWorld1 = {"WindMill","Marine","Middle Town","Jungle","Pirate Village","Desert","Snow Island","MarineFord","Colosseum","Sky Island 1","Sky Island 2","Sky Island 3","Prison","Magma Village","Under Water Island","Fountain City","Shank Room","Mob Island"}
local IslandsWorld2 = {"The Cafe","First Spot","Dark Area","Flamingo Mansion","Flamingo Room","Green Zone","Factory","Colosseum","Zombie Island","Two Snow Mountain","Punk Hazard","Cursed Ship","Ice Castle","Forgotten Island","Ussop Island","Mini Sky Island"}
local IslandsWorld3 = {"Mansion","Port Town","Great Tree","Castle On The Sea","MiniSky","Hydra Island","Floating Turtle","Haunted Castle","Ice Cream Island","Peanut Island","Cake Island","Cocoa Island","Candy Island","Tiki Outpost"}

local IslandCFrames = {
    ["WindMill"]           = CFrame.new(979.79895019531, 16.516613006592, 1429.0466308594),
    ["Marine"]             = CFrame.new(-2566.4296875, 6.8556680679321, 2045.2561035156),
    ["Middle Town"]        = CFrame.new(-690.33081054688, 15.09425163269, 1582.2380371094),
    ["Jungle"]             = CFrame.new(-1612.7957763672, 36.852081298828, 149.12843322754),
    ["Pirate Village"]     = CFrame.new(-1181.3093261719, 4.7514905929565, 3803.5456542969),
    ["Desert"]             = CFrame.new(944.15789794922, 20.919729232788, 4373.3002929688),
    ["Snow Island"]        = CFrame.new(1347.8067626953, 104.66806030273, -1319.7370605469),
    ["MarineFord"]         = CFrame.new(-4914.8212890625, 50.963626861572, 4281.0278320313),
    ["Colosseum"]          = CFrame.new(-1427.6203613281, 7.2881078720093, -2792.7722167969),
    ["Sky Island 1"]       = CFrame.new(-4869.1025390625, 733.46051025391, -2667.0180664063),
    ["Prison"]             = CFrame.new(4875.330078125, 5.6519818305969, 734.85021972656),
    ["Magma Village"]      = CFrame.new(-5247.7163085938, 12.883934020996, 8504.96875),
    ["Fountain City"]      = CFrame.new(5127.1284179688, 59.501365661621, 4105.4458007813),
    ["Shank Room"]         = CFrame.new(-1442.16553, 29.8788261, -28.3547478),
    ["Mob Island"]         = CFrame.new(-2850.20068, 7.39224768, 5354.99268),
    ["The Cafe"]           = CFrame.new(-380.47927856445, 77.220390319824, 255.82550048828),
    ["First Spot"]         = CFrame.new(-11.311455726624, 29.276733398438, 2771.5224609375),
    ["Dark Area"]          = CFrame.new(3780.0302734375, 22.652164459229, -3498.5859375),
    ["Flamingo Mansion"]   = CFrame.new(-483.73370361328, 332.0383605957, 595.32708740234),
    ["Flamingo Room"]      = CFrame.new(2284.4140625, 15.152037620544, 875.72534179688),
    ["Green Zone"]         = CFrame.new(-2448.5300292969, 73.016105651855, -3210.6306152344),
    ["Factory"]            = CFrame.new(424.12698364258, 211.16171264648, -427.54049682617),
    ["Zombie Island"]      = CFrame.new(-5622.033203125, 492.19604492188, -781.78552246094),
    ["Two Snow Mountain"]  = CFrame.new(753.14288330078, 408.23559570313, -5274.6147460938),
    ["Punk Hazard"]        = CFrame.new(-6127.654296875, 15.951762199402, -5040.2861328125),
    ["Cursed Ship"]        = CFrame.new(923.40197753906, 125.05712890625, 32885.875),
    ["Ice Castle"]         = CFrame.new(6148.4116210938, 294.38687133789, -6741.1166992188),
    ["Forgotten Island"]   = CFrame.new(-3032.7641601563, 317.89672851563, -10075.373046875),
    ["Ussop Island"]       = CFrame.new(4816.8618164063, 8.4599885940552, 2863.8195800781),
    ["Mini Sky Island"]    = CFrame.new(-288.74060058594, 49326.31640625, -35248.59375),
    ["Port Town"]          = CFrame.new(-290.7376708984375, 6.729952812194824, 5343.5537109375),
    ["Great Tree"]         = CFrame.new(2681.2736816406, 1682.8092041016, -7190.9853515625),
    ["Castle On The Sea"]  = CFrame.new(-5074.45556640625, 314.5155334472656, -2991.054443359375),
    ["MiniSky"]            = CFrame.new(-260.65557861328, 49325.8046875, -35253.5703125),
    ["Hydra Island"]       = CFrame.new(5255.1049, 1004.1949, 344.7700),
    ["Floating Turtle"]    = CFrame.new(-13274.528320313, 531.82073974609, -7579.22265625),
    ["Haunted Castle"]     = CFrame.new(-9515.3720703125, 164.00624084473, 5786.0610351562),
    ["Ice Cream Island"]   = CFrame.new(-902.56817626953, 79.93204498291, -10988.84765625),
    ["Peanut Island"]      = CFrame.new(-2062.7475585938, 50.473892211914, -10232.568359375),
    ["Cake Island"]        = CFrame.new(-1884.7747802734375, 19.327526092529297, -11666.8974609375),
    ["Cocoa Island"]       = CFrame.new(87.94276428222656, 73.55451202392578, -12319.46484375),
    ["Candy Island"]       = CFrame.new(-1014.4241943359375, 149.11068725585938, -14555.962890625),
    ["Tiki Outpost"]       = CFrame.new(-16218.6826, 9.08636189, 445.618408, -0.0610186495, 1.10512588e-09, -0.99813664, -1.83458475e-08, 1, 2.22871765e-09, 0.99813664, 1.84476558e-08, -0.0610186495),
}

local IslandEntrance = {
    ["Sky Island 2"]       = Vector3.new(-4607.82275, 872.54248, -1667.55688),
    ["Sky Island 3"]       = Vector3.new(-7894.6176757813, 5547.1416015625, -380.29119873047),
    ["Under Water Island"] = Vector3.new(61163.8515625, 11.6796875, 1819.7841796875),
    ["Mansion"]            = Vector3.new(-12471.169921875, 374.94024658203, -7551.677734375),
}

local function tpIsland(name)
    if IslandEntrance[name] then
        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", IslandEntrance[name])
    elseif IslandCFrames[name] then
        topos_raid(IslandCFrames[name])
    end
end

local NPCCFrames = {
    ["Random Devil Fruit (W1)"] = CFrame.new(-1436.19727, 61.8777695, 4.75247526, -0.557794094, 2.74216543e-08, 0.829979479, 5.83273234e-08, 1, 6.16037932e-09, -0.829979479, 5.18467118e-08, -0.557794094),
    ["Blox Fruits Dealer (W1)"] = CFrame.new(-923.255066, 7.67800522, 1608.61011),
    ["Remove Devil Fruit (W1)"] = CFrame.new(5664.80469, 64.677681, 867.85907),
    ["Ability Teacher"]         = CFrame.new(-1057.67822, 9.65220833, 1799.49146, -0.865874112, -9.26330159e-08, 0.500262439, -7.33759435e-08, 1, 5.816689e-08, -0.500262439, 1.36579752e-08, -0.865874112),
    ["Dark Step"]               = CFrame.new(-987.873047, 13.7778397, 3989.4978),
    ["Electro"]                 = CFrame.new(-5389.49561, 13.283, -2149.80151),
    ["Fishman Karate"]          = CFrame.new(61581.8047, 18.8965912, 987.832703),
    ["Dargon Berath"]           = CFrame.new(703.372986, 186.985519, 654.522034),
    ["Mysterious Man"]          = CFrame.new(-2574.43335, 1627.92371, -3739.35767, 0.378697902, -9.06400288e-09, 0.92552036, -8.95582009e-09, 1, 1.34578926e-08, -0.92552036, -1.33852689e-08, 0.378697902),
    ["Mysterious Scientist"]    = CFrame.new(-6437.87793, 250.645355, -4498.92773, 0.502376854, -1.01223634e-08, -0.864648759, 2.34106086e-08, 1, 1.89508653e-09, 0.864648759, -2.11940012e-08, 0.502376854),
    ["Awakening Expert"]        = CFrame.new(-408.098846, 16.0459061, 247.432846, 0.028394036, 6.17599138e-10, 0.999596894, -5.57905944e-09, 1, -4.59372484e-10, -0.999596894, -5.56376767e-09, 0.028394036),
    ["Nerd"]                    = CFrame.new(-401.783722, 73.0859299, 262.306702),
    ["Bar Manager"]             = CFrame.new(-385.84726, 73.0458984, 316.088806),
    ["Blox Fruits Dealer (W2)"] = CFrame.new(-450.725464, 73.0458984, 355.636902, -0.780352175, -2.7266168e-08, 0.625340283, 9.78516468e-09, 1, 5.58128797e-08, -0.625340283, 4.96727601e-08, -0.780352175),
    ["Trevor (W2)"]             = CFrame.new(-341.498322, 331.886444, 643.024963),
    ["Enhancement Editor"]      = CFrame.new(-346.820221, 72.9856339, 1194.36218),
    ["Pirate Recruiter"]        = CFrame.new(-428.072998, 72.9495239, 1445.32422),
    ["Marines Recruiter"]       = CFrame.new(-1349.77295, 72.9853363, -1045.12964, 0.866493046, 0, -0.499189168, 0, 1, 0, 0.499189168, 0, 0.866493046),
    ["Chemist"]                 = CFrame.new(-2777.45288, 72.9919434, -3572.25732),
    ["Ghoul Mark"]              = CFrame.new(635.172546, 125.976357, 33219.832),
    ["Cyborg"]                  = CFrame.new(629.146851, 312.307373, -531.624146),
    ["Guashiem"]                = CFrame.new(937.953003, 181.083359, 33277.9297),
    ["El Admin"]                = CFrame.new(1322.80835, 126.345039, 33135.8789, 0.988783717, -8.69797603e-08, -0.149354503, 8.62223786e-08, 1, -1.15461916e-08, 0.149354503, -1.46101409e-09, 0.988783717),
    ["El Rodolfo"]              = CFrame.new(941.228699, 40.4686775, 32778.9922, -0.818029106, -1.19524382e-08, 0.575176775, -1.28741648e-08, 1, 2.47053866e-09, -0.575176775, -5.38394795e-09, -0.818029106),
    ["Arowe"]                   = CFrame.new(-1994.51038, 125.519142, -72.2622986, -0.16715166, -6.55417338e-08, -0.985931218, -7.13315558e-08, 1, -5.43836585e-08, 0.985931218, 6.12376851e-08, -0.16715166),
    ["Random Devil Fruit (W3)"] = CFrame.new(-12491, 337, -7449),
    ["Blox Fruits Dealer (W3)"] = CFrame.new(-12511, 337, -7448),
    ["Remove Devil Fruit (W3)"] = CFrame.new(-5571, 1089, -2661),
    ["Horned Man"]              = CFrame.new(-11890, 931, -8760),
    ["Hungry Man"]              = CFrame.new(-10919, 624, -10268),
    ["Previous Hero"]           = CFrame.new(-10368, 332, -10128),
    ["Butler"]                  = CFrame.new(-5125, 316, -3130),
    ["Lunoven"]                 = CFrame.new(-5117, 316, -3093),
    ["Elite Hunter"]            = CFrame.new(-5420, 314, -2828),
    ["Player Hunter"]           = CFrame.new(-5559, 314, -2840),
    ["Uzoth"]                   = CFrame.new(-9785, 852, 6667),
}

local NPCListWorld1 = {"Random Devil Fruit (W1)","Blox Fruits Dealer (W1)","Remove Devil Fruit (W1)","Ability Teacher","Dark Step","Electro","Fishman Karate"}
local NPCListWorld2 = {"Dargon Berath","Mysterious Man","Mysterious Scientist","Awakening Expert","Nerd","Bar Manager","Blox Fruits Dealer (W2)","Trevor (W2)","Enhancement Editor","Pirate Recruiter","Marines Recruiter","Chemist","Cyborg","Ghoul Mark","Guashiem","El Admin","El Rodolfo","Arowe"}
local NPCListWorld3 = {"Random Devil Fruit (W3)","Blox Fruits Dealer (W3)","Remove Devil Fruit (W3)","Horned Man","Hungry Man","Previous Hero","Butler","Lunoven","Elite Hunter","Player Hunter","Uzoth"}

local _G_TeleportIsland = false
local _G_TeleportNPC    = false
local _G_SelectIsland   = "WindMill"
local _G_SelectNPC      = "Dargon Berath"

spawn(function()
    while wait() do
        if _G_TeleportIsland then
            pcall(function() tpIsland(_G_SelectIsland) end)
        end
    end
end)

spawn(function()
    while wait() do
        if _G_TeleportNPC then
            pcall(function()
                if NPCCFrames[_G_SelectNPC] then
                    topos_raid(NPCCFrames[_G_SelectNPC])
                end
            end)
        end
    end
end)

local function _stopTeleportTween()
    _raid_isTeleporting = false
    local char = game.Players.LocalPlayer.Character
    if char and char:FindFirstChild("PartTele") then
        char.PartTele:Destroy()
    end
end

do
    local TravelSection = TeleportPage:Section({ Name = "Viajar" })
    TravelSection:AddButton({ Name = "Primeiro Mar", Callback = function()
        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelMain")
    end })
    TravelSection:AddButton({ Name = "Segundo Mar", Callback = function()
        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelDressrosa")
    end })
    TravelSection:AddButton({ Name = "Terceiro Mar", Callback = function()
        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelZou")
    end })

    local IslandSection = TeleportPage:Section({ Name = "Auto Island" })

    local currentWorldId = mundox[game.PlaceId]

    if currentWorldId == "World1" then
        IslandSection:AddDropdown({
            Name = "Selecionar Ilha", Flag = "select_island",
            Items = IslandsWorld1, Default = getConfig("Selecionar Ilha", "WindMill"),
            Callback = function(v) setConfig("Selecionar Ilha", v); _G_SelectIsland = v end
        })
    elseif currentWorldId == "World2" then
        IslandSection:AddDropdown({
            Name = "Selecionar Ilha", Flag = "select_island",
            Items = IslandsWorld2, Default = getConfig("Selecionar Ilha", "The Cafe"),
            Callback = function(v) setConfig("Selecionar Ilha", v); _G_SelectIsland = v end
        })
    elseif currentWorldId == "World3" then
        IslandSection:AddDropdown({
            Name = "Selecionar Ilha", Flag = "select_island",
            Items = IslandsWorld3, Default = getConfig("Selecionar Ilha", "Mansion"),
            Callback = function(v) setConfig("Selecionar Ilha", v); _G_SelectIsland = v end
        })
    end

    IslandSection:AddToggle({
        Name = "Auto Tween para Ilha", Flag = "auto_tween_island", Default = getConfig("Auto Tween para Ilha", false),
        Callback = function(v)
            setConfig("Auto Tween para Ilha", v)
            _G_TeleportIsland = v
            if not v then _stopTeleportTween() end
        end
    })

    local NPCSection = TeleportPage:Section({ Name = "Auto NPC" })

    if currentWorldId == "World1" then
        NPCSection:AddDropdown({
            Name = "Selecionar NPC", Flag = "select_npc",
            Items = NPCListWorld1, Default = getConfig("Selecionar NPC", "Random Devil Fruit (W1)"),
            Callback = function(v) setConfig("Selecionar NPC", v); _G_SelectNPC = v end
        })
    elseif currentWorldId == "World2" then
        NPCSection:AddDropdown({
            Name = "Selecionar NPC", Flag = "select_npc",
            Items = NPCListWorld2, Default = getConfig("Selecionar NPC", "Dargon Berath"),
            Callback = function(v) setConfig("Selecionar NPC", v); _G_SelectNPC = v end
        })
    elseif currentWorldId == "World3" then
        NPCSection:AddDropdown({
            Name = "Selecionar NPC", Flag = "select_npc",
            Items = NPCListWorld3, Default = getConfig("Selecionar NPC", "Random Devil Fruit (W3)"),
            Callback = function(v) setConfig("Selecionar NPC", v); _G_SelectNPC = v end
        })
    end

    NPCSection:AddToggle({
        Name = "Auto Teleport NPC", Flag = "auto_teleport_npc", Default = getConfig("Auto Teleport NPC", false),
        Callback = function(v)
            setConfig("Auto Teleport NPC", v)
            _G_TeleportNPC = v
            if not v then _stopTeleportTween() end
        end
    })
end

local StylesData = nil
local DataUrl = "https://raw.githubusercontent.com/NSHWShadow/MidNightHub/refs/heads/main/Data/Blox%20Fruits/styles.json"

local function LoadStylesData()
    local success, data = pcall(function()
        return game:HttpGet(DataUrl)
    end)
    if success and data then
        local decoded = game:GetService("HttpService"):JSONDecode(data)
        StylesData = decoded
        return true
    else
        return false
    end
end

local _shopTweenService = game:GetService("TweenService")

local function ShopTweenToPosition(posData)
    if not posData or #posData < 3 then return false end
    local x, y, z = posData[1], posData[2], posData[3]
    local targetCFrame = CFrame.new(x, y, z)
    if #posData >= 6 then
        local r00, r01, r02, r10, r11, r12, r20, r21, r22 =
            posData[4], posData[5], posData[6],
            posData[7], posData[8], posData[9],
            posData[10], posData[11], posData[12]
        targetCFrame = CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
    end
    local character = plr.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    local speed = 300
    local duration = math.max(distance / speed, 0.5)
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = _shopTweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    tween:Play()
    tween.Completed:Wait()
    return true
end

local function ExecuteStylePurchase(styleKey, styleData)
    local remote = styleData.remote
    local checkRemote = styleData.checkRemote
    if styleData.pos then
        Library:Notify({ Name = "Movendo", Content = "Indo ate o NPC de " .. styleData.name .. "...", Time = 2 })
        local tweenSuccess = ShopTweenToPosition(styleData.pos)
        if not tweenSuccess then
            Library:Notify({ Name = "Erro", Content = "Falha ao chegar no NPC!", Time = 3 })
            return false, "Falha no tween"
        end
        task.wait(0.5)
    end
    local success = false
    local errorMsg = ""
    pcall(function()
        if remote == "BuyBlackLeg" then
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyBlackLeg"); success = true
        elseif remote == "BuyElectro" then
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyElectro"); success = true
        elseif remote == "BuyFishmanKarate" then
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyFishmanKarate"); success = true
        elseif remote == "BlackbeardReward" then
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward", checkRemote[2], checkRemote[3]); success = true
        elseif remote == "BuyDeathStep" then
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyDeathStep"); success = true
        elseif remote == "BuySharkmanKarate" then
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuySharkmanKarate", true)
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuySharkmanKarate"); success = true
        elseif remote == "BuySuperhuman" then
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuySuperhuman"); success = true
        elseif remote == "BuyElectricClaw" then
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyElectricClaw"); success = true
        elseif remote == "BuyDragonTalon" then
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyDragonTalon"); success = true
        elseif remote == "BuyGodhuman" then
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyGodhuman"); success = true
        elseif remote == "BuySanguineArt" then
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuySanguineArt", true)
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuySanguineArt"); success = true
        else
            errorMsg = "Remote desconhecido: " .. remote; success = false
        end
    end)
    return success, errorMsg
end

local function BuyStyleWithTween(styleInfo)
    if not styleInfo or not styleInfo.data then
        Library:Notify({ Name = "Erro", Content = "Selecione um estilo valido!", Time = 3 }); return
    end
    if not styleInfo.data.pos then
        Library:Notify({ Name = "Erro", Content = "NPC nao encontrado para este estilo!", Time = 3 }); return
    end
    local character = plr.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local targetPos = Vector3.new(styleInfo.data.pos[1], styleInfo.data.pos[2], styleInfo.data.pos[3])
    local distance = (hrp.Position - targetPos).Magnitude
    if distance < 20 then
        local success, errorMsg = ExecuteStylePurchase(styleInfo.key, styleInfo.data)
        if success then
            Library:Notify({ Name = "Sucesso", Content = styleInfo.name .. " comprado com sucesso!", Time = 4 })
        else
            Library:Notify({ Name = "Erro", Content = errorMsg or "Falha ao comprar " .. styleInfo.name, Time = 4 })
        end
        return
    end
    Library:Notify({ Name = "Movendo", Content = "Indo ate o NPC de " .. styleInfo.name .. "...", Time = 3 })
    local tweenSuccess = ShopTweenToPosition(styleInfo.data.pos)
    if not tweenSuccess then
        Library:Notify({ Name = "Erro", Content = "Falha ao chegar no NPC!", Time = 3 }); return
    end
    task.wait(0.5)
    local success, errorMsg = ExecuteStylePurchase(styleInfo.key, styleInfo.data)
    if success then
        Library:Notify({ Name = "Sucesso", Content = styleInfo.name .. " comprado com sucesso!", Time = 4 })
    else
        Library:Notify({ Name = "Erro", Content = errorMsg or "Falha ao comprar " .. styleInfo.name, Time = 4 })
    end
end

local function GetCurrentSea()
    local placeId = game.PlaceId
    for seaId, seaData in pairs(StylesData.seas) do
        if seaData.placeId == placeId then return seaId, seaData end
    end
    return nil, nil
end

local function FormatPrice(price, currency)
    if currency == "Beli" then
        return string.format("$%s", tostring(price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
    else
        return string.format("%s %s", tostring(price), currency)
    end
end

local function GetStyleDisplayName(styleKey, styleData)
    local name = styleData.name or styleKey
    local price = FormatPrice(styleData.price, styleData.currency)
    local display = string.format("%s - %s", name, price)
    if styleData.extraPrice then
        display = display .. string.format(" + %s %s", FormatPrice(styleData.extraPrice, styleData.extraCurrency or "Fragments"), styleData.extraCurrency or "Fragments")
    end
    if styleData.requiredItem then
        display = display .. string.format(" [Requer: %s]", styleData.requiredItem)
    end
    if styleData.requiredMastery then
        display = display .. string.format(" [Mastery: %s]", styleData.requiredMastery)
    end
    if styleData.requiredStyles then
        display = display .. string.format(" [Requer: %s estilos]", #styleData.requiredStyles)
    end
    return display, name, price
end

local ShopPage = Window:Page({ Name = "Loja", Icon = "shopping-cart" })

task.spawn(function()
    local loaded = LoadStylesData()
    if not loaded then
        local errSec = ShopPage:Section({ Name = "Erro" })
        errSec:AddLabel("Falha ao carregar dados da loja.")
        return
    end

    local FightingSection = ShopPage:Section({ Name = "Fighting Styles" })
    local currentSeaId, currentSeaData = GetCurrentSea()
    local styleItems = {}
    local styleDataMap = {}
    if currentSeaData and currentSeaData.styles then
        for styleKey, styleData in pairs(currentSeaData.styles) do
            local display, name, price = GetStyleDisplayName(styleKey, styleData)
            table.insert(styleItems, display)
            styleDataMap[display] = { key = styleKey, data = styleData, name = name, price = price }
        end
    end
    if #styleItems == 0 then
        FightingSection:AddLabel("Nenhum estilo disponivel para este mar.")
    else
        FightingSection:AddDropdown({
            Name = "Selecione o Estilo", Flag = "shop_fighting_style",
            Items = styleItems, Default = getConfig("Selecione o Estilo", styleItems[1] or ""),
            Callback = function(Value) setConfig("Selecione o Estilo", Value); _G.SelectedFighting = Value end
        })
        FightingSection:AddButton({
            Name = "Ir ate o NPC e Comprar",
            Callback = function()
                local selected = _G.SelectedFighting or styleItems[1]
                if not selected or not styleDataMap[selected] then
                    Library:Notify({ Name = "Erro", Content = "Selecione um estilo valido!", Time = 3 }); return
                end
                BuyStyleWithTween(styleDataMap[selected])
            end
        })
        FightingSection:AddLabel("Mar atual: " .. (currentSeaData and currentSeaData.name or "Desconhecido"))
        FightingSection:AddLabel("Estilos disponiveis: " .. #styleItems)
    end

    local HakiSection = ShopPage:Section({ Name = "Hakis e Habilidades" })
    HakiSection:AddDropdown({
        Name = "Selecione a Habilidade", Flag = "shop_haki",
        Items = { "Geppo - $10,000", "Buso Haki - $25,000", "Soru - $25,000", "Observation Haki - $750,000" },
        Default = getConfig("Selecione a Habilidade", "Geppo - $10,000"),
        Callback = function(Value) setConfig("Selecione a Habilidade", Value); _G.SelectedHaki = Value end
    })
    HakiSection:AddButton({
        Name = "Comprar Habilidade",
        Callback = function()
            local haki = _G.SelectedHaki or "Geppo - $10,000"
            if haki == "Geppo - $10,000" then
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyHaki","Geppo")
            elseif haki == "Buso Haki - $25,000" then
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyHaki","Buso")
            elseif haki == "Soru - $25,000" then
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyHaki","Soru")
            elseif haki == "Observation Haki - $750,000" then
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("KenTalk","Buy")
            end
            Library:Notify({ Name = "Compra", Content = haki .. " comprado com sucesso!", Time = 3 })
        end
    })

    local SwordSection = ShopPage:Section({ Name = "Espadas" })
    SwordSection:AddDropdown({
        Name = "Selecione a Espada", Flag = "shop_sword",
        Items = {
            "Cutlass - $1,000", "Katana - $1,000", "Iron Mace - $25,000",
            "Dual Katana - $12,000", "Triple Katana - $60,000", "Pipe - $100,000",
            "Dual-Headed Blade - $400,000", "Bisento - $1,200,000",
            "Soul Cane - $750,000", "Pole v.2 - 5,000 Frag"
        },
        Default = getConfig("Selecione a Espada", "Cutlass - $1,000"),
        Callback = function(Value) setConfig("Selecione a Espada", Value); _G.SelectedSword = Value end
    })
    SwordSection:AddButton({
        Name = "Comprar Espada",
        Callback = function()
            local sword = _G.SelectedSword or "Cutlass - $1,000"
            local itemName = ""
            if sword == "Cutlass - $1,000" then itemName = "Cutlass"
            elseif sword == "Katana - $1,000" then itemName = "Katana"
            elseif sword == "Iron Mace - $25,000" then itemName = "Iron Mace"
            elseif sword == "Dual Katana - $12,000" then itemName = "Duel Katana"
            elseif sword == "Triple Katana - $60,000" then itemName = "Triple Katana"
            elseif sword == "Pipe - $100,000" then itemName = "Pipe"
            elseif sword == "Dual-Headed Blade - $400,000" then itemName = "Dual-Headed Blade"
            elseif sword == "Bisento - $1,200,000" then itemName = "Bisento"
            elseif sword == "Soul Cane - $750,000" then itemName = "Soul Cane"
            elseif sword == "Pole v.2 - 5,000 Frag" then
                game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ThunderGodTalk")
                Library:Notify({ Name = "Compra", Content = "Pole v.2 comprado!", Time = 3 }); return
            end
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyItem", itemName)
            Library:Notify({ Name = "Compra", Content = sword .. " comprado!", Time = 3 })
        end
    })

    local GunSection = ShopPage:Section({ Name = "Armas de Fogo" })
    GunSection:AddDropdown({
        Name = "Selecione a Arma", Flag = "shop_gun",
        Items = {
            "Slingshot - $5,000", "Musket - $8,000", "Flintlock - $10,500",
            "Refined Slingshot - $30,000", "Refined Flintlock - $65,000",
            "Cannon - $100,000", "Kabucha - 1,500 Frag", "Bizarre Rifle - 250 Ectoplasm"
        },
        Default = getConfig("Selecione a Arma", "Slingshot - $5,000"),
        Callback = function(Value) setConfig("Selecione a Arma", Value); _G.SelectedGun = Value end
    })
    GunSection:AddButton({
        Name = "Comprar Arma",
        Callback = function()
            local gun = _G.SelectedGun or "Slingshot - $5,000"
            local itemName = ""
            if gun == "Slingshot - $5,000" then itemName = "Slingshot"
            elseif gun == "Musket - $8,000" then itemName = "Musket"
            elseif gun == "Flintlock - $10,500" then itemName = "Flintlock"
            elseif gun == "Refined Slingshot - $30,000" then itemName = "Refined Slingshot"
            elseif gun == "Refined Flintlock - $65,000" then itemName = "Refined Flintlock"
            elseif gun == "Cannon - $100,000" then itemName = "Cannon"
            elseif gun == "Kabucha - 1,500 Frag" then
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward","Slingshot","1")
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward","Slingshot","2")
                Library:Notify({ Name = "Compra", Content = "Kabucha comprado!", Time = 3 }); return
            elseif gun == "Bizarre Rifle - 250 Ectoplasm" then
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Ectoplasm", "Buy", 1)
                Library:Notify({ Name = "Compra", Content = "Bizarre Rifle comprado!", Time = 3 }); return
            end
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyItem", itemName)
            Library:Notify({ Name = "Compra", Content = gun .. " comprado!", Time = 3 })
        end
    })

    local BoatSection = ShopPage:Section({ Name = "Barcos" })
    BoatSection:AddDropdown({
        Name = "Selecione o Barco", Flag = "shop_boat",
        Items = { "Pirate Sloop", "Enforcer", "Rocket Boost", "Dinghy", "Pirate Basic", "Pirate Brigade" },
        Default = getConfig("Selecione o Barco", "Pirate Sloop"),
        Callback = function(Value) setConfig("Selecione o Barco", Value); _G.SelectBoat = Value end
    })
    BoatSection:AddButton({
        Name = "Comprar Barco",
        Callback = function()
            local boatMap = {
                ["Pirate Sloop"] = "PirateSloop", ["Enforcer"] = "Enforcer",
                ["Rocket Boost"] = "RocketBoost", ["Dinghy"] = "Dinghy",
                ["Pirate Basic"] = "PirateBasic", ["Pirate Brigade"] = "PirateBrigade"
            }
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyBoat", boatMap[_G.SelectBoat] or "PirateSloop")
            Library:Notify({ Name = "Compra", Content = (_G.SelectBoat or "Pirate Sloop") .. " comprado!", Time = 3 })
        end
    })

    local AcessorioSection = ShopPage:Section({ Name = "Acessorios" })
    AcessorioSection:AddDropdown({
        Name = "Selecione o Acessorio", Flag = "shop_acessorio",
        Items = { "Black Cape - $50,000", "Swordsman Hat - $150,000", "Tomoe Ring - $500,000" },
        Default = getConfig("Selecione o Acessorio", "Black Cape - $50,000"),
        Callback = function(Value) setConfig("Selecione o Acessorio", Value); _G.SelectedAcessorio = Value end
    })
    AcessorioSection:AddButton({
        Name = "Comprar Acessorio",
        Callback = function()
            local item = _G.SelectedAcessorio or "Black Cape - $50,000"
            local itemName = ""
            if item == "Black Cape - $50,000" then itemName = "Black Cape"
            elseif item == "Swordsman Hat - $150,000" then itemName = "Swordsman Hat"
            elseif item == "Tomoe Ring - $500,000" then itemName = "Tomoe Ring"
            end
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyItem", itemName)
            Library:Notify({ Name = "Compra", Content = item .. " comprado!", Time = 3 })
        end
    })

    local StatsShopSection = ShopPage:Section({ Name = "Stats e Racas" })
    StatsShopSection:AddButton({
        Name = "Reset Stats - 2,500 Frag",
        Callback = function()
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward", "Refund", "1")
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward", "Refund", "2")
            Library:Notify({ Name = "Sucesso", Content = "Stats resetados!", Time = 3 })
        end
    })
    StatsShopSection:AddButton({
        Name = "Random Race - 3,000 Frag",
        Callback = function()
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward", "Reroll", "1")
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward", "Reroll", "2")
            Library:Notify({ Name = "Sucesso", Content = "Raca trocada!", Time = 3 })
        end
    })
end)

