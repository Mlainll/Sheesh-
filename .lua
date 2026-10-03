

```
-- [[ PELICAN | The Undead Coming ]]
-- English version
--
-- Infinite Ammo: ALWAYS ON
-- No Recoil: ALWAYS ON
-- Silent Aim: REMOVED
-- No Fire Delay: REMOVED
--
-- RightShift: Show / Hide Menu
-- F8: Stop and Restore

assert(game.PlaceId == 17805166690, "The Undead Coming (2026) only")
assert(type(filtergc) == "function", "This executor must support filtergc")

local env = getgenv()

if env.PelicanUndead then
    env.PelicanUndead.Stop()
end

local loaded, Library = pcall(function()
    local source = game:HttpGet(
        "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/Library.lua"
    )

    local chunk, err = loadstring(source)
    assert(chunk, err)

    return chunk()
end)

assert(
    loaded and type(Library) == "table",
    "Failed to load Obsidian UI: " .. tostring(Library)
)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- =========================================
-- PERMANENT SETTINGS
-- =========================================

local state = {
    Running = true,

    -- Always enabled
    InfiniteAmmo = true,
    NoRecoil = true,
}

env.PelicanUndead = state

-- =========================================
-- STORAGE
-- =========================================

local originals = setmetatable({}, {
    __mode = "k"
})

local recoilServices = setmetatable({}, {
    __mode = "k"
})

local recoilSettings = setmetatable({}, {
    __mode = "k"
})

local connection

-- =========================================
-- UI
-- =========================================

local Window = Library:CreateWindow({
    Title = "PELICAN | The Undead Coming",
    Footer = "Obsidian UI",
    Center = true,
    AutoShow = true,
    Resizable = true,
    ToggleKeybind = Enum.KeyCode.RightShift,
    ShowCustomCursor = false,
})

local Main = Window:AddTab("Combat", "crosshair")
local Settings = Window:AddTab("Settings", "settings")

local Weapons = Main:AddLeftGroupbox("Weapons")
local Status = Main:AddLeftGroupbox("Status")
local Menu = Settings:AddLeftGroupbox("Menu")

-- =========================================
-- WEAPON UI
-- =========================================

Weapons:AddLabel("Infinite Ammo: ON", true)
Weapons:AddLabel("No Recoil: ON", true)

local label = Status:AddLabel(
    "Searching for weapons...",
    true
)

Menu:AddLabel(
    "RightShift: Show / Hide Menu\nF8: Stop and Restore",
    true
)

Menu:AddButton({
    Text = "Stop and Restore",

    Func = function()
        state.Stop()
    end
})

Menu:AddDropdown("UIScale", {
    Text = "UI Scale",
    Values = {
        "75%",
        "100%",
        "125%",
        "150%"
    },
    Default = "100%",

    Callback = function(value)
        Library:SetDPIScale(
            tonumber(
                value:gsub("%%", "")
            )
        )
    end,
})

-- =========================================
-- WEAPON CHECK
-- =========================================

local function eligible(w)
    local tool = rawget(w, "Tool")
    local client = rawget(w, "Client")

    return type(client) == "table"
        and client.Character == player.Character
        and typeof(tool) == "Instance"
        and tool.Parent ~= nil
        and (w.SlotType == "Primary"
            or w.SlotType == "Secondary")
        and w.AmmoType == "Ammo"
        and type(w.MaxAmmo) == "number"
        and w.MaxAmmo > 0
end

-- =========================================
-- RESTORE ORIGINAL WEAPON SETTINGS
-- =========================================

local function restore(w, original)
    w.CostPerShot = original.CostPerShot
    w.CooldownLength = original.CooldownLength
end

-- =========================================
-- NO RECOIL
-- =========================================

local function bindRecoil(w)
    local client = w.Client
    local service = client and client.RecoilService

    if type(w.Recoil) ~= "table"
        or type(service) ~= "table"
        or type(service.Recoil) ~= "function" then

        return false
    end

    recoilSettings[w.Recoil] = true

    if recoilServices[service] then
        return true
    end

    if table.isfrozen(service) then
        return false
    end

    local original = service.Recoil

    local function wrapped(options, ...)
        if state.Running
            and state.NoRecoil
            and type(options) == "table"
            and recoilSettings[options.RecoilSettings] then

            options = table.clone(options)

            -- Remove weapon recoil impulse.
            options.Div = math.huge
        end

        return original(options, ...)
    end

    recoilServices[service] = {
        Original = original,
        Wrapper = wrapped
    }

    service.Recoil = wrapped

    return true
end

-- =========================================
-- APPLY INFINITE AMMO + NO RECOIL
-- =========================================

local function apply()
    local matches = filtergc("table", {
        Keys = {
            "Ammo",
            "MaxAmmo",
            "CooldownLength",
            "CostPerShot"
        },
    }, false)

    local count = 0
    local recoilCount = 0

    for _, w in matches do

        if eligible(w)
            and not table.isfrozen(w) then

            local original = originals[w]

            if not original then
                original = {
                    CostPerShot = w.CostPerShot,
                    CooldownLength = w.CooldownLength
                }

                originals[w] = original
            end

            -- =================================
            -- INFINITE AMMO ALWAYS ON
            -- =================================

            w.CostPerShot = 0

            if not w.Reloading
                and not w.MidReload
                and w.Ammo < w.MaxAmmo then

                w.Ammo = w.MaxAmmo

                if w.Equipped
                    and type(w.UpdateAmmo) == "function" then

                    pcall(
                        w.UpdateAmmo,
                        w
                    )
                end
            end

            -- =================================
            -- NO RECOIL ALWAYS ON
            -- =================================

            if bindRecoil(w) then
                recoilCount += 1
            end

            count += 1
        end
    end

    -- Restore weapons that are no longer valid.
    for w, original in originals do

        if not eligible(w) then
            pcall(
                restore,
                w,
                original
            )

            originals[w] = nil
        end
    end

    label:SetText(
        string.format(
            "Weapons detected: %d\nNo Recoil connected: %d\nInfinite Ammo: ON\nNo Recoil: ON",
            count,
            recoilCount
        )
    )
end

-- =========================================
-- KEY INPUT
-- =========================================

connection = UIS.InputBegan:Connect(
    function(input, processed)

        if processed
            or UIS:GetFocusedTextBox() then

            return
        end

        -- F8 = Stop and restore
        if input.KeyCode == Enum.KeyCode.F8 then
            state.Stop()
            return
        end
    end
)

-- =========================================
-- STOP / RESTORE
-- =========================================

function state.Stop(fromLibrary)

    if not state.Running then
        return
    end

    state.Running = false

    if connection then
        connection:Disconnect()
    end

    -- Restore original weapon values.
    for w, original in originals do
        pcall(
            restore,
            w,
            original
        )
    end

    -- Restore original recoil functions.
    for service, saved in recoilServices do

        if service.Recoil == saved.Wrapper then
            service.Recoil = saved.Original
        end
    end

    if env.PelicanUndead == state then
        env.PelicanUndead = nil
    end

    if not fromLibrary
        and not Library.Unloaded then

        Library:Unload()
    end
end

-- =========================================
-- LIBRARY UNLOAD
-- =========================================

Library:OnUnload(
    function()
        state.Stop(true)
    end
)

-- =========================================
-- MAIN LOOP
-- =========================================

task.spawn(function()

    while state.Running do

        local ok, err = pcall(apply)

        if not ok then
            warn(
                "[PelicanUndead]",
                err
            )

            state.Stop()
            return
        end

        -- Periodic scan for weapons.
        task.wait(0.5)
    end
end)
