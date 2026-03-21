-->> eurys @euryz

local VERSION    = "1.0.0"
local BUILD_DATE = "2026-03-20"

-->>

game.Players.LocalPlayer.Idled:Connect(function()
    local vu = game:GetService("VirtualUser")
    vu:Button2Down(Vector2.new(), workspace.CurrentCamera.CFrame)
    vu:Button2Up(Vector2.new(), workspace.CurrentCamera.CFrame)
end)

-->>

local function InitializeConfiguration()
    local env = getgenv()
    env.eurys = env.eurys or {}
    env.eurys.Obbies     = env.eurys.Obbies     or {}
    env.eurys.Summoning  = env.eurys.Summoning  or {}
    env.eurys.Smithing   = env.eurys.Smithing   or {}
    env.eurys._ActiveJobs = env.eurys._ActiveJobs or {}

    local O = env.eurys.Obbies
    local S = env.eurys.Summoning
    local H = env.eurys.Smithing

    O.Selected   = O.Selected   or {"Crystal Caves"}
    O.AutoRun    = O.AutoRun    or false
    O.LastUsed   = O.LastUsed   or {}

    S.AutoBestPotion   = S.AutoBestPotion   or false
    S.PreferMoneyBoost = S.PreferMoneyBoost or false
    S.SelectedPotion   = S.SelectedPotion   or "Disabled"

    H.AutoEquipBestRelic  = H.AutoEquipBestRelic  or false
    H.AutoUpgradeCheapest = H.AutoUpgradeCheapest or false
    H.CachedCosts         = H.CachedCosts         or {}

    return env.eurys
end

-->>

local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/euryz/euryz/refs/heads/main/archived/wind-ui/main.lua",
    true
))()

local MainWindow = WindUI:CreateWindow({
    Title               = "dakuten",
    Icon                = "eye",
    Author              = "by eurys",
    Folder              = "eurys-agr",
    Size                = UDim2.fromOffset(560, 380),
    MinSize             = Vector2.new(560, 350),
    MaxSize             = Vector2.new(860, 580),
    Transparent         = true,
    Theme               = "Dark",
    Resizable           = true,
    SideBarWidth        = 200,
    BackgroundImageTransparency = 0.44,
    HideSearchBar       = false,
    ScrollBarEnabled    = true,
    User = {
        Enabled    = true,
        Anonymous  = false,
        Callback   = function() end
    }
})

MainWindow:Tag({ Title = "v" .. VERSION,    Icon = "rocket",  Color = Color3.fromHex("#111111"), Radius = 12 })
MainWindow:Tag({ Title = BUILD_DATE,        Icon = "history", Color = Color3.fromHex("#111111"), Radius = 12 })

MainWindow:SetToggleKey(Enum.KeyCode.LeftControl)

MainWindow:OnDestroy(function()
    local cfg = InitializeConfiguration()
    local O = cfg.Obbies
    local S = cfg.Summoning
    local H = cfg.Smithing

    O.Selected   = nil
    O.AutoRun    = nil
    O.LastUsed   = nil

    S.AutoBestPotion   = nil
    S.PreferMoneyBoost = nil
    S.SelectedPotion   = nil

    H.AutoEquipBestRelic  = nil
    H.AutoUpgradeCheapest = nil
    H.CachedCosts         = nil
end)

-->>

local TabSummoning  = MainWindow:Tab({ Title = "Summoning",  Icon = "refresh-ccw", Locked = false })
local TabSmithing   = MainWindow:Tab({ Title = "Smithing",   Icon = "anvil", Locked = false })
local TabTreasuring = MainWindow:Tab({ Title = "Treasuring", Icon = "map-pin-check-inside", Locked = false })

MainWindow:Divider()

local TabSettings = MainWindow:Tab({ Title = "Settings", Icon = "bolt", Locked = true })

TabSummoning:Select()

-->>

do
    local cfg = InitializeConfiguration()

    local Players           = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer       = Players.LocalPlayer

    local CORE_RemoteEvents = ReplicatedStorage:WaitForChild("CORE_RemoteEvents", 12)

    local Remote = {
        Equip    = CORE_RemoteEvents and CORE_RemoteEvents:FindFirstChild("SendEquipRequest"),
        Summon   = CORE_RemoteEvents and CORE_RemoteEvents:FindFirstChild("SendSummonRequest"),
        Purchase = CORE_RemoteEvents and CORE_RemoteEvents:FindFirstChild("SendPurchaseRequest"),
        Upgrade  = CORE_RemoteEvents and CORE_RemoteEvents:FindFirstChild("SendUpgradeRequest")
    }

    local PotionDict  = require(ReplicatedStorage.CORE_ClientModules:WaitForChild("PotionDictionary"))
    local RelicDict   = require(ReplicatedStorage.CORE_ClientModules:WaitForChild("RelicDictionary"))

    -->>

    local function Job_Start(key, executor)
        local token = (cfg._ActiveJobs[key] or 0) + 1
        cfg._ActiveJobs[key] = token

        task.spawn(function()
            executor(function() return cfg._ActiveJobs[key] ~= token end)
        end)
    end

    local function Job_Stop(key)
        cfg._ActiveJobs[key] = (cfg._ActiveJobs[key] or 0) + 1
    end

    local function CountItemsOfName(containerName, itemName)
        local container = LocalPlayer:FindFirstChild(containerName)
        if not container then return 0 end

        local count = 0
        for _, v in ipairs(container:GetChildren()) do
            if v.Name == itemName and (v:IsA("IntValue") or v:IsA("NumberValue")) then
                count += 1
            end
        end
        return count
    end

    local function GetPotionPurchaseCost(name)
        for _, entry in ipairs(PotionDict) do
            if entry[1] == name then return entry[9] or 0 end
        end
        return 0
    end

    -->>

    local LateGamePotionPriority = {
        ["Devil's Deal"]   = 15000,
        ["Mega Shimmer"]   =  8000,
        ["Mega Sunburst"]  =  5700,
        ["Broken Dreams"]  =  2500,
        ["Shimmer"]        =  2000,
    }

    local function GetTopTwoPotions()
        local candidates = {}
        for name, value in pairs(LateGamePotionPriority) do
            local cnt = CountItemsOfName("PotionInventory", name)
            if cnt > 0 then
                table.insert(candidates, {Name = name, Value = value, Count = cnt})
            end
        end

        table.sort(candidates, function(a,b) return a.Value > b.Value end)

        local p1 = candidates[1]
        local p2 = candidates[2]

        if p1 and p1.Count > 1 then return p1.Name, p1.Name end
        if p1 and p2          then return p1.Name, p2.Name end
        if p1                 then return p1.Name, p1.Name end
        return nil, nil
    end

    local function EquipBestAvailablePotions()
        local equipped = LocalPlayer:FindFirstChild("EquippedPotions")
        if not equipped or equipped.Value >= 2 then return end

        local needed = 2 - equipped.Value
        local p1, p2 = GetTopTwoPotions()

        if needed >= 1 and p1 then
            Remote.Equip:FireServer("use_potion", p1)
            task.wait(0.9)
        end
        if needed >= 2 and p2 then
            Remote.Equip:FireServer("use_potion", p2)
            task.wait(0.9)
        end
    end

    local function TryPurchaseBetterLatePotion()
        local cash = LocalPlayer:FindFirstChild("Cash")
        if not cash then return end

        local currentMax = 0
        for name in pairs(LateGamePotionPriority) do
            if CountItemsOfName("PotionInventory", name) > 0 then
                currentMax = math.max(currentMax, LateGamePotionPriority[name])
            end
        end

        local upgrades = {}
        for name, luck in pairs(LateGamePotionPriority) do
            if luck > currentMax then
                local cost = GetPotionPurchaseCost(name)
                if cost > 0 then
                    table.insert(upgrades, {Name = name, Cost = cost, Luck = luck})
                end
            end
        end

        table.sort(upgrades, function(a,b) return a.Luck > b.Luck end)

        for _, entry in ipairs(upgrades) do
            if cash.Value >= entry.Cost then
                Remote.Purchase:FireServer(entry.Name)
                task.wait(1.1)
                return
            end
        end
    end

    local function ManagePotionEquipping()
        local stars = LocalPlayer:FindFirstChild("Stars")
        local isLateGame = stars and stars.Value >= 160

        if cfg.Summoning.AutoBestPotion then
            if isLateGame then
                EquipBestAvailablePotions()
                TryPurchaseBetterLatePotion()
            else
                EquipBestAvailablePotions()
            end
        elseif cfg.Summoning.SelectedPotion ~= "Disabled" then
            local potion = cfg.Summoning.SelectedPotion
            local count  = CountItemsOfName("PotionInventory", potion)
            local eq     = LocalPlayer:FindFirstChild("EquippedPotions")
            if not eq then return end

            local needed = 2 - (eq.Value or 0)
            if needed <= 0 then return end

            local toBuy = math.max(0, needed - count)
            for _ = 1, toBuy do
                Remote.Purchase:FireServer(potion)
                task.wait(0.7)
            end

            for _ = 1, needed do
                Remote.Equip:FireServer("use_potion", potion)
                task.wait(0.6)
            end
        end
    end

    -->>

    local uiAutoBest, uiPreferredPotion

    uiAutoBest = TabSummoning:Toggle({
        Title    = "Auto Best Potions",
        Desc     = "Equip highest summon luck potions available",
        Icon     = "sparkles",
        Type     = "Checkbox",
        Value    = cfg.Summoning.AutoBestPotion,
        Callback = function(state)
            cfg.Summoning.AutoBestPotion = state
            task.defer(function()
                if state and uiPreferredPotion and cfg.Summoning.SelectedPotion ~= "Disabled" then
                    uiPreferredPotion:Select("Disabled")
                end
            end)
        end
    })

    TabSummoning:Toggle({
        Title    = "Prefer Money Boost Potions",
        Desc     = "When auto-equipping, prioritize money potions over luck",
        Icon     = "coins",
        Type     = "Checkbox",
        Value    = cfg.Summoning.PreferMoneyBoost,
        Callback = function(v) cfg.Summoning.PreferMoneyBoost = v end
    })

    uiPreferredPotion = TabSummoning:Dropdown({
        Title    = "Fixed Potion",
        Desc     = "Always try to equip two of this potion (overrides Auto Best)",
        Values   = (function()
            local list = {"Disabled"}
            for _, entry in ipairs(PotionDict) do
                local luck = tonumber(entry[5]) or 0
                local name = entry[1]
                if luck > 0 and not name:find("Key") and not name:find("Boost") then
                    table.insert(list, name)
                end
            end
            return list
        end)(),
        Value    = cfg.Summoning.SelectedPotion,
        Callback = function(selection)
            cfg.Summoning.SelectedPotion = selection
            if selection ~= "Disabled" and cfg.Summoning.AutoBestPotion then
                uiAutoBest:Set(false)
            end
        end
    })

    TabSummoning:Toggle({
        Title    = "Auto Summon",
        Desc     = "Continuously summon without delay",
        Icon     = "fast-forward",
        Type     = "Checkbox",
        Value    = cfg.Summoning.AutoSummon or false,
        Callback = function(enabled)
            cfg.Summoning.AutoSummon = enabled
            local key = "SummonLoop"
            if not enabled then Job_Stop(key) return end

            Job_Start(key, function(shouldTerminate)
                while cfg.Summoning.AutoSummon and not shouldTerminate() do
                    ManagePotionEquipping()
                    if Remote.Summon then
                        Remote.Summon:FireServer(0)
                    end
                    task.wait()
                end
            end)
        end
    })

    -->>

    local ObbyData = {
        ["Crystal Caves"] = {
            Position     = Vector3.new( 139, -85, -264),
            PromptPath   = {"MapFolder", "Obby_CrystalCaves", "PromptPart"},
            KeyName      = "Crystal Key",
            Cooldown     = 20
        },
        ["Flooded Caves"] = {
            Buttons      = {Vector3.new( 18,-87,-25), Vector3.new(151,-87, 12)},
            Position     = Vector3.new( 172, -85, -62),
            PromptPath   = {"MapFolder", "Obby_FloodedCaves", "PromptPart"},
            KeyName      = "Flooded Key",
            Cooldown     = 20
        },
        ["Volcano"] = {
            Position     = Vector3.new( 469,-166, 721),
            PromptPath   = {"MapFolder", "Obby_TheVolcano", "PromptPart"},
            KeyName      = "Molten Key",
            Cooldown     = 42
        },
        ["Frozen Caves"] = {
            Buttons      = {Vector3.new(-26,-155,504), Vector3.new(186,-155,687)},
            Position     = Vector3.new(  73,-157, 451),
            PromptPath   = {"MapFolder", "Obby_FrozenCaves", "PromptPart"},
            KeyName      = "Frozen Key",
            Cooldown     = 42
        }
    }

    local function GetHumanoidRootPart(maxWait)
        maxWait = maxWait or 8
        local t0 = os.clock()
        while os.clock() - t0 < maxWait do
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                return char.HumanoidRootPart
            end
            task.wait(0.04)
        end
        return nil
    end

    local function LocateObbyPrompt(obbyName)
        local data = ObbyData[obbyName]
        if not data or not data.PromptPath then return end

        local current = workspace
        for _, partName in ipairs(data.PromptPath) do
            current = current:FindFirstChild(partName)
            if not current then return end
        end
        return current:FindFirstChildWhichIsA("ProximityPrompt", true)
    end

    local function ActivatePrompt(prompt)
        if not prompt then return false end
        if fireproximityprompt then
            fireproximityprompt(prompt)
            return true
        end
        pcall(prompt.InputHoldBegin, prompt)
        task.wait(prompt.HoldDuration or 0.25)
        pcall(prompt.InputHoldEnd, prompt)
        return true
    end

    local function AttemptUseKey(obbyName)
        local data = ObbyData[obbyName]
        local key = data and data.KeyName
        if not key or key == "" then return false end

        if CountItemsOfName("PotionInventory", key) <= 0 then return false end
        if not Remote.Equip then return false end

        local success = pcall(Remote.Equip.FireServer, Remote.Equip, "use_potion", key)
        if not success then
            for _, method in ipairs({"use_item","use_key","activate","consume","open"}) do
                pcall(Remote.Equip.FireServer, Remote.Equip, method, key)
            end
        end
        return true
    end

    local function ExecuteObby(obbyName, rootPart)
        local data = ObbyData[obbyName]
        if not data then return false end

        if data.Buttons then
            for _, pos in ipairs(data.Buttons) do
                rootPart.CFrame = CFrame.new(pos)
                task.wait(0.12)
            end
        end

        if data.Position then
            rootPart.CFrame = CFrame.new(data.Position)
            AttemptUseKey(obbyName)
            task.wait(0.25)

            local prompt = LocateObbyPrompt(obbyName)
            if prompt then ActivatePrompt(prompt) end

            return true
        end

        return false
    end

    TabTreasuring:Dropdown({
        Title    = "Selected Treasures",
        Desc     = "Choose which obbies / treasures to farm",
        Values   = {"Crystal Caves","Flooded Caves","Volcano","Frozen Caves"},
        Value    = cfg.Obbies.Selected,
        Multi    = true,
        AllowNone = true,
        Callback = function(vals) cfg.Obbies.Selected = vals end
    })

    TabTreasuring:Toggle({
        Title    = "Auto Farm Treasures",
        Desc     = "Automatically complete selected obbies on cooldown",
        Icon     = "sparkles",
        Type     = "Checkbox",
        Value    = cfg.Obbies.AutoRun,
        Callback = function(enabled)
            cfg.Obbies.AutoRun = enabled
            local key = "TreasureFarm"
            if not enabled then Job_Stop(key) return end

            Job_Start(key, function(shouldTerminate)
                while cfg.Obbies.AutoRun and not shouldTerminate() do
                    local targets = cfg.Obbies.Selected or {}
                    if #targets == 0 then task.wait(5.5) continue end

                    local hrp = GetHumanoidRootPart(7.5)
                    if not hrp then task.wait(1.8) continue end

                    local now = os.clock()
                    local anyAction = false

                    for _, name in ipairs(targets) do
                        local last = cfg.Obbies.LastUsed[name] or 0
                        local cd   = ObbyData[name].Cooldown or 20

                        if now - last >= cd then
                            if ExecuteObby(name, hrp) then
                                cfg.Obbies.LastUsed[name] = now
                                anyAction = true
                            end
                            task.wait(1.3)
                        end
                    end

                    if not anyAction then task.wait(4.5) end
                end
            end)
        end
    })

    -->>

    local function FindHighestLuckRelic()
        local inv = LocalPlayer:FindFirstChild("RelicInventory")
        if not inv then return nil end

        local bestName, bestScore = nil, -1

        for _, item in ipairs(inv:GetChildren()) do
            if item:IsA("IntValue") or item:IsA("NumberValue") then
                for _, entry in ipairs(RelicDict) do
                    if entry[1] == item.Name then
                        local score = tonumber(entry[4]) or tonumber(entry[5]) or 0
                        if score > bestScore then
                            bestScore = score
                            bestName  = item.Name
                        end
                        break
                    end
                end
            end
        end
        return bestName
    end

    local function EquipBestRelic()
        local best = FindHighestLuckRelic()
        if not best then return end

        local slot1 = LocalPlayer:FindFirstChild("EquippedRelic1")
        if not slot1 or slot1.Value == best then return end

        if slot1.Value and slot1.Value ~= "" then
            Remote.Equip:FireServer("unequip_relic", slot1.Value)
            task.wait(0.45)
        end

        Remote.Equip:FireServer("equip_relic", best, 1)
    end

    --
    Remote.Upgrade.OnClientEvent:Connect(function(action, value)
        if action == "get_cost" and type(value) == "number" then
            if cfg.Smithing.LastRequestedChar then
                cfg.Smithing.CachedCosts[cfg.Smithing.LastRequestedChar] = value
            end
        end
    end)

    local function FindCheapestUpgradeTarget()
        local inv = LocalPlayer:FindFirstChild("CharacterInventory")
        if not inv then return nil end

        local target, lowestCost = nil, math.huge

        for _, char in ipairs(inv:GetChildren()) do
            if (char:IsA("IntValue") or char:IsA("NumberValue")) and char.Value < 5 then
                cfg.Smithing.LastRequestedChar = char.Name
                Remote.Upgrade:FireServer("get_cost", char.Name)
                task.wait(0.16)

                local cost = cfg.Smithing.CachedCosts[char.Name] or math.huge
                if cost < lowestCost then
                    lowestCost = cost
                    target = char.Name
                end
            end
        end
        return target
    end

    local function TryUpgradeCheapestCharacter()
        local target = FindCheapestUpgradeTarget()
        if not target then return end

        local cash = LocalPlayer:FindFirstChild("Cash")
        local cost = cfg.Smithing.CachedCosts[target] or math.huge

        if cash and cash.Value >= cost then
            Remote.Upgrade:FireServer("upgrade", target)
        end
    end

    TabSmithing:Toggle({
        Title    = "Auto Equip Best Relic",
        Desc     = "Always keep the highest luck relic equipped",
        Icon     = "gem",
        Type     = "Checkbox",
        Value    = cfg.Smithing.AutoEquipBestRelic,
        Callback = function(v) cfg.Smithing.AutoEquipBestRelic = v end
    })

    TabSmithing:Toggle({
        Title    = "Auto Upgrade Characters",
        Desc     = "Upgrade cheapest available character to ★5 repeatedly",
        Icon     = "star",
        Type     = "Checkbox",
        Value    = cfg.Smithing.AutoUpgradeCheapest,
        Callback = function(v) cfg.Smithing.AutoUpgradeCheapest = v end
    })

    -->>

    task.spawn(function()
        while true do
            task.wait(4.8)

            if cfg.Summoning.AutoBestPotion then
                EquipBestAvailablePotions()
            end

            if cfg.Smithing.AutoEquipBestRelic then
                EquipBestRelic()
            end

            if cfg.Smithing.AutoUpgradeCheapest then
                TryUpgradeCheapestCharacter()
            end
        end
    end)
end
