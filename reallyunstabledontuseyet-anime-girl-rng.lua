-->>  eurys @euryz
-->> loadstring(game:HttpGet('https://raw.githubusercontent.com/euryz/dakuten/refs/heads/main/reallyunstabledontuseyet-anime-girl-rng.lua'))()

local VERSION    = "1.0.0"
local BUILD_DATE = "2026-03-21"

-->>

loadstring(game:HttpGet("https://raw.githubusercontent.com/euryz/euryz/refs/heads/main/archived/simple-antiafk.lua"))()

-->> 

local function GetConfiguration()
    local env = getgenv()
    env.eurys = env.eurys or {}
    env.eurys.Obbies     = env.eurys.Obbies     or {}
    env.eurys.Summoning  = env.eurys.Summoning  or {}
    env.eurys.Smithing   = env.eurys.Smithing   or {}
    env.eurys._Jobs      = env.eurys._Jobs      or {}

    local obbies    = env.eurys.Obbies
    local summoning = env.eurys.Summoning
    local smithing  = env.eurys.Smithing

    obbies.SelectedObbies     = obbies.SelectedObbies     or {"Crystal Caves"}
    obbies.AutomaticCompletion = obbies.AutomaticCompletion or false
    obbies.LastUsed           = obbies.LastUsed           or {}

    summoning.AutoSummon       = summoning.AutoSummon       or false
    summoning.AutoBestPotions  = summoning.AutoBestPotions  or false
    summoning.UseMoneyPotions  = summoning.UseMoneyPotions  or false
    summoning.SelectedPotion   = summoning.SelectedPotion   or "Disabled"

    smithing.AutoEquipBestRelic = smithing.AutoEquipBestRelic or false
    smithing.AutoUpgradeChars   = smithing.AutoUpgradeChars   or false
    smithing.Costs              = smithing.Costs              or {}

    return env.eurys
end

-->> 

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/euryz/euryz/refs/heads/main/archived/wind-ui/main.lua", true))()

local Window = WindUI:CreateWindow({
    Title               = "dakuten",
    Icon                = "eye",
    Author              = "by eurys",
    Folder              = "eurys-agr",
    Size                = UDim2.fromOffset(550, 370),
    MinSize             = Vector2.new(560, 350),
    MaxSize             = Vector2.new(850, 560),
    Transparent         = true,
    Theme               = "Dark",
    Resizable           = true,
    SideBarWidth        = 200,
    BackgroundImageTransparency = 0.42,
    HideSearchBar       = false,
    ScrollBarEnabled    = true,
    User = {
        Enabled    = true,
        Anonymous  = false,
        Callback   = function() end
    },
})

Window:Tag({Title = "v" .. VERSION,   Icon = "rocket",  Color = Color3.fromHex("#000000"), Radius = 13})
Window:Tag({Title = BUILD_DATE,       Icon = "history", Color = Color3.fromHex("#000000"), Radius = 13})

Window:SetToggleKey(Enum.KeyCode.LeftControl)

Window:OnDestroy(function()
    local cfg = GetConfiguration()
    local obbies    = cfg.Obbies
    local summoning = cfg.Summoning
    local smithing  = cfg.Smithing

    obbies.SelectedObbies      = nil
    obbies.AutomaticCompletion = nil
    obbies.LastUsed            = nil

    summoning.AutoSummon      = nil
    summoning.AutoBestPotions = nil
    summoning.UseMoneyPotions = nil
    summoning.SelectedPotion  = nil

    smithing.AutoEquipBestRelic = nil
    smithing.AutoUpgradeChars   = nil
    smithing.Costs              = nil
end)

-->> 

local SummoningTab  = Window:Tab({Title = "Summoning",  Icon = "refresh-ccw", Locked = false})
local SmithingTab   = Window:Tab({Title = "Smithing",   Icon = "anvil",       Locked = false})
local TreasuringTab = Window:Tab({Title = "Treasuring", Icon = "map-pin-check-inside", Locked = false})

Window:Divider()

local SettingsTab = Window:Tab({Title = "Settings", Icon = "bolt", Locked = true})

SummoningTab:Select()

-->>

do
    local cfg = GetConfiguration()

    local Players           = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local LocalPlayer       = Players.LocalPlayer

    local CORE_RemoteEvents = ReplicatedStorage:WaitForChild("CORE_RemoteEvents", 10)

    local SendEquipRequest   = CORE_RemoteEvents and CORE_RemoteEvents:FindFirstChild("SendEquipRequest")
    local SendSummonRequest  = CORE_RemoteEvents and CORE_RemoteEvents:FindFirstChild("SendSummonRequest")
    local SendPurchaseRequest = CORE_RemoteEvents and CORE_RemoteEvents:FindFirstChild("SendPurchaseRequest")
    local SendUpgradeRequest  = CORE_RemoteEvents and CORE_RemoteEvents:FindFirstChild("SendUpgradeRequest")

    local PotionDictionary = require(game.ReplicatedStorage.CORE_ClientModules:WaitForChild("PotionDictionary"))

    local LateGamePotions = {
        ["Devil's Deal"]  = 15000,
        ["Mega Shimmer"]  = 8000,
        ["Mega Sunburst"] = 5700,
        ["Broken Dreams"] = 2500,
        ["Shimmer"]       = 2000,
    }

    local CanFireTouch   = firetouchinterest   ~= nil
    local CanFirePrompt  = fireproximityprompt ~= nil

    -->>

    local function StopJob(key)
        cfg._Jobs[key] = (cfg._Jobs[key] or 0) + 1
    end

    local function StartJob(key, executor)
        cfg._Jobs[key] = (cfg._Jobs[key] or 0) + 1
        local token = cfg._Jobs[key]

        task.spawn(function()
            executor(function() return cfg._Jobs[key] ~= token end)
        end)
    end

    -->>

    local function GetItemCount(name)
        local inv = LocalPlayer:FindFirstChild("PotionInventory")
        if not inv then return 0 end

        local count = 0
        for _, child in ipairs(inv:GetChildren()) do
            if child.Name == name and (child:IsA("IntValue") or child:IsA("NumberValue")) then
                count += 1
            end
        end
        return count
    end

    local function GetKeyCount(keyName)
        return GetItemCount(keyName)
    end

    local function GetPotionCost(name)
        for _, data in ipairs(PotionDictionary) do
            if data[1] == name then
                return data[9] or 0
            end
        end
        return 0
    end

    -->>

    local function GetBestPotions()
        local candidates = {}
        for name, value in pairs(LateGamePotions) do
            local count = GetItemCount(name)
            if count > 0 then
                table.insert(candidates, {Name = name, Value = value, Count = count})
            end
        end

        table.sort(candidates, function(a,b) return a.Value > b.Value end)

        local p1 = candidates[1]
        local p2 = candidates[2]

        if p1 and p1.Count > 1 then return p1.Name, p1.Name end
        if p1 and p2         then return p1.Name, p2.Name end
        if p1                then return p1.Name, p1.Name end
        return nil, nil
    end

    local function LateGamePotionLogic()
        local equipped = LocalPlayer:FindFirstChild("EquippedPotions")
        if not equipped then return end

        local current = equipped.Value or 0
        if current >= 2 then return end

        local needed = 2 - current
        local p1, p2 = GetBestPotions()

        if needed >= 1 and p1 then
            SendEquipRequest:FireServer("use_potion", p1)
            task.wait(1)
        end
        if needed >= 2 and p2 then
            SendEquipRequest:FireServer("use_potion", p2)
            task.wait(1)
        end
    end

    local function BuyBetterLateGamePotion()
        local cash = LocalPlayer:FindFirstChild("Cash")
        if not cash then return end

        local currentBest = 0
        for name, luck in pairs(LateGamePotions) do
            if GetItemCount(name) > 0 then
                currentBest = math.max(currentBest, luck)
            end
        end

        local upgrades = {}
        for name, luck in pairs(LateGamePotions) do
            if luck > currentBest then
                local cost = GetPotionCost(name)
                if cost > 0 then
                    table.insert(upgrades, {Name = name, Cost = cost, Luck = luck})
                end
            end
        end

        table.sort(upgrades, function(a,b) return a.Luck > b.Luck end)

        for _, potion in ipairs(upgrades) do
            if cash.Value >= potion.Cost then
                SendPurchaseRequest:FireServer(potion.Name)
                task.wait(1)
                return
            end
        end
    end

    local function EquipBestPotions()
        local equipped = LocalPlayer:FindFirstChild("EquippedPotions")
        if not equipped then return end

        local current = equipped.Value or 0
        if current >= 2 then return end

        local needed = 2 - current
        local p1, p2 = GetBestPotions()

        if needed >= 1 and p1 then SendEquipRequest:FireServer("use_potion", p1) task.wait(1) end
        if needed >= 2 and p2 then SendEquipRequest:FireServer("use_potion", p2) task.wait(1) end
    end

    local function EnsurePotions()
        local equipped = LocalPlayer:FindFirstChild("EquippedPotions")
        if not equipped then return end

        local stars = LocalPlayer:FindFirstChild("Stars")
        local isLateGame = stars and stars.Value >= 160

        if cfg.Summoning.AutoBestPotions then
            if isLateGame then
                LateGamePotionLogic()
                BuyBetterLateGamePotion()
            else
                EquipBestPotions()
            end
        elseif cfg.Summoning.SelectedPotion ~= "Disabled" then
            local potion = cfg.Summoning.SelectedPotion
            local count  = GetItemCount(potion)
            local current = equipped.Value or 0
            local needed  = 2 - current

            if needed > 0 then
                local toBuy = math.max(0, needed - count)
                for _ = 1, toBuy do
                    SendPurchaseRequest:FireServer(potion)
                end
                for _ = 1, needed do
                    SendEquipRequest:FireServer("use_potion", potion)
                end
            end
        end
    end

    -->>

    local potionNames = {"Disabled"}
    for _, data in ipairs(PotionDictionary) do
        local luck = tonumber(data[5]) or 0
        local name = data[1]
        if luck > 0 and not name:find("Key") and not name:find("Boost") then
            table.insert(potionNames, name)
        end
    end

    local autoBestToggle
    local preferredDropdown

    autoBestToggle = SummoningTab:Toggle({
        Title    = "Auto Best Potions",
        Desc     = "Automatically equips highest summon luck potions available",
        Icon     = "sparkles",
        Value    = cfg.Summoning.AutoBestPotions,
        Callback = function(v)
            cfg.Summoning.AutoBestPotions = v
            task.defer(function()
                if v and preferredDropdown and cfg.Summoning.SelectedPotion ~= "Disabled" then
                    preferredDropdown:Select("Disabled")
                end
            end)
        end
    })

    SummoningTab:Toggle({
        Title    = "Use Money Boost Potions",
        Desc     = "Prioritize money potions over luck when auto-equipping",
        Icon     = "coins",
        Value    = cfg.Summoning.UseMoneyPotions,
        Callback = function(v) cfg.Summoning.UseMoneyPotions = v end
    })

    preferredDropdown = SummoningTab:Dropdown({
        Title    = "Preferred Potion",
        Desc     = "Force-equip two of the selected potion (overrides Auto Best)",
        Values   = potionNames,
        Value    = cfg.Summoning.SelectedPotion,
        Callback = function(v)
            cfg.Summoning.SelectedPotion = v
            if v ~= "Disabled" and cfg.Summoning.AutoBestPotions then
                autoBestToggle:Set(false)
            end
        end
    })

    SummoningTab:Toggle({
        Title    = "Auto Summon",
        Desc     = "Continuously summon with minimal delay",
        Icon     = "fast-forward",
        Value    = cfg.Summoning.AutoSummon,
        Callback = function(enabled)
            cfg.Summoning.AutoSummon = enabled
            local jobKey = "AutoSummon"

            if not enabled then
                StopJob(jobKey)
                return
            end

            StartJob(jobKey, function(shouldStop)
                while cfg.Summoning.AutoSummon and not shouldStop() do
                    EnsurePotions()
                    if SendSummonRequest then
                        SendSummonRequest:FireServer(0)
                    end
                    task.wait()
                end
            end)
        end
    })

    -->>

    local ObbyData = {
        ["Crystal Caves"] = {
            Position      = Vector3.new(139, -85, -264),
            PromptPath    = {"MapFolder", "Obby_CrystalCaves", "PromptPart"},
            KeyName       = "Crystal Key",
            Cooldown      = 20,
        },
        ["Flooded Caves"] = {
            Buttons = {
                {Position = Vector3.new(18, -87, -25),  Path = {"MapFolder", "Obby_FloodedCaves", "Button1", "TouchPart"}},
                {Position = Vector3.new(151,-87, 12),   Path = {"MapFolder", "Obby_FloodedCaves", "Button2", "TouchPart"}},
            },
            Position      = Vector3.new(172, -85, -62),
            PromptPath    = {"MapFolder", "Obby_FloodedCaves", "PromptPart"},
            KeyName       = "Flooded Key",
            Cooldown      = 20,
        },
        ["Volcano"] = {
            Position      = Vector3.new(469, -166, 721),
            PromptPath    = {"MapFolder", "Obby_TheVolcano", "PromptPart"},
            KeyName       = "Molten Key",
            Cooldown      = 42,
        },
        ["Frozen Caves"] = {
            Buttons = {
                {Position = Vector3.new(-26, -155, 504), Path = {"MapFolder", "Obby_FrozenCaves", "Button1", "TouchPart"}},
                {Position = Vector3.new(186, -155, 687), Path = {"MapFolder", "Obby_FrozenCaves", "Button2", "TouchPart"}},
            },
            Position      = Vector3.new(73, -157, 451),
            PromptPath    = {"MapFolder", "Obby_FrozenCaves", "PromptPart"},
            KeyName       = "Frozen Key",
            Cooldown      = 42,
        },
    }

    local function GetHumanoidRootPart(timeout)
        timeout = timeout or 8
        local t0 = os.clock()
        while os.clock() - t0 < timeout do
            local char = LocalPlayer.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                return char.HumanoidRootPart
            end
            task.wait(0.05)
        end
        return nil
    end

    local function ResolvePrompt(obbyName)
        local data = ObbyData[obbyName]
        if not data or not data.PromptPath then return nil end

        local node = workspace
        for _, part in ipairs(data.PromptPath) do
            node = node:FindFirstChild(part)
            if not node then return nil end
        end
        return node:FindFirstChildWhichIsA("ProximityPrompt", true)
    end

    local function FirePrompt(prompt)
        if not prompt then return false end

        if CanFirePrompt then
            fireproximityprompt(prompt)
            return true
        else
            local originalHold = prompt.HoldDuration
            prompt.HoldDuration = 0
            pcall(prompt.InputHoldBegin, prompt)
            pcall(prompt.InputHoldEnd, prompt)
            prompt.HoldDuration = originalHold
            return true
        end
    end

    local function TryUseKey(obbyName)
        local data = ObbyData[obbyName]
        local key  = data and data.KeyName
        if not key or key == "" then return false end

        if GetKeyCount(key) <= 0 then return false end
        if not SendEquipRequest then return false end

        local success = pcall(SendEquipRequest.FireServer, SendEquipRequest, "use_potion", key)
        if not success then
            for _, method in ipairs({"use_item","use_key","activate","consume","open"}) do
                pcall(SendEquipRequest.FireServer, SendEquipRequest, method, key)
            end
        end

        return true
    end

    local function ProcessObby(obbyName, hrp)
        local data = ObbyData[obbyName]
        if not data then return false end

        if data.Buttons then
            for _, btn in ipairs(data.Buttons) do
                if CanFireTouch then
                    local node = workspace
                    for _, name in ipairs(btn.Path) do
                        node = node:FindFirstChild(name)
                        if not node then break end
                    end
                    if node and node:IsA("BasePart") then
                        firetouchinterest(hrp, node, 0)
                        task.wait()
                        firetouchinterest(hrp, node, 1)
                    end
                else
                    hrp.CFrame = CFrame.new(btn.Position)
                end
                task.wait(0.1)
            end
        end

        if data.Position then
            hrp.CFrame = CFrame.new(data.Position)
            TryUseKey(obbyName)
            task.wait(0.2)

            local prompt = ResolvePrompt(obbyName)
            if prompt then FirePrompt(prompt) end

            return true
        end

        return false
    end

    -->>

    TreasuringTab:Dropdown({
        Title     = "Treasures to Collect",
        Desc      = "Select dungeons to farm (multi-select supported)",
        Values    = {"Crystal Caves", "Flooded Caves", "Volcano", "Frozen Caves"},
        Value     = cfg.Obbies.SelectedObbies,
        Multi     = true,
        AllowNone = true,
        Callback  = function(vals) cfg.Obbies.SelectedObbies = vals end
    })

    TreasuringTab:Toggle({
        Title    = "Auto Collect Treasure",
        Desc     = "Automatically completes selected obbies / treasure farms",
        Icon     = "sparkles",
        Value    = cfg.Obbies.AutomaticCompletion,
        Callback = function(enabled)
            cfg.Obbies.AutomaticCompletion = enabled
            local jobKey = "MultiTreasureFarm"

            if not enabled then
                StopJob(jobKey)
                return
            end

            StartJob(jobKey, function(shouldStop)
                while cfg.Obbies.AutomaticCompletion and not shouldStop() do
                    local selected = cfg.Obbies.SelectedObbies or {}
                    if #selected == 0 then task.wait(6) continue end

                    local hrp = GetHumanoidRootPart(8)
                    if not hrp then task.wait(1.5) continue end

                    local now = os.clock()
                    local anySuccess = false

                    for _, name in ipairs(selected) do
                        local last = cfg.Obbies.LastUsed[name] or 0
                        local cd   = ObbyData[name].Cooldown or 20

                        if now - last >= cd then
                            if ProcessObby(name, hrp) then
                                cfg.Obbies.LastUsed[name] = now
                                anySuccess = true
                            end
                            task.wait(1.2)
                        end
                    end

                    if not anySuccess then task.wait(5) end
                end
            end)
        end
    })

    -->>

    local function GetBestRelic()
        local inv = LocalPlayer:FindFirstChild("RelicInventory")
        if not inv then return nil end

        local best, bestValue = nil, -1
        local dict = require(game.ReplicatedStorage.CORE_ClientModules.RelicDictionary)

        for _, relic in ipairs(inv:GetChildren()) do
            if relic:IsA("IntValue") or relic:IsA("NumberValue") then
                for _, entry in ipairs(dict) do
                    if entry[1] == relic.Name then
                        local val = tonumber(entry[4]) or tonumber(entry[5]) or 0
                        if val > bestValue then
                            bestValue = val
                            best = relic.Name
                        end
                        break
                    end
                end
            end
        end
        return best
    end

    local function AutoEquipBestRelic()
        local best = GetBestRelic()
        if not best then return end

        local slot1 = LocalPlayer:FindFirstChild("EquippedRelic1")
        if not slot1 or slot1.Value == best then return end

        if slot1.Value ~= "" then
            SendEquipRequest:FireServer("unequip_relic", slot1.Value)
            task.wait(0.4)
        end

        SendEquipRequest:FireServer("equip_relic", best, 1)
    end

    SendUpgradeRequest.OnClientEvent:Connect(function(action, value)
        if action == "get_cost" and type(value) == "number" then
            if cfg.Smithing.LastRequestedChar then
                cfg.Smithing.Costs[cfg.Smithing.LastRequestedChar] = value
            end
        end
    end)

    local function GetCheapestUpgradeableCharacter()
        local inv = LocalPlayer:FindFirstChild("CharacterInventory")
        if not inv then return nil end

        local target, minCost = nil, math.huge

        for _, char in ipairs(inv:GetChildren()) do
            if (char:IsA("IntValue") or char:IsA("NumberValue")) and char.Value < 5 then
                cfg.Smithing.LastRequestedChar = char.Name
                SendUpgradeRequest:FireServer("get_cost", char.Name)
                task.wait(0.15)

                local cost = cfg.Smithing.Costs[char.Name] or math.huge
                if cost < minCost then
                    minCost = cost
                    target  = char.Name
                end
            end
        end

        return target
    end

    local function AutoUpgradeCharacters()
        local target = GetCheapestUpgradeableCharacter()
        if not target then return end

        local cash = LocalPlayer:FindFirstChild("Cash")
        local cost = cfg.Smithing.Costs[target] or math.huge

        if cash and cash.Value >= cost then
            SendUpgradeRequest:FireServer("upgrade", target)
        end
    end

    -->>

    SmithingTab:Toggle({
        Title    = "Auto Equip Best Relic",
        Desc     = "Equip highest luck relic (unequips current if necessary)",
        Icon     = "gem",
        Value    = cfg.Smithing.AutoEquipBestRelic,
        Callback = function(v) cfg.Smithing.AutoEquipBestRelic = v end
    })

    SmithingTab:Toggle({
        Title    = "Auto Upgrade Cheapest Character",
        Desc     = "Upgrades lowest-cost character to 5★ then moves to next",
        Icon     = "star",
        Value    = cfg.Smithing.AutoUpgradeChars,
        Callback = function(v) cfg.Smithing.AutoUpgradeChars = v end
    })

    -->>

    task.spawn(function()
        while true do
            task.wait(5)

            if cfg.Summoning.AutoBestPotions then
                EquipBestPotions()
            end

            if cfg.Smithing.AutoEquipBestRelic then
                AutoEquipBestRelic()
            end

            if cfg.Smithing.AutoUpgradeChars then
                AutoUpgradeCharacters()
            end
        end
    end)
end
