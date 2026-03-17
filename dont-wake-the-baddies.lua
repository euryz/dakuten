-->> @euryz on GitHub.
-->> Yes, I am leaving debug code in here.

-->> F to toggle on/off.
-->> It's best not to execute more than once.

-->> Highly catered to my preference, edit the script to change whatever you don't like.

getgenv().Eurys = setmetatable({
    AutoTake = false,
    DebounceTime = 5,
    ReturnPosition = CFrame.new(-24, 4, 6)
}, {})

getgenv().Eurys._version = (getgenv().Eurys._version or 0) + 1
local SCRIPT_VERSION = getgenv().Eurys._version

-->>

local TargetRarities = { -->> Change the rarities you're looking for here.
    ['Legendary'] = true,
    ['Mythic'] = true,
    ['Divine'] = true,
    ['Secret'] = true
}

-->>

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInputService = game:GetService('UserInputService')

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local NPCFolder = workspace.Map.Zones.Field.NPC

local Notification = loadstring(game:HttpGet('https://raw.githubusercontent.com/euryz/euryz/refs/heads/main/archived/JxereasNotifications.lua', true))()

local Registry = require(ReplicatedStorage:WaitForChild('Shared'):WaitForChild('Registry'))
local DataAggregation = require(
    LocalPlayer:WaitForChild('PlayerScripts')
        :WaitForChild('ClientLoader')
        :WaitForChild('Modules')
        :WaitForChild('DataAggregation')
)

local Replica = DataAggregation.WaitForReplica()

-->>

local NameToId = {}
for _, Data in ipairs(Registry.NPCOrdered) do
    NameToId[Data.DisplayName] = Data.Id
end

local LastHitRegistry = {}

-->>

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F then
        getgenv().Eurys.AutoTake = not getgenv().Eurys.AutoTake
        Notification.new('info', '[eurys] AutoTake', 'AutoTake is now ' .. (getgenv().Eurys.AutoTake and 'ON.' or 'OFF.'), true, 2)
    end
end)

-->>

local function GetVariant(NPCModel)
    local Torso = NPCModel:FindFirstChild('Torso')
    if not Torso then return 'Normal' end

    local FirstColor = Torso.Color
    task.wait(0.1)
    local SecondColor = Torso.Color

    if FirstColor ~= SecondColor then
        return 'Rainbow'
    end

    if FirstColor == Color3.fromRGB(255,217,0) then
        return 'Gold'
    elseif FirstColor == Color3.fromRGB(0,166,255) then
        return 'Diamond'
    else
        return 'Normal'
    end
end

-->>

local function IsMissing(NPCName, Variant)
    local Id = NameToId[NPCName]
    if not Id then return false end

    local Tab = Replica.Data.Index[Variant]
    if not Tab then return false end

    return not Tab[Id]
end

-->>

local function EquipCloak()
    local Backpack = LocalPlayer:FindFirstChild('Backpack')
    if not Backpack then return end

    task.wait(1)
    for _, Tool in ipairs(Character:GetChildren()) do
        if Tool:IsA('Tool') then
            Tool.Parent = Backpack
        end
    end

    local Cloak = Backpack:FindFirstChild('InvisibilityCloak')
    if Cloak then
        Cloak.Parent = Character
        print('[eurys] Cloak Equipped')
    else
        print('[eurys] Cloak Missing')
    end
end

-->>

local function GetPriority(Rarity, Missing, Variant)
    if Rarity == 'Secret' then
        return 5, 'Priority 5 - Secret'
    elseif Rarity == 'Divine' then
        return 4, 'Priority 4 - Divine'
    elseif Missing then
        return 3, 'Priority 3 - ' .. Variant .. ' Index'
    elseif Variant == 'Rainbow' then
        return 2, 'Priority 2 - Rainbow'
    elseif TargetRarities[Rarity] then
        return 1, 'Priority 1 - ' .. Rarity
    end

    return 0, 'Ignored'
end

-->>

task.spawn(function()
    while SCRIPT_VERSION == getgenv().Eurys._version do
        if getgenv().Eurys.AutoTake then
            for _, NPCModel in ipairs(NPCFolder:GetChildren()) do
                
                local Attachment = NPCModel:FindFirstChild('OverheadAttachment')
                if not Attachment then continue end

                local CharacterInfo = Attachment:FindFirstChild('CharacterInfo')
                if not CharacterInfo or not CharacterInfo:FindFirstChild('Frame') then continue end

                local Frame = CharacterInfo.Frame
                local Rarity = Frame.Rarity.Text
                local NPCName = Frame.CharacterName.Text

                local Variant = GetVariant(NPCModel)
                local Missing = IsMissing(NPCName, Variant)

                local Priority, Reason = GetPriority(Rarity, Missing, Variant)

                print('[eurys][SCAN]', NPCName, '|', Rarity, '|', Variant, '| Missing:', Missing)

                if Priority > 0 then
                    warn('[eurys][VALID HIT]', NPCName, '|', Reason)

                    if Rarity == 'Secret' then
                        Notification.new('success', '[eurys] Secret Found!', NPCName .. ' | ' .. Reason)
                    else
                        Notification.new('success', '[eurys] Valid Hit', NPCName .. ' | ' .. Reason, true, 2)
                    end

                    local Identifier = NPCModel:GetDebugId()

                    if LastHitRegistry[Identifier] and (tick() - LastHitRegistry[Identifier] < getgenv().Eurys.DebounceTime) then
                        print('[eurys][SKIP - DEBOUNCE]', NPCName)
                        continue
                    end

                    local PromptFolder = NPCModel:FindFirstChild('Prompts')
                    if not PromptFolder then continue end

                    local Prompt = PromptFolder:FindFirstChild('Pickup')
                    if not Prompt or not Prompt:IsA('ProximityPrompt') then continue end

                    local Root = Character:FindFirstChild('HumanoidRootPart')
                    if not Root then continue end

                    LastHitRegistry[Identifier] = tick()

                    print('[eurys][TAKING]', NPCName, '|', Reason)

                    Root.CFrame = NPCModel:GetPivot()
                    task.wait(0.3)

                    fireproximityprompt(Prompt)
                    task.wait(0.4)

                    Root.CFrame = getgenv().Eurys.ReturnPosition

                    EquipCloak()

                    task.wait(0.2)
                end
            end
        end

        task.wait(0.15)
    end
end)
