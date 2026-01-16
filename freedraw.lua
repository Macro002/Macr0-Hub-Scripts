-- Reference Image Placer - Final Version
-- External image support for drawing games
-- Uses WindUI library

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
_G.WindUI = WindUI

-- Load Macr0 theme from GitHub
pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Macro002/Macr0-Hub-Scripts/main/theme.lua"))()
end)

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Variables
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local currentImageUrl = ""
local currentImageData = nil
local previewPart = nil
local placedPart = nil
local isPlacementMode = false
local followConnection = nil
local clickConnection = nil

local imageSize = 10
local imageTransparency = 0.5
local imageRotation = 0

-- Key validation check (if run directly without loader)
local HUB_FOLDER = "Macr0_Hub"
local API_URL_HWID = "https://keyauth.macr0.dev/api/v1/validate_hwid"

-- Create hub folder
if not isfolder(HUB_FOLDER) then
    makefolder(HUB_FOLDER)
end

-- License info storage
local licenseInfo = {
    is_lifetime = false,
    expires_at = nil,
    valid = false
}

-- Get HTTP request function
local function getRequestFunc()
    local requestMethods = {
        function() return syn and syn.request end,
        function() return http and http.request end,
        function() return http_request end,
        function() return request end,
        function() return syn and syn.http and syn.http.request end,
    }
    for _, method in ipairs(requestMethods) do
        local func = method()
        if func then return func end
    end
    return nil
end

-- Function to fetch license info from API
local function fetchLicenseInfo()
    local requestFunc = getRequestFunc()
    if not requestFunc then return nil end

    local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
    local robloxId = tostring(game:GetService("Players").LocalPlayer.UserId)
    local robloxUsername = game:GetService("Players").LocalPlayer.Name
    local url = API_URL_HWID .. "?hwid=" .. hwid .. "&roblox_id=" .. robloxId .. "&roblox_username=" .. game:GetService("HttpService"):UrlEncode(robloxUsername)

    local success, result = pcall(function()
        local response = requestFunc({
            Url = url,
            Method = "GET"
        })

        if response.StatusCode == 200 then
            return game:GetService("HttpService"):JSONDecode(response.Body)
        end
        return nil
    end)

    if success and result then
        licenseInfo.is_lifetime = result.is_lifetime or false
        licenseInfo.expires_at = result.expires_at
        licenseInfo.valid = result.valid or false
        return result
    end
    return nil
end

-- Function to validate access (checks loader flag, then HWID)
local function validateAccess()
    -- Check if loader already validated (session flag)
    if _G.Macr0HubValidated then
        local currentHWID = game:GetService("RbxAnalyticsService"):GetClientId()
        if _G.Macr0HubHWID == currentHWID then
            fetchLicenseInfo()
            return true, "Session valid"
        end
    end

    local requestFunc = getRequestFunc()
    if not requestFunc then return false, "HTTP not supported" end

    -- Validate by HWID
    local success, valid = pcall(function()
        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        local robloxId = tostring(Players.LocalPlayer.UserId)
        local robloxUsername = Players.LocalPlayer.Name
        local url = API_URL_HWID .. "?hwid=" .. hwid .. "&roblox_id=" .. robloxId .. "&roblox_username=" .. game:GetService("HttpService"):UrlEncode(robloxUsername)

        local response = requestFunc({ Url = url, Method = "GET" })

        if response.StatusCode == 200 then
            local data = game:GetService("HttpService"):JSONDecode(response.Body)
            licenseInfo.is_lifetime = data.is_lifetime or false
            licenseInfo.expires_at = data.expires_at
            licenseInfo.valid = data.valid or false
            return data.valid == true
        end
        return false
    end)

    return success and valid, valid and "Valid" or "Invalid license"
end

-- Check if access is valid before proceeding
local isValid, message = validateAccess()
if not isValid then
    -- Load the loader instead
    warn("[FreeDraw] " .. message .. " - Loading Macr0 Hub Loader...")
    loadstring(game:HttpGet("https://raw.githubusercontent.com/Macro002/Macr0-Hub-Scripts/main/loader.lua"))()
    return
end

-- Folder structure: Macr0_Hub/freedraw/
local imageFolder = HUB_FOLDER .. "/freedraw"
local loadedImages = {}
local selectedImage = nil

-- Create freedraw subfolder
if not isfolder(imageFolder) then
    makefolder(imageFolder)
end

-- Get full folder path
local function getFullPath()
    -- Try to get the full path by writing a temp file and checking its path
    local testFile = imageFolder .. "/pathtest.txt"
    writefile(testFile, "test")
    local fullPath = testFile
    
    -- Try to get full path from listfiles
    local files = listfiles(imageFolder)
    if #files > 0 then
        fullPath = files[1]:match("(.+[/\\])[^/\\]+$") or imageFolder
    else
        -- Use the test file we just created
        local allFiles = listfiles(imageFolder)
        if #allFiles > 0 then
            fullPath = allFiles[1]:match("(.+[/\\])[^/\\]+$") or imageFolder
        end
    end
    
    -- Clean up test file
    if isfile(testFile) then
        delfile(testFile)
    end
    
    return fullPath
end

local fullFolderPath = getFullPath()

-- Function to refresh image list
local function refreshImageList()
    loadedImages = {}
    local files = listfiles(imageFolder)
    for _, file in ipairs(files) do
        local filename = file:match("([^/\\]+)$")
        if filename:match("%.png$") or filename:match("%.jpg$") or filename:match("%.jpeg$") or filename:match("%.gif$") then
            table.insert(loadedImages, filename)
        end
    end
    return loadedImages
end

-- Parse ISO date to timestamp
local function parseISODate(isoDate)
    if not isoDate then return nil end
    local year, month, day, hour, min, sec = isoDate:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not year then return nil end
    return os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec)
    })
end

-- Calculate remaining seconds from expiry timestamp
local function getRemainingSeconds()
    if not licenseInfo.expires_at then return nil end
    local expireTime = parseISODate(licenseInfo.expires_at)
    if not expireTime then return nil end
    return expireTime - os.time()
end

-- Format seconds to readable string
local function formatTime(seconds)
    if not seconds or seconds <= 0 then return "Expired" end

    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if days > 0 then
        return days .. "d " .. hours .. "h"
    elseif hours > 0 then
        return hours .. "h " .. mins .. "m"
    elseif mins > 0 then
        return mins .. "m " .. secs .. "s"
    else
        return secs .. "s"
    end
end

-- Function to calculate remaining time from ISO date (legacy wrapper)
local function getTimeRemaining(expiresAt)
    if not expiresAt then return nil end
    local expireTime = parseISODate(expiresAt)
    if not expireTime then return nil end
    local remaining = expireTime - os.time()
    return formatTime(remaining)
end

-- Function to get license tag text
local function getLicenseTagText()
    if licenseInfo.is_lifetime then
        return "Lifetime"
    elseif licenseInfo.expires_at then
        local remaining = getTimeRemaining(licenseInfo.expires_at)
        return remaining or "Licensed"
    else
        return "Licensed"
    end
end

-- Create GUI
local Window = WindUI:CreateWindow({
    Title = "Macr0 Hub - Free Draw",
    Icon = "brush",
    Author = "by Macr0",
    Size = UDim2.fromOffset(550, 450),
    SideBarWidth = 150,
    Folder = "Macr0Hub",
    Theme = "Macr0",
    Transparent = true,
    HideSearchBar = true,
    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function()
            print("[Macr0 Hub] User clicked")
        end,
    },
})

-- Add license tag (purple bg, white text/icon)
local licenseTag = Window:Tag({
    Title = getLicenseTagText(),
    Icon = licenseInfo.is_lifetime and "infinity" or "clock",
    Color = Color3.fromHex("#a855f7"),
    Radius = 6,
})

-- Function to handle license expiry/ban
local function handleLicenseInvalid(reason)
    WindUI:Notify({
        Title = "License Invalid",
        Content = reason or "Your license has expired or been revoked",
        Duration = 5,
        Icon = "alert-triangle",
    })
    task.wait(2)
    pcall(function() Window:Destroy() end)
end

-- Real-time countdown for time-limited licenses (updates every second)
if not licenseInfo.is_lifetime and licenseInfo.expires_at then
    task.spawn(function()
        while true do
            task.wait(1)
            local remaining = getRemainingSeconds()
            if remaining and remaining <= 0 then
                handleLicenseInvalid("Your license has expired")
                break
            end
            pcall(function()
                if licenseTag and remaining then
                    licenseTag:SetTitle(formatTime(remaining))
                end
            end)
        end
    end)
end

-- Auto-sync with API every 5 minutes to check for status changes
task.spawn(function()
    while task.wait(300) do -- 5 minutes
        local result = fetchLicenseInfo()
        if result then
            -- Check if license became invalid
            if not result.valid then
                handleLicenseInvalid("License revoked or banned")
                break
            end
            -- Check if expired
            if not licenseInfo.is_lifetime and licenseInfo.expires_at then
                local remaining = getRemainingSeconds()
                if remaining and remaining <= 0 then
                    handleLicenseInvalid("Your license has expired")
                    break
                end
            end
        end
    end
end)

local ReferenceTab = Window:Tab({
    Title = "Reference",
    Icon = "images",
})

local CloningTab = Window:Tab({
    Title = "Cloning",
    Icon = "copy",
})

local ImportExportTab = Window:Tab({
    Title = "Import/Export",
    Icon = "download",
})

local DebugTab = Window:Tab({
    Title = "Debug",
    Icon = "terminal",
})

-- Cloning variables
local capturedLines = {}
local isCapturing = false
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Selection variables
local isSelectionMode = false
local selectedLines = {}
local selectionStart = nil
local selectionEnd = nil
local selectionBox = nil
local highlightedParts = {}

-- Clipboard
local copiedLines = {}
local previewFolder = nil
local isPlacementMode = false
local placementOffset = Vector2.new(0, 0)

-- Drawing settings
local drawDelay = 0.7  -- Delay between drawing lines (adjustable)
local batchSize = 15   -- Lines per batch
local batchCooldown = 2  -- Cooldown after batch
local useBatchProcessing = false  -- Batch processing toggle

-- Debug logging
local debugLogs = {}
local maxDebugLogs = 500

local function addDebugLog(message)
    local timestamp = os.date("%H:%M:%S")
    local logEntry = string.format("[%s] %s", timestamp, message)
    table.insert(debugLogs, logEntry)
    if #debugLogs > maxDebugLogs then
        table.remove(debugLogs, 1)
    end
    print(logEntry)
end

-- Status
local statusLabel = ReferenceTab:Paragraph({ 
    Title = "Status", 
    Desc = "Ready to load image" 
})

ReferenceTab:Paragraph({
    Title = "INFO",
    Desc = "Folder: " .. fullFolderPath .. "\nR - Rotate image\nE - Hold to hide image (quick view)"
})

-- Image URL Input
ReferenceTab:Input({
    Title = "Image URL",
    Placeholder = "https://example.com/image.png",
    Callback = function(value)
        currentImageUrl = value
    end
})

-- Load Image Button
ReferenceTab:Button({
    Title = "Load Image",
    Callback = function()
        if currentImageUrl == "" then
            WindUI:Notify({
                Title = "Drawing Game",
                Content = "Enter an image URL first!",
                Duration = 3,
                Icon = "alert-triangle",
            })
            return
        end
        
        statusLabel:SetDesc("⏳ Downloading image...")
        
        -- Download image
        local success, imageData = pcall(function()
            return game:HttpGet(currentImageUrl)
        end)
        
        if not success or not imageData then
            print("[Drawing Game] Failed to download image")
            WindUI:Notify({
                Title = "Drawing Game",
                Content = "Failed to download image!",
                Duration = 3,
                Icon = "x",
            })
            statusLabel:SetDesc("❌ Download failed")
            return
        end
        
        print("[Drawing Game] Downloaded:", #imageData, "bytes")
        
        -- Determine file extension
        local ext = "png"
        if string.match(currentImageUrl:lower(), "%.jpg") or string.match(currentImageUrl:lower(), "%.jpeg") then
            ext = "jpg"
        elseif string.match(currentImageUrl:lower(), "%.gif") then
            ext = "gif"
        end
        
        -- Create unique filename with timestamp
        local timestamp = os.time()
        local filename = imageFolder .. "/image_" .. timestamp .. "." .. ext
        
        -- Save to file
        writefile(filename, imageData)
        
        -- Convert to asset URL
        currentImageData = getcustomasset(filename)
        
        -- Refresh image list and full path
        refreshImageList()
        fullFolderPath = getFullPath()
        if imageDropdown then
            imageDropdown:Refresh(loadedImages)
        end
        
        print("[Drawing Game] Image loaded successfully")
        WindUI:Notify({
            Title = "Drawing Game",
            Content = "Image downloaded and saved!",
            Duration = 3,
            Icon = "check",
        })
        statusLabel:SetDesc("✅ Image ready to place")
    end
})

-- Image dropdown
local imageDropdown = ReferenceTab:Dropdown({
    Title = "Select Saved Image",
    Desc = "Choose from downloaded images",
    Values = refreshImageList(),
    Value = nil,
    Callback = function(option)
        selectedImage = option
        local filepath = imageFolder .. "/" .. option
        currentImageData = getcustomasset(filepath)
        
        print("[Drawing Game] Selected image:", option)
        print("[Drawing Game] File path:", filepath)
        print("[Drawing Game] Asset URL:", currentImageData)
        
        -- Check if file exists and get size
        if isfile(filepath) then
            local fileData = readfile(filepath)
            print("[Drawing Game] File size:", #fileData, "bytes")
        else
            print("[Drawing Game] WARNING: File does not exist!")
        end
        
        WindUI:Notify({
            Title = "Drawing Game",
            Content = "Selected: " .. option,
            Duration = 2,
            Icon = "image",
        })
        statusLabel:SetDesc("✅ Selected: " .. option)
    end
})

ReferenceTab:Button({
    Title = "Refresh Image List",
    Callback = function()
        local images = refreshImageList()
        if imageDropdown then
            imageDropdown:Refresh(images)
        end
        WindUI:Notify({
            Title = "Drawing Game",
            Content = "Found " .. #images .. " images",
            Duration = 2,
            Icon = "check",
        })
    end
})

ReferenceTab:Button({
    Title = "Clear Image Folder",
    Callback = function()
        local files = listfiles(imageFolder)
        local count = 0
        for _, file in ipairs(files) do
            delfile(file)
            count = count + 1
        end
        
        refreshImageList()
        if imageDropdown then
            imageDropdown:Refresh({})
        end
        
        WindUI:Notify({
            Title = "Drawing Game",
            Content = "Deleted " .. count .. " files",
            Duration = 3,
            Icon = "trash",
        })
        print("[Drawing Game] Cleared folder, deleted", count, "files")
    end
})

-- Start Placement
ReferenceTab:Button({
    Title = "Start Placement Mode",
    Callback = function()
        if not currentImageData then
            WindUI:Notify({
                Title = "Drawing Game",
                Content = "Load an image first!",
                Duration = 3,
                Icon = "alert-triangle",
            })
            return
        end
        
        if isPlacementMode then
            WindUI:Notify({
                Title = "Drawing Game",
                Content = "Already in placement mode!",
                Duration = 2,
                Icon = "info",
            })
            return
        end
        
        isPlacementMode = true
        
        -- Create preview part
        previewPart = Instance.new("Part")
        previewPart.Size = Vector3.new(imageSize, 0.01, imageSize)  -- Much thinner (0.01 instead of 0.1)
        previewPart.Anchored = true
        previewPart.CanCollide = false
        previewPart.Transparency = imageTransparency
        previewPart.Material = Enum.Material.SmoothPlastic
        previewPart.Color = Color3.fromRGB(100, 200, 255)
        previewPart.Name = "ReferenceImagePreview"
        previewPart.Orientation = Vector3.new(0, imageRotation, 0)
        previewPart.Parent = workspace
        
        -- Add SurfaceGui with image
        local surfaceGui = Instance.new("SurfaceGui")
        surfaceGui.Face = Enum.NormalId.Top
        surfaceGui.AlwaysOnTop = false
        surfaceGui.LightInfluence = 0
        surfaceGui.Parent = previewPart
        
        local imageLabel = Instance.new("ImageLabel")
        imageLabel.Size = UDim2.new(1, 0, 1, 0)
        imageLabel.BackgroundTransparency = 1
        imageLabel.Image = currentImageData
        imageLabel.ImageTransparency = imageTransparency
        imageLabel.ScaleType = Enum.ScaleType.Fit
        imageLabel.Parent = surfaceGui
        
        -- Follow mouse
        followConnection = RunService.RenderStepped:Connect(function()
            if previewPart and mouse.Hit then
                local hitPos = mouse.Hit.Position
                previewPart.Position = Vector3.new(hitPos.X, 0.005, hitPos.Z)  -- Lower to account for thinner part
            end
        end)
        
        -- R key to rotate
        local rotateConnection
        rotateConnection = game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.R and previewPart then
                imageRotation = (imageRotation + 45) % 360
                previewPart.Orientation = Vector3.new(0, imageRotation, 0)
                print("[Drawing Game] Rotated to", imageRotation, "degrees")
            end
        end)
        
        WindUI:Notify({
            Title = "Drawing Game",
            Content = "Click to place the image!",
            Duration = 3,
            Icon = "mouse-pointer",
        })
        statusLabel:SetDesc("🖱️ Click to place")
        
        -- Click to place
        clickConnection = mouse.Button1Down:Connect(function()
            if previewPart and isPlacementMode then
                if placedPart then
                    placedPart:Destroy()
                end
                
                placedPart = previewPart:Clone()
                placedPart.Color = Color3.fromRGB(255, 255, 255)
                placedPart.Name = "ReferenceImagePlaced"
                placedPart.Parent = workspace
                
                local gui = placedPart:FindFirstChildOfClass("SurfaceGui")
                if gui then
                    local img = gui:FindFirstChildOfClass("ImageLabel")
                    if img then
                        img.ImageTransparency = imageTransparency
                    end
                end
                
                print("[Drawing Game] Image placed")
                WindUI:Notify({
                    Title = "Drawing Game",
                    Content = "Image placed!",
                    Duration = 2,
                    Icon = "check",
                })
                statusLabel:SetDesc("✅ Image placed")
                
                -- Auto-stop placement mode
                isPlacementMode = false
                
                if followConnection then
                    followConnection:Disconnect()
                    followConnection = nil
                end
                
                if clickConnection then
                    clickConnection:Disconnect()
                    clickConnection = nil
                end
                
                if rotateConnection then
                    rotateConnection:Disconnect()
                    rotateConnection = nil
                end
                
                if previewPart then
                    previewPart:Destroy()
                    previewPart = nil
                end
            end
        end)
    end
})

-- Clear Image
ReferenceTab:Button({
    Title = "Clear Placed Image",
    Callback = function()
        if placedPart then
            placedPart:Destroy()
            placedPart = nil
            WindUI:Notify({
                Title = "Drawing Game",
                Content = "Image cleared!",
                Duration = 2,
                Icon = "trash",
            })
            statusLabel:SetDesc("🗑️ Cleared")
        else
            WindUI:Notify({
                Title = "Drawing Game",
                Content = "No image to clear!",
                Duration = 2,
                Icon = "info",
            })
        end
    end
})

-- Settings Sliders

ReferenceTab:Slider({
    Title = "Image Size (studs)",
    Step = 0.5,
    Value = { Min = 1, Max = 50, Default = imageSize },
    Callback = function(value)
        imageSize = value
        if previewPart then
            previewPart.Size = Vector3.new(imageSize, 0.1, imageSize)
        end
        if placedPart then
            placedPart.Size = Vector3.new(imageSize, 0.1, imageSize)
        end
    end
})

ReferenceTab:Slider({
    Title = "Rotation (degrees)",
    Step = 15,
    Value = { Min = 0, Max = 360, Default = imageRotation },
    Callback = function(value)
        imageRotation = value
        if previewPart then
            previewPart.Orientation = Vector3.new(0, imageRotation, 0)
        end
        if placedPart then
            placedPart.Orientation = Vector3.new(0, imageRotation, 0)
        end
    end
})

ReferenceTab:Slider({
    Title = "Transparency (%)",
    Step = 1,
    Value = { Min = 0, Max = 100, Default = imageTransparency * 100 },
    Callback = function(value)
        imageTransparency = value / 100
        
        if previewPart then
            previewPart.Transparency = imageTransparency
            local gui = previewPart:FindFirstChildOfClass("SurfaceGui")
            if gui then
                local img = gui:FindFirstChildOfClass("ImageLabel")
                if img then
                    img.ImageTransparency = imageTransparency
                end
            end
        end
        
        if placedPart then
            placedPart.Transparency = imageTransparency
            local gui = placedPart:FindFirstChildOfClass("SurfaceGui")
            if gui then
                local img = gui:FindFirstChildOfClass("ImageLabel")
                if img then
                    img.ImageTransparency = imageTransparency
                end
            end
        end
    end
})

-- Cloning Tab Features

local cloningStatus = CloningTab:Paragraph({
    Title = "Status",
    Desc = "Ready to scan workspace"
})

CloningTab:Paragraph({
    Title = "INFO",
    Desc = "1. Scan workspace\n2. Enter selection mode\n3. Drag to select parts\n4. Copy → Place → Draw\nR - Reset selection"
})

-- Function to get drawing container
local function getDrawingContainer()
    return workspace:FindFirstChild("Container(Drawing)")
end

-- Function to convert 3D position to screen position
local function worldToScreen(pos)
    local camera = workspace.CurrentCamera
    local screenPos, onScreen = camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen
end

-- Function to check if point is in selection box
local function isPointInBox(point, boxStart, boxEnd)
    local minX = math.min(boxStart.X, boxEnd.X)
    local maxX = math.max(boxStart.X, boxEnd.X)
    local minY = math.min(boxStart.Y, boxEnd.Y)
    local maxY = math.max(boxStart.Y, boxEnd.Y)
    
    return point.X >= minX and point.X <= maxX and point.Y >= minY and point.Y <= maxY
end

-- Function to highlight selected parts
local function highlightLine(line, lineData)
    for _, part in ipairs(line:GetChildren()) do
        if part:IsA("BasePart") then
            local highlight = Instance.new("SelectionBox")
            highlight.Adornee = part
            highlight.Color3 = Color3.fromRGB(0, 255, 0)
            highlight.LineThickness = 0.05
            highlight.Transparency = 0.3
            highlight.Parent = part
            table.insert(highlightedParts, highlight)
        end
    end
end

-- Function to clear all highlights
local function clearHighlights()
    for _, highlight in ipairs(highlightedParts) do
        highlight:Destroy()
    end
    highlightedParts = {}
end

-- Function to scan all lines in workspace
local function scanWorkspaceLines()
    capturedLines = {}
    local container = getDrawingContainer()
    
    if not container then
        addDebugLog("[Cloning] No drawing container found")
        return 0
    end
    
    local lineCount = 0
    
    for _, collector in ipairs(container:GetChildren()) do
        if collector.Name:match("^Collector") then
            for _, layer in ipairs(collector:GetChildren()) do
                if layer.Name:match("^Layer") then
                    local layerID = layer.Name:match("%((.+)%)")
                    
                    for _, line in ipairs(layer:GetChildren()) do
                        if line.Name == "Line" and line:IsA("Model") then
                            local points = {}
                            local color = Color3.new(0, 0, 0)
                            local thickness = 0.2
                            
                            -- Extract points from line parts
                            for _, part in ipairs(line:GetChildren()) do
                                if part:IsA("BasePart") then
                                    local pos = part.Position
                                    table.insert(points, Vector2.new(pos.X, pos.Z))
                                    
                                    if #points == 1 then
                                        color = part.Color
                                    end
                                    
                                    if part.Size.Y > 0 then
                                        thickness = math.max(thickness, part.Size.Y)
                                    end
                                end
                            end
                            
                            if #points > 0 then
                                table.insert(capturedLines, {
                                    layerID = layerID,
                                    color = color,
                                    thickness = thickness,
                                    transparency = 0,
                                    points = points,
                                    lineModel = line
                                })
                                lineCount = lineCount + 1
                            end
                        end
                    end
                end
            end
        end
    end
    
    addDebugLog("[Cloning] Captured " .. lineCount .. " lines")
    return lineCount
end

-- Scan button
CloningTab:Button({
    Title = "Scan Workspace",
    Callback = function()
        cloningStatus:SetDesc("⏳ Scanning...")
        local count = scanWorkspaceLines()
        
        if count > 0 then
            WindUI:Notify({
                Title = "Cloning",
                Content = "Captured " .. count .. " lines!",
                Duration = 3,
                Icon = "check",
            })
            cloningStatus:SetDesc("✅ Captured " .. count .. " lines")
        else
            WindUI:Notify({
                Title = "Cloning",
                Content = "No lines found in workspace",
                Duration = 3,
                Icon = "alert-triangle",
            })
            cloningStatus:SetDesc("❌ No lines found")
        end
    end
})

-- Selection mode toggle
CloningTab:Button({
    Title = "Enter Selection Mode",
    Callback = function()
        if #capturedLines == 0 then
            WindUI:Notify({
                Title = "Cloning",
                Content = "Scan workspace first!",
                Duration = 3,
                Icon = "alert-triangle",
            })
            return
        end
        
        isSelectionMode = not isSelectionMode
        
        if isSelectionMode then
            cloningStatus:SetDesc("🖱️ Selection mode: Drag to select parts")
            WindUI:Notify({
                Title = "Cloning",
                Content = "Selection mode active! Drag to select, R to reset",
                Duration = 3,
                Icon = "mouse-pointer",
            })
        else
            cloningStatus:SetDesc("⏹️ Selection mode disabled")
            clearHighlights()
            if selectionBox then
                selectionBox:Destroy()
                selectionBox = nil
            end
        end
    end
})

-- Create selection box GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SelectionBoxGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Selection mode handler
local selectionConnection = nil
local dragConnection = nil
local dragStartConnection = nil
local dragEndConnection = nil

dragStartConnection = mouse.Button1Down:Connect(function()
    if isSelectionMode and #capturedLines > 0 then
        selectionStart = Vector2.new(mouse.X, mouse.Y)
        selectionEnd = selectionStart
        
        -- Create visual selection box
        if not selectionBox then
            selectionBox = Instance.new("Frame")
            selectionBox.BorderSizePixel = 2
            selectionBox.BorderColor3 = Color3.fromRGB(0, 255, 0)
            selectionBox.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            selectionBox.BackgroundTransparency = 0.8
            selectionBox.ZIndex = 10
            selectionBox.Parent = screenGui
        end
    end
end)

-- Update selection box while dragging
dragConnection = RunService.RenderStepped:Connect(function()
    if isSelectionMode and selectionStart and mouse.Button1Down then
        selectionEnd = Vector2.new(mouse.X, mouse.Y)
        
        if selectionBox then
            local minX = math.min(selectionStart.X, selectionEnd.X)
            local maxX = math.max(selectionStart.X, selectionEnd.X)
            local minY = math.min(selectionStart.Y, selectionEnd.Y)
            local maxY = math.max(selectionStart.Y, selectionEnd.Y)
            
            selectionBox.Position = UDim2.new(0, minX, 0, minY)
            selectionBox.Size = UDim2.new(0, maxX - minX, 0, maxY - minY)
            selectionBox.Visible = true
        end
    end
end)

dragEndConnection = mouse.Button1Up:Connect(function()
    if isSelectionMode and selectionStart then
        selectionEnd = Vector2.new(mouse.X, mouse.Y)
        
        -- Hide selection box
        if selectionBox then
            selectionBox.Visible = false
        end
        
        -- Check which lines have parts in selection
        local newSelected = {}
        
        for i, lineData in ipairs(capturedLines) do
            -- Check each point individually
            for _, point in ipairs(lineData.points) do
                local worldPos = Vector3.new(point.X, 0, point.Y)
                local screenPos, onScreen = worldToScreen(worldPos)
                
                if onScreen and isPointInBox(screenPos, selectionStart, selectionEnd) then
                    -- Select this line
                    if not selectedLines[i] then
                        selectedLines[i] = true
                    end
                    break
                end
            end
        end
        
        -- Highlight all selected lines
        clearHighlights()
        local selectedCount = 0
        for i, _ in pairs(selectedLines) do
            if capturedLines[i] and capturedLines[i].lineModel then
                highlightLine(capturedLines[i].lineModel, capturedLines[i])
                selectedCount = selectedCount + 1
            end
        end
        
        cloningStatus:SetDesc("✅ Selected " .. selectedCount .. " lines")
        selectionStart = nil
        selectionEnd = nil
    end
end)

-- R key to reset selection
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.R and isSelectionMode then
        selectedLines = {}
        clearHighlights()
        cloningStatus:SetDesc("🔄 Selection reset")
        WindUI:Notify({
            Title = "Cloning",
            Content = "Selection reset!",
            Duration = 2,
            Icon = "refresh-cw",
        })
    end
end)

-- Copy selected lines
CloningTab:Button({
    Title = "Copy Selected Lines",
    Callback = function()
        local count = 0
        copiedLines = {}
        
        for i, _ in pairs(selectedLines) do
            if capturedLines[i] then
                table.insert(copiedLines, capturedLines[i])
                count = count + 1
            end
        end
        
        if count > 0 then
            WindUI:Notify({
                Title = "Cloning",
                Content = "Copied " .. count .. " lines to clipboard!",
                Duration = 3,
                Icon = "clipboard",
            })
            cloningStatus:SetDesc("📋 Copied " .. count .. " lines")
        else
            WindUI:Notify({
                Title = "Cloning",
                Content = "No lines selected!",
                Duration = 3,
                Icon = "alert-triangle",
            })
        end
    end
})

-- Start placement mode (OPTIMIZED - no lag)
CloningTab:Button({
    Title = "Place Copied Lines",
    Callback = function()
        if #copiedLines == 0 then
            WindUI:Notify({
                Title = "Cloning",
                Content = "Copy some lines first!",
                Duration = 3,
                Icon = "alert-triangle",
            })
            return
        end
        
        isPlacementMode = true
        cloningStatus:SetDesc("🖱️ Click to place copied lines")
        
        -- Create single preview part (box showing bounds)
        if previewFolder then
            previewFolder:Destroy()
        end
        
        previewFolder = Instance.new("Folder")
        previewFolder.Name = "PlacementPreview"
        previewFolder.Parent = workspace
        
        -- Calculate bounds of copied lines
        local minX, maxX = math.huge, -math.huge
        local minY, maxY = math.huge, -math.huge
        
        for _, lineData in ipairs(copiedLines) do
            for _, point in ipairs(lineData.points) do
                minX = math.min(minX, point.X)
                maxX = math.max(maxX, point.X)
                minY = math.min(minY, point.Y)
                maxY = math.max(maxY, point.Y)
            end
        end
        
        local centerX = (minX + maxX) / 2
        local centerY = (minY + maxY) / 2
        local sizeX = maxX - minX
        local sizeY = maxY - minY
        
        -- Create single bounding box preview (MUCH faster!)
        local previewPart = Instance.new("Part")
        previewPart.Size = Vector3.new(sizeX, 0.1, sizeY)
        previewPart.Anchored = true
        previewPart.CanCollide = false
        previewPart.Transparency = 0.7
        previewPart.Color = Color3.fromRGB(0, 255, 0)
        previewPart.Material = Enum.Material.Neon
        previewPart.Name = "BoundingBox"
        previewPart.Parent = previewFolder
        
        placementOffset = Vector2.new(centerX, centerY)
        
        -- Follow mouse
        local placementConnection
        placementConnection = RunService.RenderStepped:Connect(function()
            if previewFolder and mouse.Hit then
                local hitPos = mouse.Hit.Position
                placementOffset = Vector2.new(hitPos.X, hitPos.Z)
                previewPart.Position = Vector3.new(hitPos.X, 0.5, hitPos.Z)
            end
        end)
        
        -- Click to confirm placement
        local placeConnection
        placeConnection = mouse.Button1Down:Connect(function()
            if isPlacementMode then
                isPlacementMode = false
                placementConnection:Disconnect()
                placeConnection:Disconnect()
                
                cloningStatus:SetDesc("✅ Placement confirmed - Ready to draw")
                WindUI:Notify({
                    Title = "Cloning",
                    Content = "Position set! Click 'Draw Copied Lines' to draw.",
                    Duration = 3,
                    Icon = "check",
                })
            end
        end)
        
        WindUI:Notify({
            Title = "Cloning",
            Content = "Move mouse to position, click to confirm",
            Duration = 3,
            Icon = "mouse-pointer",
        })
    end
})

-- Clear placement preview
CloningTab:Button({
    Title = "Clear Placement",
    Callback = function()
        if previewFolder then
            previewFolder:Destroy()
            previewFolder = nil
        end
        isPlacementMode = false
        placementOffset = Vector2.new(0, 0)
        cloningStatus:SetDesc("🗑️ Placement cleared")
        WindUI:Notify({
            Title = "Cloning",
            Content = "Placement cleared",
            Duration = 2,
            Icon = "trash",
        })
    end
})

-- Function to generate random GUID
local function generateGUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end):upper()
end

-- Function to generate random layer ID (8 characters matching real format)
local function generateLayerID()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+"
    local result = ""
    for i = 1, 8 do
        local randIndex = math.random(1, #chars)
        result = result .. chars:sub(randIndex, randIndex)
    end
    return result
end

-- Draw copied lines at placement position
CloningTab:Button({
    Title = "Draw Copied Lines",
    Callback = function()
        if #copiedLines == 0 then
            WindUI:Notify({
                Title = "Cloning",
                Content = "Copy some lines first!",
                Duration = 3,
                Icon = "alert-triangle",
            })
            return
        end
        
        cloningStatus:SetDesc("⏳ Drawing lines...")
        
        -- Find createLine remote
        local createLineRemote = ReplicatedStorage:FindFirstChild("packages")
        if createLineRemote then
            createLineRemote = createLineRemote:FindFirstChild("_Index")
            if createLineRemote then
                createLineRemote = createLineRemote:FindFirstChild("vorlias_net@2.1.4")
                if createLineRemote then
                    createLineRemote = createLineRemote:FindFirstChild("net")
                    if createLineRemote then
                        createLineRemote = createLineRemote:FindFirstChild("_NetManaged")
                        if createLineRemote then
                            createLineRemote = createLineRemote:FindFirstChild("createLine")
                        end
                    end
                end
            end
        end
        
        if not createLineRemote then
            WindUI:Notify({
                Title = "Cloning",
                Content = "createLine remote not found!",
                Duration = 3,
                Icon = "x",
            })
            return
        end
        
        -- Calculate bounds for offset calculation
        local minX, maxX = math.huge, -math.huge
        local minY, maxY = math.huge, -math.huge
        
        for _, lineData in ipairs(copiedLines) do
            for _, point in ipairs(lineData.points) do
                minX = math.min(minX, point.X)
                maxX = math.max(maxX, point.X)
                minY = math.min(minY, point.Y)
                maxY = math.max(maxY, point.Y)
            end
        end
        
        local originalCenter = Vector2.new((minX + maxX) / 2, (minY + maxY) / 2)
        local offset = Vector2.new(
            placementOffset.X - originalCenter.X,
            placementOffset.Y - originalCenter.Y
        )
        
        addDebugLog("[Cloning] Original bounds: X(" .. minX .. " to " .. maxX .. ") Y(" .. minY .. " to " .. maxY .. ")")
        addDebugLog("[Cloning] Original center: " .. originalCenter.X .. ", " .. originalCenter.Y)
        addDebugLog("[Cloning] Placement target: " .. placementOffset.X .. ", " .. placementOffset.Y)
        addDebugLog("[Cloning] Calculated offset: " .. offset.X .. ", " .. offset.Y)
        
        -- Get current layer ID from workspace
        local currentLayerID = nil
        local drawingContainer = workspace:FindFirstChild("Container(Drawing)")
        
        if drawingContainer then
            local myCollector = drawingContainer:FindFirstChild("Collector(" .. player.UserId .. ")")
            if myCollector then
                -- Find the most recent layer (last child)
                local layers = myCollector:GetChildren()
                if #layers > 0 then
                    local lastLayer = layers[#layers]
                    if lastLayer.Name:match("^Layer%(") then
                        currentLayerID = lastLayer.Name:match("%((.+)%)")
                        addDebugLog("[Cloning] Found current layer: " .. currentLayerID)
                    end
                end
            end
        end
        
        -- Fallback to generating new ID if we couldn't find current layer
        if not currentLayerID then
            addDebugLog("[Cloning] Could not find current layer, using fallback")
            currentLayerID = copiedLines[1].layerID or generateLayerID()
        end
        
        addDebugLog("[Cloning] Starting draw with layer ID: " .. currentLayerID)
        addDebugLog("[Cloning] Drawing " .. #copiedLines .. " lines with adaptive rate limiting")
        
        local successCount = 0
        local batchSize = 15  -- Lines per batch before cooldown
        local batchCooldown = 2  -- Seconds to wait after each batch
        
        for i, lineData in ipairs(copiedLines) do
            -- Apply offset to all points
            local newPoints = {}
            for _, point in ipairs(lineData.points) do
                table.insert(newPoints, Vector2.new(
                    point.X + offset.X,
                    point.Y + offset.Y
                ))
            end
            
            addDebugLog("[Cloning] Line " .. i .. " - Points: " .. #newPoints .. " Color: " .. tostring(lineData.color) .. " Thickness: " .. lineData.thickness)
            
            -- Log first point to debug coordinates
            if i <= 3 and #newPoints > 0 then
                addDebugLog("[Cloning]   First point after offset: (" .. newPoints[1].X .. ", " .. newPoints[1].Y .. ")")
            end
            
            local success, err = pcall(function()
                createLineRemote:FireServer(
                    generateGUID(),
                    {
                        currentLayerID,
                        {
                            color = lineData.color,
                            transparency = lineData.transparency,
                            thickness = lineData.thickness
                        },
                        newPoints
                    }
                )
            end)
            
            if success then
                successCount = successCount + 1
                addDebugLog("[Cloning] Line " .. i .. " drawn successfully")
            else
                addDebugLog("[Cloning] Line " .. i .. " FAILED: " .. tostring(err))
            end
            
            -- Adaptive rate limiting
            if i % batchSize == 0 then
                addDebugLog("[Cloning] Batch complete (" .. i .. "/" .. #copiedLines .. "), cooldown " .. batchCooldown .. "s...")
                task.wait(batchCooldown)
            else
                task.wait(drawDelay)
            end
        end
        
        -- Clear preview after drawing
        if previewFolder then
            previewFolder:Destroy()
            previewFolder = nil
        end
        
        WindUI:Notify({
            Title = "Cloning",
            Content = "Drew " .. successCount .. " lines!",
            Duration = 3,
            Icon = "check",
        })
        cloningStatus:SetDesc("✅ Drew " .. successCount .. " lines")
        addDebugLog("[Cloning] Drawing complete: " .. successCount .. " lines on layer " .. currentLayerID)
    end
})

-- Cleanup
Window:OnDestroy(function()
    if followConnection then followConnection:Disconnect() end
    if clickConnection then clickConnection:Disconnect() end
    if previewPart then previewPart:Destroy() end
    if placedPart then placedPart:Destroy() end
end)

-- Import/Export Tab

local importExportStatus = ImportExportTab:Paragraph({
    Title = "Status",
    Desc = "Ready to import saves"
})

ImportExportTab:Paragraph({
    Title = "INFO",
    Desc = "Place JSON save files in: " .. fullFolderPath .. "\n1. Select save file\n2. Click 'Draw Save'\n3. Wait for completion"
})

-- Variables for import
local availableSaves = {}
local selectedSave = nil

-- Function to refresh save list
local function refreshSaveList()
    availableSaves = {}
    local files = listfiles(imageFolder)
    for _, file in ipairs(files) do
        local filename = file:match("([^/\\]+)$")
        if filename:match("%.json$") then
            table.insert(availableSaves, filename)
        end
    end
    return availableSaves
end

-- Save selector dropdown
local saveDropdown = ImportExportTab:Dropdown({
    Title = "Select Save File",
    Desc = "Choose JSON save to import",
    Values = refreshSaveList(),
    Value = nil,
    Callback = function(option)
        selectedSave = option
        importExportStatus:SetDesc("✅ Selected: " .. option)
        WindUI:Notify({
            Title = "Import/Export",
            Content = "Selected: " .. option,
            Duration = 2,
            Icon = "file",
        })
    end
})

ImportExportTab:Button({
    Title = "Refresh Save List",
    Callback = function()
        local saves = refreshSaveList()
        if saveDropdown then
            saveDropdown:Refresh(saves)
        end
        WindUI:Notify({
            Title = "Import/Export",
            Content = "Found " .. #saves .. " save files",
            Duration = 2,
            Icon = "check",
        })
    end
})

-- Preview folder
local previewFolder = nil

-- Preview save data
ImportExportTab:Button({
    Title = "Preview Save",
    Callback = function()
        if not selectedSave then
            WindUI:Notify({
                Title = "Import/Export",
                Content = "Select a save file first!",
                Duration = 3,
                Icon = "alert-triangle",
            })
            return
        end
        
        -- Clear existing preview
        if previewFolder then
            previewFolder:Destroy()
        end
        
        importExportStatus:SetDesc("⏳ Loading preview...")
        
        -- Read JSON file
        local filepath = imageFolder .. "/" .. selectedSave
        local success, jsonData = pcall(function()
            return readfile(filepath)
        end)
        
        if not success or not jsonData then
            WindUI:Notify({
                Title = "Import/Export",
                Content = "Failed to read save file!",
                Duration = 3,
                Icon = "x",
            })
            return
        end
        
        -- Parse JSON
        local data = game:GetService("HttpService"):JSONDecode(jsonData)
        
        addDebugLog("[Preview] Loaded " .. #data.layers .. " layers")
        
        -- Create preview folder
        previewFolder = Instance.new("Folder")
        previewFolder.Name = "SavePreview"
        previewFolder.Parent = workspace
        
        local totalLines = 0
        
        -- Create visual preview for each layer
        for layerIdx, layer in ipairs(data.layers) do
            local layerFolder = Instance.new("Folder")
            layerFolder.Name = "Layer" .. layerIdx .. "_" .. layer.id
            layerFolder.Parent = previewFolder
            
            addDebugLog("[Preview] Layer " .. layerIdx .. ": " .. #layer.lines .. " lines")
            
            -- Draw each line
            for lineIdx, line in ipairs(layer.lines) do
                local lineModel = Instance.new("Model")
                lineModel.Name = "Line" .. lineIdx
                lineModel.Parent = layerFolder
                
                -- Get color from line data
                local lineColor = Color3.new(line.color.R, line.color.G, line.color.B)
                local thickness = line.thickness or 0.2
                
                -- Create parts connecting the points
                for pointIdx = 1, #line.points - 1 do
                    local point1 = line.points[pointIdx]
                    local point2 = line.points[pointIdx + 1]
                    
                    -- Calculate position and size
                    local pos1 = Vector3.new(point1.X, 1, point1.Y)
                    local pos2 = Vector3.new(point2.X, 1, point2.Y)
                    local midpoint = (pos1 + pos2) / 2
                    local distance = (pos2 - pos1).Magnitude
                    
                    -- Create line segment
                    local part = Instance.new("Part")
                    part.Size = Vector3.new(thickness, thickness, distance)
                    part.Position = midpoint
                    part.Anchored = true
                    part.CanCollide = false
                    part.Color = lineColor
                    part.Material = Enum.Material.SmoothPlastic
                    part.Transparency = line.transparency or 0
                    
                    -- Rotate to connect points
                    part.CFrame = CFrame.new(midpoint, pos2)
                    
                    part.Parent = lineModel
                end
                
                totalLines = totalLines + 1
            end
        end
        
        addDebugLog("[Preview] Preview created: " .. totalLines .. " lines rendered")
        
        WindUI:Notify({
            Title = "Import/Export",
            Content = "Preview created! " .. #data.layers .. " layers, " .. totalLines .. " lines",
            Duration = 3,
            Icon = "eye",
        })
        importExportStatus:SetDesc("👁️ Preview: " .. #data.layers .. " layers, " .. totalLines .. " lines")
    end
})

ImportExportTab:Button({
    Title = "Clear Preview",
    Callback = function()
        if previewFolder then
            previewFolder:Destroy()
            previewFolder = nil
            WindUI:Notify({
                Title = "Import/Export",
                Content = "Preview cleared",
                Duration = 2,
                Icon = "trash",
            })
            importExportStatus:SetDesc("🗑️ Preview cleared")
        else
            WindUI:Notify({
                Title = "Import/Export",
                Content = "No preview to clear",
                Duration = 2,
                Icon = "info",
            })
        end
    end
})

-- Function to generate GUID (defined earlier but need access here)
-- Already defined globally above

-- Function to get current layer
local function getCurrentLayerForImport()
    local container = workspace:FindFirstChild("Container(Drawing)")
    if container then
        local myCollector = container:FindFirstChild("Collector(" .. player.UserId .. ")")
        if myCollector then
            local layers = myCollector:GetChildren()
            if #layers > 0 then
                local lastLayer = layers[#layers]
                if lastLayer.Name:match("^Layer%(") then
                    return lastLayer.Name:match("%((.+)%)")
                end
            end
        end
    end
    return nil
end

-- Draw save file
ImportExportTab:Button({
    Title = "Draw Save",
    Callback = function()
        if not selectedSave then
            WindUI:Notify({
                Title = "Import/Export",
                Content = "Select a save file first!",
                Duration = 3,
                Icon = "alert-triangle",
            })
            return
        end
        
        importExportStatus:SetDesc("⏳ Loading save file...")
        
        -- Read JSON file
        local filepath = imageFolder .. "/" .. selectedSave
        local success, jsonData = pcall(function()
            return readfile(filepath)
        end)
        
        if not success or not jsonData then
            WindUI:Notify({
                Title = "Import/Export",
                Content = "Failed to read save file!",
                Duration = 3,
                Icon = "x",
            })
            importExportStatus:SetDesc("❌ Failed to read file")
            return
        end
        
        -- Parse JSON
        local data = game:GetService("HttpService"):JSONDecode(jsonData)
        
        addDebugLog("[Import] Loaded " .. #data.layers .. " layers")
        
        -- Count total lines
        local totalLines = 0
        for _, layer in ipairs(data.layers) do
            totalLines = totalLines + #layer.lines
        end
        
        addDebugLog("[Import] Total lines: " .. totalLines)
        importExportStatus:SetDesc("📂 Loaded " .. totalLines .. " lines from " .. #data.layers .. " layers")
        
        -- Find createLine remote
        local createLineRemote = ReplicatedStorage:FindFirstChild("packages")
        if createLineRemote then
            createLineRemote = createLineRemote:FindFirstChild("_Index")
            if createLineRemote then
                createLineRemote = createLineRemote:FindFirstChild("vorlias_net@2.1.4")
                if createLineRemote then
                    createLineRemote = createLineRemote:FindFirstChild("net")
                    if createLineRemote then
                        createLineRemote = createLineRemote:FindFirstChild("_NetManaged")
                        if createLineRemote then
                            createLineRemote = createLineRemote:FindFirstChild("createLine")
                        end
                    end
                end
            end
        end
        
        if not createLineRemote then
            WindUI:Notify({
                Title = "Import/Export",
                Content = "createLine remote not found!",
                Duration = 3,
                Icon = "x",
            })
            return
        end
        
        -- Get current layer
        local currentLayerID = getCurrentLayerForImport()
        if not currentLayerID then
            WindUI:Notify({
                Title = "Import/Export",
                Content = "No active layer found! Create a layer first.",
                Duration = 3,
                Icon = "alert-triangle",
            })
            return
        end
        
        addDebugLog("[Import] Drawing on layer: " .. currentLayerID)
        importExportStatus:SetDesc("⏳ Drawing " .. totalLines .. " lines...")
        
        local successCount = 0
        local failCount = 0
        
        -- Draw all lines from all layers
        for layerIdx, layer in ipairs(data.layers) do
            addDebugLog("[Import] Layer " .. layerIdx .. "/" .. #data.layers .. " (" .. #layer.lines .. " lines)")
            
            for lineIdx, line in ipairs(layer.lines) do
                -- Convert points to Vector2
                local points = {}
                for _, point in ipairs(line.points) do
                    table.insert(points, Vector2.new(point.X, point.Y))
                end
                
                -- Convert color
                local color = Color3.new(line.color.R, line.color.G, line.color.B)
                
                -- Draw line
                local success, err = pcall(function()
                    createLineRemote:FireServer(
                        generateGUID(),
                        {
                            currentLayerID,
                            {
                                color = color,
                                transparency = line.transparency or 0,
                                thickness = line.thickness or 0.2
                            },
                            points
                        }
                    )
                end)
                
                if success then
                    successCount = successCount + 1
                else
                    failCount = failCount + 1
                    addDebugLog("[Import] Line failed: " .. tostring(err))
                end
                
                -- Progress update
                if successCount % 100 == 0 then
                    addDebugLog("[Import] Progress: " .. successCount .. "/" .. totalLines)
                    importExportStatus:SetDesc("⏳ Drawing: " .. successCount .. "/" .. totalLines)
                end
                
                -- Rate limiting
                if useBatchProcessing and successCount % batchSize == 0 then
                    addDebugLog("[Import] Batch cooldown...")
                    task.wait(batchCooldown)
                else
                    task.wait(drawDelay)
                end
            end
        end
        
        addDebugLog("[Import] ==========================================")
        addDebugLog("[Import] IMPORT COMPLETE!")
        addDebugLog("[Import] Success: " .. successCount .. "/" .. totalLines)
        addDebugLog("[Import] Failed: " .. failCount)
        addDebugLog("[Import] ==========================================")
        
        WindUI:Notify({
            Title = "Import/Export",
            Content = "Imported " .. successCount .. "/" .. totalLines .. " lines!",
            Duration = 5,
            Icon = "check",
        })
        importExportStatus:SetDesc("✅ Imported " .. successCount .. " lines")
    end
})

-- Debug Tab
DebugTab:Paragraph({
    Title = "Debug Console",
    Desc = "View and copy debug logs"
})

-- Delay slider
DebugTab:Slider({
    Title = "Draw Delay (seconds)",
    Step = 0.05,
    Value = { Min = 0.05, Max = 2.0, Default = drawDelay },
    Callback = function(value)
        drawDelay = value
        addDebugLog("[Settings] Draw delay set to " .. value .. "s")
        WindUI:Notify({
            Title = "Debug",
            Content = "Delay: " .. value .. "s between lines",
            Duration = 2,
            Icon = "clock",
        })
    end
})

-- Batch processing toggle
DebugTab:Toggle({
    Title = "Batch Processing",
    Desc = "Enable batch rate limiting (disabled by default)",
    Value = useBatchProcessing,
    Callback = function(value)
        useBatchProcessing = value
        addDebugLog("[Settings] Batch processing: " .. (value and "enabled" or "disabled"))
        WindUI:Notify({
            Title = "Debug",
            Content = "Batch processing " .. (value and "enabled" or "disabled"),
            Duration = 2,
            Icon = value and "check" or "x",
        })
    end
})

DebugTab:Slider({
    Title = "Batch Size (lines)",
    Step = 1,
    Value = { Min = 5, Max = 30, Default = batchSize },
    Callback = function(value)
        batchSize = value
        addDebugLog("[Settings] Batch size set to " .. value .. " lines")
        WindUI:Notify({
            Title = "Debug",
            Content = "Batch: " .. value .. " lines",
            Duration = 2,
            Icon = "layers",
        })
    end
})

DebugTab:Slider({
    Title = "Batch Cooldown (seconds)",
    Step = 0.5,
    Value = { Min = 1, Max = 5, Default = batchCooldown },
    Callback = function(value)
        batchCooldown = value
        addDebugLog("[Settings] Batch cooldown set to " .. value .. "s")
        WindUI:Notify({
            Title = "Debug",
            Content = "Cooldown: " .. value .. "s",
            Duration = 2,
            Icon = "pause",
        })
    end
})

DebugTab:Paragraph({
    Title = "Rate Limiting",
    Desc = "Draws in batches with cooldown between each batch to avoid rate limiting"
})

DebugTab:Paragraph({
    Title = "Recommended Settings",
    Desc = "Simple (<50 lines): 0.05s delay, 15 batch\nMedium (50-200 lines): 0.1s delay, 15 batch, 2s cooldown\nComplex (200+ lines): 0.1s delay, 10 batch, 3s cooldown"
})

DebugTab:Button({
    Title = "Copy All Logs",
    Callback = function()
        local allLogs = table.concat(debugLogs, "\n")
        setclipboard(allLogs)
        WindUI:Notify({
            Title = "Debug",
            Content = "Copied " .. #debugLogs .. " log lines!",
            Duration = 2,
            Icon = "clipboard",
        })
    end
})

DebugTab:Button({
    Title = "Show Copied Lines Info",
    Callback = function()
        if #copiedLines == 0 then
            WindUI:Notify({
                Title = "Debug",
                Content = "No lines copied yet",
                Duration = 2,
                Icon = "alert-triangle",
            })
            return
        end
        
        addDebugLog("[Debug] === Copied Lines Info ===")
        addDebugLog("[Debug] Total lines: " .. #copiedLines)
        
        -- Show first 3 lines with their first 3 points
        for i = 1, math.min(3, #copiedLines) do
            local line = copiedLines[i]
            addDebugLog("[Debug] Line " .. i .. " has " .. #line.points .. " points")
            for j = 1, math.min(3, #line.points) do
                local p = line.points[j]
                addDebugLog("[Debug]   Point " .. j .. ": (" .. p.X .. ", " .. p.Y .. ")")
            end
        end
        
        WindUI:Notify({
            Title = "Debug",
            Content = "Logged line info - check console",
            Duration = 2,
            Icon = "info",
        })
    end
})

DebugTab:Button({
    Title = "Clear Logs",
    Callback = function()
        debugLogs = {}
        addDebugLog("[Debug] Logs cleared")
        WindUI:Notify({
            Title = "Debug",
            Content = "Logs cleared",
            Duration = 2,
            Icon = "trash",
        })
    end
})

DebugTab:Button({
    Title = "Sync License Status",
    Callback = function()
        -- Re-fetch from API
        local requestFunc = getRequestFunc()
        if not requestFunc then
            WindUI:Notify({
                Title = "Sync",
                Content = "HTTP not available",
                Duration = 3,
                Icon = "alert-triangle",
            })
            return
        end

        local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
        local robloxId = tostring(Players.LocalPlayer.UserId)
        local robloxUsername = Players.LocalPlayer.Name
        local url = API_URL_HWID .. "?hwid=" .. hwid .. "&roblox_id=" .. robloxId .. "&roblox_username=" .. game:GetService("HttpService"):UrlEncode(robloxUsername)

        local success, response = pcall(function()
            return requestFunc({ Url = url, Method = "GET" })
        end)

        if not success then
            WindUI:Notify({
                Title = "Sync",
                Content = "Connection failed",
                Duration = 3,
                Icon = "wifi-off",
            })
            return
        end

        if response.StatusCode == 200 then
            local data = game:GetService("HttpService"):JSONDecode(response.Body)
            licenseInfo.is_lifetime = data.is_lifetime or false
            licenseInfo.expires_at = data.expires_at
            licenseInfo.valid = data.valid or false

            if not data.valid then
                handleLicenseInvalid("License revoked or banned")
                return
            end

            local status = licenseInfo.is_lifetime and "Lifetime" or (getTimeRemaining(licenseInfo.expires_at) or "Licensed")
            WindUI:Notify({
                Title = "Sync",
                Content = "Synced: " .. status,
                Duration = 3,
                Icon = "check",
            })
        elseif response.StatusCode == 403 then
            local data = game:GetService("HttpService"):JSONDecode(response.Body)
            handleLicenseInvalid(data.reason or "License banned")
        elseif response.StatusCode == 404 then
            handleLicenseInvalid("License not found")
        else
            WindUI:Notify({
                Title = "Sync",
                Content = "Server error: " .. response.StatusCode,
                Duration = 3,
                Icon = "alert-triangle",
            })
        end
    end
})

local logCountLabel = DebugTab:Paragraph({
    Title = "Log Count",
    Desc = "0 logs"
})

-- Update log count periodically
task.spawn(function()
    while task.wait(2) do
        if logCountLabel then
            pcall(function()
                logCountLabel:SetDesc(#debugLogs .. " logs stored")
            end)
        end
    end
end)

-- E key to temporarily hide placed image (global handler)
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.E and placedPart then
        -- Hide the placed image
        placedPart.Transparency = 1
        local gui = placedPart:FindFirstChildOfClass("SurfaceGui")
        if gui then
            local img = gui:FindFirstChildOfClass("ImageLabel")
            if img then
                img.ImageTransparency = 1
            end
        end
        print("[Drawing Game] Image hidden (E pressed)")
    end
end)

game:GetService("UserInputService").InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.E and placedPart then
        -- Restore the placed image
        placedPart.Transparency = imageTransparency
        local gui = placedPart:FindFirstChildOfClass("SurfaceGui")
        if gui then
            local img = gui:FindFirstChildOfClass("ImageLabel")
            if img then
                img.ImageTransparency = imageTransparency
            end
        end
        print("[Drawing Game] Image shown (E released)")
    end
end)

Window:SetToggleKey(Enum.KeyCode.RightControl)
Window:SelectTab(1)

print("[Drawing Game] Reference Image Placer loaded!")

WindUI:Notify({
    Title = "Drawing Game",
    Content = "Reference Image Placer ready!",
    Duration = 3,
    Icon = "check-circle",
})