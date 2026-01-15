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
    print("[Macr0 Hub] Starting key validation...")
    print("[Macr0 Hub] Key:", key)
    print("[Macr0 Hub] HWID:", game:GetService("RbxAnalyticsService"):GetClientId())

    -- Try multiple HTTP request methods
    local requestMethods = {
        {name = "syn.request", func = function() return syn and syn.request end},
        {name = "http.request", func = function() return http and http.request end},
        {name = "http_request", func = function() return http_request end},
        {name = "request", func = function() return request end},
        {name = "syn.http.request", func = function() return syn and syn.http and syn.http.request end},
    }

    local requestFunc = nil
    local methodName = nil

    for _, method in ipairs(requestMethods) do
        local func = method.func()
        if func then
            requestFunc = func
            methodName = method.name
            print("[Macr0 Hub] Found HTTP method:", methodName)
            break
        end
    end

    if not requestFunc then
        print("[Macr0 Hub] ERROR: No HTTP request method available!")
        return false, {message = "HTTP request not supported by executor"}
    end

    local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
    local robloxId = tostring(player.UserId)
    local robloxUsername = player.Name

    -- Build URL with all parameters
    local url = API_URL .. "?key=" .. key .. "&hwid=" .. hwid .. "&roblox_id=" .. robloxId .. "&roblox_username=" .. HttpService:UrlEncode(robloxUsername)

    local success, valid, data = pcall(function()
        print("[Macr0 Hub] Sending request to:", url)

        local response = requestFunc({
            Url = url,
            Method = "GET"
        })

        print("[Macr0 Hub] Response Status:", response.StatusCode)
        print("[Macr0 Hub] Response Body:", response.Body)

        if response.StatusCode == 200 then
            local responseData = HttpService:JSONDecode(response.Body)
            print("[Macr0 Hub] Parsed response:", HttpService:JSONEncode(responseData))
            return responseData.valid == true, responseData
        elseif response.StatusCode == 404 then
            print("[Macr0 Hub] Key not found")
            return false, {message = "Invalid license key"}
        elseif response.StatusCode == 403 then
            -- Parse the body to get specific reason (banned, expired, HWID mismatch)
            local responseData = HttpService:JSONDecode(response.Body)
            print("[Macr0 Hub] Forbidden:", responseData.reason)
            return false, {message = responseData.reason or "Access denied"}
        elseif response.StatusCode == 400 then
            print("[Macr0 Hub] Bad request")
            return false, {message = "Invalid request parameters"}
        else
            print("[Macr0 Hub] Server error:", response.StatusCode)
            return false, {message = "Server error: " .. response.StatusCode}
        end
    end)

    if not success then
        print("[Macr0 Hub] ERROR:", tostring(valid))
        return false, {message = "Failed to connect to API: " .. tostring(valid)}
    end

    print("[Macr0 Hub] Validation complete. Valid:", valid)
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

-- Enable normal cursor when UI is open
local UserInputService = game:GetService("UserInputService")
UserInputService.MouseIconEnabled = true

-- Macr0 Hub Custom Theme - Purple Accented
WindUI:AddTheme({
    Name = "Macr0",

    -- Core - Vibrant purple accent with high contrast
    Accent = Color3.fromHex("#9b59b6"),
    Background = Color3.fromHex("#0a0a0f"),
    Outline = Color3.fromHex("#9b59b6"),
    Text = Color3.fromHex("#ffffff"),
    Placeholder = Color3.fromHex("#6c6c80"),
    Button = Color3.fromHex("#1e1e2a"),
    Icon = Color3.fromHex("#b87fd9"),

    Hover = Color3.fromHex("#c39bd3"),
    BackgroundTransparency = 0,

    -- Window - Deep dark base
    WindowBackground = Color3.fromHex("#0a0a0f"),
    WindowShadow = Color3.fromHex("#9b59b6"),

    -- Topbar
    WindowTopbarButtonIcon = Color3.fromHex("#b87fd9"),
    WindowTopbarTitle = Color3.fromHex("#ffffff"),
    WindowTopbarAuthor = Color3.fromHex("#b87fd9"),
    WindowTopbarIcon = Color3.fromHex("#9b59b6"),

    -- Tabs - Clear separation
    TabBackground = Color3.fromHex("#151520"),
    TabTitle = Color3.fromHex("#ffffff"),
    TabIcon = Color3.fromHex("#b87fd9"),

    -- Elements - Lighter cards that pop against dark bg
    ElementBackground = Color3.fromHex("#1a1a28"),
    ElementTitle = Color3.fromHex("#ffffff"),
    ElementDesc = Color3.fromHex("#a0a0b0"),
    ElementIcon = Color3.fromHex("#b87fd9"),

    -- Popups
    PopupBackground = Color3.fromHex("#151520"),
    PopupBackgroundTransparency = 0,
    PopupTitle = Color3.fromHex("#ffffff"),
    PopupContent = Color3.fromHex("#d4d4e4"),
    PopupIcon = Color3.fromHex("#b87fd9"),

    -- Dialogs
    DialogBackground = Color3.fromHex("#151520"),
    DialogBackgroundTransparency = 0,
    DialogTitle = Color3.fromHex("#ffffff"),
    DialogContent = Color3.fromHex("#d4d4e4"),
    DialogIcon = Color3.fromHex("#b87fd9"),

    -- Toggle - Purple accent
    Toggle = Color3.fromHex("#2a2a3a"),
    ToggleBar = Color3.fromHex("#9b59b6"),

    -- Checkbox
    Checkbox = Color3.fromHex("#2a2a3a"),
    CheckboxIcon = Color3.fromHex("#ffffff"),

    -- Slider
    Slider = Color3.fromHex("#2a2a3a"),
    SliderThumb = Color3.fromHex("#9b59b6"),
})

-- Gradient - Purple fade for depth
WindUI:Gradient({
    ["0"] = { Color = Color3.fromHex("#0a0a0f"), Transparency = 0 },
    ["100"] = { Color = Color3.fromHex("#12121c"), Transparency = 0 },
}, {
    Rotation = 180,
})

-- Set theme
WindUI:SetTheme("Macr0")

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
