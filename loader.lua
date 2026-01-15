-- Macr0 Hub Loader
-- Secure key validation system
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local API_URL = "https://keyauth.macr0.dev/api/v1/validate"

-- Configuration
local HUB_FOLDER = "Macr0_Hub"
local KEY_FILE = HUB_FOLDER .. "/key.txt"

-- Game scripts mapping
local GAME_SCRIPTS = {
    [1547610457] = "https://raw.githubusercontent.com/Macro002/Macr0-Hub-Scripts/main/freedraw.lua", -- FreeDraw game
}

-- Create hub folder if it doesn't exist
if not isfolder(HUB_FOLDER) then
    makefolder(HUB_FOLDER)
end

-- Function to get saved key
local function getSavedKey()
    if isfile(KEY_FILE) then
        return readfile(KEY_FILE)
    end
    return nil
end

-- Function to save key
local function saveKey(key)
    writefile(KEY_FILE, key)
end

-- Function to validate key with API
local function validateKey(key)
    -- Try multiple HTTP request methods
    local requestMethods = {
        function() return syn and syn.request end,
        function() return http and http.request end,
        function() return http_request end,
        function() return request end,
        function() return syn and syn.http and syn.http.request end,
    }

    local requestFunc = nil
    for _, method in ipairs(requestMethods) do
        local func = method()
        if func then
            requestFunc = func
            break
        end
    end

    if not requestFunc then
        return false, {message = "HTTP not supported"}
    end

    local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
    local robloxId = tostring(player.UserId)
    local robloxUsername = player.Name
    local url = API_URL .. "?key=" .. key .. "&hwid=" .. hwid .. "&roblox_id=" .. robloxId .. "&roblox_username=" .. HttpService:UrlEncode(robloxUsername)

    local success, valid, data = pcall(function()
        local response = requestFunc({ Url = url, Method = "GET" })

        if response.StatusCode == 200 then
            local responseData = HttpService:JSONDecode(response.Body)
            return responseData.valid == true, responseData
        elseif response.StatusCode == 404 then
            return false, {message = "Invalid license key"}
        elseif response.StatusCode == 403 then
            local responseData = HttpService:JSONDecode(response.Body)
            return false, {message = responseData.reason or "Access denied"}
        else
            return false, {message = "Server error"}
        end
    end)

    if not success then
        return false, {message = "Connection failed"}
    end

    return valid, data or {message = "Unknown error"}
end

-- Function to load game script
local function loadGameScript()
    local gameId = game.PlaceId
    local scriptUrl = GAME_SCRIPTS[gameId]

    if not scriptUrl then
        return false, "This game is not supported yet!"
    end

    local success, result = pcall(function()
        return game:HttpGet(scriptUrl)
    end)

    if not success then
        return false, "Failed to download game script: " .. tostring(result)
    end

    -- Set a global flag to indicate the loader has validated the key
    -- This prevents the game script from re-checking
    _G.Macr0HubValidated = true
    _G.Macr0HubHWID = game:GetService("RbxAnalyticsService"):GetClientId()

    -- Execute the script
    local execSuccess, execError = pcall(function()
        loadstring(result)()
    end)

    if not execSuccess then
        return false, "Failed to execute game script: " .. tostring(execError)
    end

    return true, "Script loaded successfully!"
end

-- Load WindUI
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
_G.WindUI = WindUI

-- Enable normal cursor when UI is open
local UserInputService = game:GetService("UserInputService")
UserInputService.MouseIconEnabled = true

-- Load Macr0 theme from GitHub
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Macro002/Macr0-Hub-Scripts/main/theme.lua"))()
end)

-- Fetch supported games list
local supportedGamesList = "Loading..."
pcall(function()
    local gamesData = game:HttpGet("https://raw.githubusercontent.com/Macro002/Macr0-Hub-Scripts/main/supported_games.txt")
    local games = {}
    for line in gamesData:gmatch("[^\r\n]+") do
        if line ~= "" then
            table.insert(games, "• " .. line)
        end
    end
    supportedGamesList = table.concat(games, "\n")
end)

-- Check for saved key first
local savedKey = getSavedKey()
if savedKey and savedKey ~= "" then
    print("[Macr0 Hub] Found saved key, validating...")
    -- Try to validate saved key
    local valid, response = validateKey(savedKey)

    if valid then
        print("[Macr0 Hub] Saved key is valid, loading script directly...")
        -- Key is valid, load the script directly
        local loadSuccess, loadMessage = loadGameScript()

        if loadSuccess then
            WindUI:Notify({
                Title = "Macr0 Hub",
                Content = "Welcome back! Loading script...",
                Duration = 3,
                Icon = "check-circle",
            })
            print("[Macr0 Hub] Auto-loaded with saved key")
            return
        else
            WindUI:Notify({
                Title = "Macr0 Hub",
                Content = loadMessage,
                Duration = 5,
                Icon = "alert-triangle",
            })
        end
    else
        -- Saved key is invalid, delete it
        print("[Macr0 Hub] Saved key invalid:", response.message or "Unknown error")
        delfile(KEY_FILE)
        WindUI:Notify({
            Title = "Macr0 Hub",
            Content = "Saved key invalid: " .. (response.message or "Please enter a new key"),
            Duration = 4,
            Icon = "alert-triangle",
        })
    end
end

-- Create loader window - wider and shorter [==] shape
local Window = WindUI:CreateWindow({
    Title = "Macr0 Hub - Key Verification",
    Icon = "key-round",
    Author = "by Macr0",
    Folder = "Macr0Hub",
    Size = UDim2.fromOffset(620, 380),
    Transparent = true,
    Theme = "Macr0",
    SideBarWidth = 0,
    HideSearchBar = true,
})

local MainTab = Window:Tab({
    Title = "Authentication",
    Icon = "key",
})

-- Variables
local enteredKey = ""
local saveKeyEnabled = true

-- Get game name
local gameName = "Unknown"
pcall(function()
    gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
end)

-- Welcome message with key location
MainTab:Paragraph({
    Title = "Welcome to Macr0 Hub",
    Desc = "Enter your license key to continue.\nGame: " .. gameName .. "\nKey Location: " .. HUB_FOLDER .. "/key.txt"
})

-- Status label
local statusLabel = MainTab:Paragraph({
    Title = "Status",
    Desc = "Ready to validate"
})

-- Key input
MainTab:Input({
    Title = "License Key",
    Placeholder = "Enter your key here...",
    Callback = function(value)
        enteredKey = value
    end
})

-- Validate button (right after key input)
MainTab:Button({
    Title = "Validate Key",
    Callback = function()
        if enteredKey == "" then
            WindUI:Notify({
                Title = "Macr0 Hub",
                Content = "Please enter a license key!",
                Duration = 3,
                Icon = "alert-triangle",
            })
            return
        end

        statusLabel:SetDesc("⏳ Validating key...")
        print("[Macr0 Hub] User clicked Validate Key button")

        local valid, response = validateKey(enteredKey)

        if valid then
            statusLabel:SetDesc("✅ Key valid! Loading script...")

            -- Save key if enabled
            if saveKeyEnabled then
                saveKey(enteredKey)
                print("[Macr0 Hub] Key saved to file")
            end

            WindUI:Notify({
                Title = "Macr0 Hub",
                Content = "Key validated! Loading script...",
                Duration = 3,
                Icon = "check-circle",
            })

            -- Close loader window
            task.wait(1)

            -- Destroy window before loading script
            pcall(function()
                Window:Destroy()
            end)

            -- Load game script
            local loadSuccess, loadMessage = loadGameScript()

            if not loadSuccess then
                WindUI:Notify({
                    Title = "Macr0 Hub",
                    Content = loadMessage,
                    Duration = 5,
                    Icon = "x",
                })
            else
                print("[Macr0 Hub] Script loaded successfully!")
            end
        else
            statusLabel:SetDesc("❌ " .. (response.message or "Invalid key"))
            WindUI:Notify({
                Title = "Macr0 Hub",
                Content = response.message or "Invalid license key!",
                Duration = 4,
                Icon = "x",
            })
        end
    end
})

-- Save key checkbox
MainTab:Toggle({
    Title = "Save Key",
    Desc = "Remember this key for next time",
    Value = true,
    Callback = function(value)
        saveKeyEnabled = value
    end
})

-- Need a key section
MainTab:Paragraph({
    Title = "Need a Key?",
    Desc = "Join our Discord for support:\nhttps://discord.gg/ssKH9aDPXK"
})

-- Copy Discord invite button
MainTab:Button({
    Title = "Copy Discord Invite",
    Callback = function()
        setclipboard("https://discord.gg/ssKH9aDPXK")
        WindUI:Notify({
            Title = "Macr0 Hub",
            Content = "Discord invite copied to clipboard!",
            Duration = 3,
            Icon = "clipboard",
        })
    end
})

-- Supported games (fetched from repo)
MainTab:Paragraph({
    Title = "Supported Games",
    Desc = supportedGamesList
})

Window:SetToggleKey(Enum.KeyCode.RightControl)
Window:SelectTab(1)

print("[Macr0 Hub] Loader initialized")
