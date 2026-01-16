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

        -- Parse response for both success and error status codes
        if response.Body then
            local data = game:GetService("HttpService"):JSONDecode(response.Body)
            data.statusCode = response.StatusCode
            return data
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

-- Folder structure: Macr0_Hub/freedraw/references/
local freedrawFolder = HUB_FOLDER .. "/freedraw"
local imageFolder = freedrawFolder .. "/references"
local loadedImages = {}
local selectedImage = nil

-- Create freedraw subfolders
if not isfolder(freedrawFolder) then
    makefolder(freedrawFolder)
end
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

-- Auto-sync with API every minute to check for status changes
task.spawn(function()
    while task.wait(60) do -- 1 minute
        local result = fetchLicenseInfo()
        if result then
            -- Check if license became invalid
            if not result.valid then
                handleLicenseInvalid(result.reason or "License revoked or banned")
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Selection variables
local isSelectionMode = false
local selectedLines = {}

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
                Title = "FreeDraw",
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
            print("[FreeDraw] Failed to download image")
            WindUI:Notify({
                Title = "FreeDraw",
                Content = "Failed to download image!",
                Duration = 3,
                Icon = "x",
            })
            statusLabel:SetDesc("❌ Download failed")
            return
        end
        
        print("[FreeDraw] Downloaded:", #imageData, "bytes")
        
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
        
        print("[FreeDraw] Image loaded successfully")
        WindUI:Notify({
            Title = "FreeDraw",
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
        
        print("[FreeDraw] Selected image:", option)
        print("[FreeDraw] File path:", filepath)
        print("[FreeDraw] Asset URL:", currentImageData)
        
        -- Check if file exists and get size
        if isfile(filepath) then
            local fileData = readfile(filepath)
            print("[FreeDraw] File size:", #fileData, "bytes")
        else
            print("[FreeDraw] WARNING: File does not exist!")
        end
        
        WindUI:Notify({
            Title = "FreeDraw",
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
            Title = "FreeDraw",
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
            Title = "FreeDraw",
            Content = "Deleted " .. count .. " files",
            Duration = 3,
            Icon = "trash",
        })
        print("[FreeDraw] Cleared folder, deleted", count, "files")
    end
})

-- Start Placement
ReferenceTab:Button({
    Title = "Start Placement Mode",
    Callback = function()
        if not currentImageData then
            WindUI:Notify({
                Title = "FreeDraw",
                Content = "Load an image first!",
                Duration = 3,
                Icon = "alert-triangle",
            })
            return
        end
        
        if isPlacementMode then
            WindUI:Notify({
                Title = "FreeDraw",
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
        previewPart.Color = Color3.fromRGB(168, 85, 247)
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
                print("[FreeDraw] Rotated to", imageRotation, "degrees")
            end
        end)
        
        WindUI:Notify({
            Title = "FreeDraw",
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
                
                print("[FreeDraw] Image placed")
                WindUI:Notify({
                    Title = "FreeDraw",
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
                Title = "FreeDraw",
                Content = "Image cleared!",
                Duration = 2,
                Icon = "trash",
            })
            statusLabel:SetDesc("🗑️ Cleared")
        else
            WindUI:Notify({
                Title = "FreeDraw",
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
    Value = { Min = 1, Max = 100, Default = imageSize },
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
    Desc = "Ready - Press Q to toggle selection mode"
})

CloningTab:Paragraph({
    Title = "INFO",
    Desc = "Q - Toggle selection mode\nDrag on canvas to select lines\nR - Reset selection\nClick to copy → place → draw"
})

-- Function to get drawing container
local function getDrawingContainer()
    return workspace:FindFirstChild("Container(Drawing)")
end

-- Selection bounds display (purple box showing what's selected)
local selectionBoundsBox = nil

-- Function to update selection bounds display (lightweight - just one box)
local function updateSelectionBoundsDisplay()
    -- Remove old bounds box
    if selectionBoundsBox then
        selectionBoundsBox:Destroy()
        selectionBoundsBox = nil
    end

    -- Count selected and calculate bounds
    local selectedCount = 0
    local minX, maxX = math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge

    for i, _ in pairs(selectedLines) do
        if capturedLines[i] then
            selectedCount = selectedCount + 1
            for _, point in ipairs(capturedLines[i].points) do
                minX = math.min(minX, point.X)
                maxX = math.max(maxX, point.X)
                minZ = math.min(minZ, point.Y)
                maxZ = math.max(maxZ, point.Y)
            end
        end
    end

    if selectedCount > 0 then
        -- Create single purple bounding box (no lag!)
        selectionBoundsBox = Instance.new("Part")
        selectionBoundsBox.Name = "SelectionBounds"
        selectionBoundsBox.Size = Vector3.new(maxX - minX + 0.5, 0.05, maxZ - minZ + 0.5)
        selectionBoundsBox.Position = Vector3.new((minX + maxX) / 2, 0.1, (minZ + maxZ) / 2)
        selectionBoundsBox.Anchored = true
        selectionBoundsBox.CanCollide = false
        selectionBoundsBox.Transparency = 0.7
        selectionBoundsBox.Color = Color3.fromRGB(168, 85, 247)
        selectionBoundsBox.Material = Enum.Material.Neon
        selectionBoundsBox.Parent = workspace

        cloningStatus:SetDesc("✅ Selected " .. selectedCount .. " lines")
    else
        cloningStatus:SetDesc("🖱️ Drag on canvas to select")
    end

    return selectedCount
end

-- Function to clear selection display
local function clearSelectionDisplay()
    if selectionBoundsBox then
        selectionBoundsBox:Destroy()
        selectionBoundsBox = nil
    end
end

-- Function to scan all lines in workspace
local function scanWorkspaceLines()
    local container = getDrawingContainer()

    if not container then
        return 0
    end

    -- Track existing line models to avoid duplicates
    local existingModels = {}
    for _, lineData in ipairs(capturedLines) do
        if lineData.lineModel then
            existingModels[lineData.lineModel] = true
        end
    end

    local newLineCount = 0

    for _, collector in ipairs(container:GetChildren()) do
        if collector.Name:match("^Collector") then
            for _, layer in ipairs(collector:GetChildren()) do
                if layer.Name:match("^Layer") then
                    local layerID = layer.Name:match("%((.+)%)")

                    for _, line in ipairs(layer:GetChildren()) do
                        if line.Name == "Line" and line:IsA("Model") and not existingModels[line] then
                            local points = {}
                            local color = Color3.new(0, 0, 0)
                            local thickness = 0.2

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
                                newLineCount = newLineCount + 1
                            end
                        end
                    end
                end
            end
        end
    end

    return newLineCount
end

-- 3D Selection plane (draggable on canvas)
local selectionPlane = nil
local selectionPlaneStart = nil
local isDraggingSelection = false

-- Function to check if a line intersects with selection box (in world coords)
local function lineIntersectsBox(lineData, boxMinX, boxMaxX, boxMinZ, boxMaxZ)
    for _, point in ipairs(lineData.points) do
        if point.X >= boxMinX and point.X <= boxMaxX and point.Y >= boxMinZ and point.Y <= boxMaxZ then
            return true
        end
    end
    return false
end

-- Create/update 3D selection plane while dragging
local function updateSelectionPlane(startPos, endPos)
    if not selectionPlane then
        selectionPlane = Instance.new("Part")
        selectionPlane.Name = "SelectionPlane"
        selectionPlane.Anchored = true
        selectionPlane.CanCollide = false
        selectionPlane.Transparency = 0.8
        selectionPlane.Color = Color3.fromRGB(168, 85, 247)
        selectionPlane.Material = Enum.Material.Neon
        selectionPlane.Parent = workspace
    end

    local minX = math.min(startPos.X, endPos.X)
    local maxX = math.max(startPos.X, endPos.X)
    local minZ = math.min(startPos.Z, endPos.Z)
    local maxZ = math.max(startPos.Z, endPos.Z)

    selectionPlane.Size = Vector3.new(maxX - minX, 0.02, maxZ - minZ)
    selectionPlane.Position = Vector3.new((minX + maxX) / 2, 0.05, (minZ + maxZ) / 2)
    selectionPlane.Visible = true
end

-- Remove selection plane
local function clearSelectionPlane()
    if selectionPlane then
        selectionPlane:Destroy()
        selectionPlane = nil
    end
end

-- Live update connection for new lines
local liveUpdateConnection = nil

-- Toggle selection mode function
local function toggleSelectionMode()
    isSelectionMode = not isSelectionMode

    if isSelectionMode then
        -- Initial scan
        capturedLines = {}
        local count = scanWorkspaceLines()
        addDebugLog("[Cloning] Selection mode ON - Found " .. count .. " lines")

        cloningStatus:SetDesc("🖱️ Drag on canvas to select (" .. count .. " lines)")
        WindUI:Notify({
            Title = "Cloning",
            Content = "Selection mode ON - " .. count .. " lines available",
            Duration = 2,
            Icon = "mouse-pointer",
        })

        -- Start live update loop for new lines
        liveUpdateConnection = task.spawn(function()
            while isSelectionMode do
                task.wait(2) -- Check every 2 seconds
                local newCount = scanWorkspaceLines()
                if newCount > 0 then
                    addDebugLog("[Cloning] Found " .. newCount .. " new lines")
                end
            end
        end)
    else
        -- Disable selection mode
        clearSelectionPlane()
        clearSelectionDisplay()
        selectedLines = {}

        if liveUpdateConnection then
            task.cancel(liveUpdateConnection)
            liveUpdateConnection = nil
        end

        cloningStatus:SetDesc("⏹️ Selection mode OFF")
        WindUI:Notify({
            Title = "Cloning",
            Content = "Selection mode OFF",
            Duration = 2,
            Icon = "square",
        })
    end
end

-- Selection mode toggle button
CloningTab:Button({
    Title = "Toggle Selection Mode (Q)",
    Callback = toggleSelectionMode
})

-- Q key to toggle selection mode
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Q then
        toggleSelectionMode()
    end
end)

-- R key to reset selection
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.R and isSelectionMode then
        selectedLines = {}
        clearSelectionDisplay()
        cloningStatus:SetDesc("🔄 Selection reset")
        WindUI:Notify({
            Title = "Cloning",
            Content = "Selection cleared",
            Duration = 2,
            Icon = "refresh-cw",
        })
    end
end)

-- Mouse drag for 3D selection on canvas
local selectionDragStart = nil
local selectionDragConnection = nil

mouse.Button1Down:Connect(function()
    if isSelectionMode and mouse.Hit then
        local hitPos = mouse.Hit.Position
        -- Only start selection if clicking near ground level (drawing surface)
        if math.abs(hitPos.Y) < 5 then
            selectionDragStart = Vector3.new(hitPos.X, 0, hitPos.Z)
            isDraggingSelection = true
        end
    end
end)

-- Update selection plane while dragging
RunService.RenderStepped:Connect(function()
    if isSelectionMode and isDraggingSelection and selectionDragStart and mouse.Hit then
        local hitPos = mouse.Hit.Position
        local currentPos = Vector3.new(hitPos.X, 0, hitPos.Z)
        updateSelectionPlane(selectionDragStart, currentPos)
    end
end)

mouse.Button1Up:Connect(function()
    if isSelectionMode and isDraggingSelection and selectionDragStart and mouse.Hit then
        local hitPos = mouse.Hit.Position
        local endPos = Vector3.new(hitPos.X, 0, hitPos.Z)

        -- Calculate selection bounds
        local minX = math.min(selectionDragStart.X, endPos.X)
        local maxX = math.max(selectionDragStart.X, endPos.X)
        local minZ = math.min(selectionDragStart.Z, endPos.Z)
        local maxZ = math.max(selectionDragStart.Z, endPos.Z)

        -- Only select if dragged a reasonable distance
        if (maxX - minX) > 0.5 or (maxZ - minZ) > 0.5 then
            -- Find lines that intersect with selection
            for i, lineData in ipairs(capturedLines) do
                if lineIntersectsBox(lineData, minX, maxX, minZ, maxZ) then
                    selectedLines[i] = true
                end
            end

            updateSelectionBoundsDisplay()
        end

        -- Clear drag plane
        clearSelectionPlane()
        selectionDragStart = nil
        isDraggingSelection = false
    end
end)

-- Copy selected lines
CloningTab:Button({
    Title = "Copy Selected",
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
                Content = "Copied " .. count .. " lines!",
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

-- Place copied lines
CloningTab:Button({
    Title = "Place Copied",
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
        cloningStatus:SetDesc("🖱️ Click to place")

        if previewFolder then
            previewFolder:Destroy()
        end

        previewFolder = Instance.new("Folder")
        previewFolder.Name = "PlacementPreview"
        previewFolder.Parent = workspace

        -- Calculate bounds
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

        local sizeX = maxX - minX
        local sizeY = maxY - minY

        -- Purple bounding box preview
        local previewPart = Instance.new("Part")
        previewPart.Size = Vector3.new(sizeX, 0.1, sizeY)
        previewPart.Anchored = true
        previewPart.CanCollide = false
        previewPart.Transparency = 0.7
        previewPart.Color = Color3.fromRGB(168, 85, 247)
        previewPart.Material = Enum.Material.Neon
        previewPart.Name = "BoundingBox"
        previewPart.Parent = previewFolder

        placementOffset = Vector2.new((minX + maxX) / 2, (minY + maxY) / 2)

        local placementConnection
        placementConnection = RunService.RenderStepped:Connect(function()
            if previewFolder and mouse.Hit then
                local hitPos = mouse.Hit.Position
                placementOffset = Vector2.new(hitPos.X, hitPos.Z)
                previewPart.Position = Vector3.new(hitPos.X, 0.5, hitPos.Z)
            end
        end)

        local placeConnection
        placeConnection = mouse.Button1Down:Connect(function()
            if isPlacementMode and not isSelectionMode then
                isPlacementMode = false
                placementConnection:Disconnect()
                placeConnection:Disconnect()

                cloningStatus:SetDesc("✅ Ready to draw")
                WindUI:Notify({
                    Title = "Cloning",
                    Content = "Position set! Click 'Draw' to draw.",
                    Duration = 3,
                    Icon = "check",
                })
            end
        end)

        WindUI:Notify({
            Title = "Cloning",
            Content = "Move to position, click to confirm",
            Duration = 3,
            Icon = "mouse-pointer",
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
    Title = "Draw Copied",
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
    if selectionBoundsBox then selectionBoundsBox:Destroy() end
    if selectionPlane then selectionPlane:Destroy() end
    if previewFolder then previewFolder:Destroy() end
    if liveUpdateConnection then task.cancel(liveUpdateConnection) end
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
        print("[FreeDraw] Image hidden (E pressed)")
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
        print("[FreeDraw] Image shown (E released)")
    end
end)

Window:SetToggleKey(Enum.KeyCode.RightControl)
Window:SelectTab(1)

print("[FreeDraw] Reference Image Placer loaded!")

WindUI:Notify({
    Title = "FreeDraw",
    Content = "Reference Image Placer ready!",
    Duration = 3,
    Icon = "check-circle",
})