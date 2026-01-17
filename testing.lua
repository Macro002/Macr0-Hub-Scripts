-- Rate Limiter Testing Script
-- Goal: Understand how the createLine rate limiter works

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- ============================================
-- DISCOVERY: Key game structures
-- ============================================
-- Player.Trackers (ObjectValue) -> Value = Collector(PlayerID)
--   └── Tracker(LayerID) (ObjectValue) -> Value = Layer(LayerID)
--       └── Attributes: id, index, name, visible
--
-- InsertService.InsertionHash (ObjectValue) -> Value = {GUID}
--   ^ This might track last insertion for rate limiting!
--
-- createLine args:
--   [1] GUID (string) - unique line identifier
--   [2] Table:
--       [1] LayerID (string)
--       [2] {color, transparency, thickness}
--       [3] {Vector2 points...}
-- ============================================

-- Find the createLine remote
local function findCreateLineRemote()
    local path = ReplicatedStorage:FindFirstChild("packages")
    if path then
        path = path:FindFirstChild("_Index")
        if path then
            path = path:FindFirstChild("vorlias_net@2.1.4")
            if path then
                path = path:FindFirstChild("net")
                if path then
                    path = path:FindFirstChild("_NetManaged")
                    if path then
                        return path:FindFirstChild("createLine")
                    end
                end
            end
        end
    end
    return nil
end

local createLineRemote = findCreateLineRemote()
print("[Test] createLine remote found:", createLineRemote ~= nil)

-- Generate GUID
local function generateGUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end):upper()
end

-- Get current layer ID
local function getCurrentLayerID()
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

-- Draw a simple test line
local function drawTestLine(x, z, length)
    local layerID = getCurrentLayerID()
    if not layerID or not createLineRemote then
        print("[Test] Missing layer or remote!")
        return false
    end

    local points = {
        Vector2.new(x, z),
        Vector2.new(x + length, z)
    }

    local success, err = pcall(function()
        createLineRemote:FireServer(
            generateGUID(),
            {
                layerID,
                {
                    color = Color3.fromRGB(255, 0, 0),
                    transparency = 0,
                    thickness = 0.3
                },
                points
            }
        )
    end)

    return success
end

-- ============================================
-- TEST 1: Burst test - how many lines before rate limit?
-- ============================================
local function testBurstLimit()
    print("\n[Test 1] BURST TEST - Drawing lines as fast as possible...")
    print("[Test 1] Watch for rate limit message in game...")

    local startTime = tick()
    local lineCount = 0

    for i = 1, 50 do
        local success = drawTestLine(i * 2, 0, 1)
        if success then
            lineCount = lineCount + 1
        end
        -- No delay - pure burst
    end

    local elapsed = tick() - startTime
    print("[Test 1] Drew " .. lineCount .. " lines in " .. string.format("%.3f", elapsed) .. "s")
    print("[Test 1] Rate: " .. string.format("%.1f", lineCount / elapsed) .. " lines/sec")
end

-- ============================================
-- TEST 2: Find the safe threshold
-- ============================================
local function testSafeThreshold(delay)
    print("\n[Test 2] THRESHOLD TEST - Delay: " .. delay .. "s")

    local lineCount = 0
    local startTime = tick()

    for i = 1, 30 do
        local success = drawTestLine(50 + i * 2, 10, 1)
        if success then
            lineCount = lineCount + 1
        end
        task.wait(delay)
    end

    local elapsed = tick() - startTime
    print("[Test 2] Drew " .. lineCount .. " lines in " .. string.format("%.2f", elapsed) .. "s")
    print("[Test 2] Effective rate: " .. string.format("%.2f", lineCount / elapsed) .. " lines/sec")
end

-- ============================================
-- TEST 3: Recovery time test
-- ============================================
local function testRecoveryTime()
    print("\n[Test 3] RECOVERY TEST - Trigger limit then test recovery...")

    -- First trigger the rate limit
    print("[Test 3] Triggering rate limit...")
    for i = 1, 20 do
        drawTestLine(100 + i * 2, 20, 1)
    end

    -- Now test recovery at different intervals
    local recoveryTimes = {1, 2, 3, 5}

    for _, waitTime in ipairs(recoveryTimes) do
        print("[Test 3] Waiting " .. waitTime .. " seconds...")
        task.wait(waitTime)

        local success = drawTestLine(100, 30 + waitTime * 5, 5)
        print("[Test 3] After " .. waitTime .. "s wait - Line drew: " .. tostring(success))
    end
end

-- ============================================
-- TEST 4: Packet inspection - what data is sent?
-- ============================================
local function inspectRemote()
    print("\n[Test 4] REMOTE INSPECTION")
    print("[Test 4] Remote name:", createLineRemote and createLineRemote.Name or "nil")
    print("[Test 4] Remote class:", createLineRemote and createLineRemote.ClassName or "nil")
    print("[Test 4] Remote parent:", createLineRemote and createLineRemote.Parent.Name or "nil")

    -- Check for any siblings that might be interesting
    if createLineRemote and createLineRemote.Parent then
        print("[Test 4] Sibling remotes in _NetManaged:")
        for _, child in ipairs(createLineRemote.Parent:GetChildren()) do
            print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
        end
    end
end

-- ============================================
-- TEST 5: Different GUID patterns
-- ============================================
local function testGUIDPatterns()
    print("\n[Test 5] GUID PATTERN TEST")

    -- Test with same GUID (might be rejected as duplicate?)
    local sameGUID = generateGUID()
    print("[Test 5] Testing with repeated GUID: " .. sameGUID)

    for i = 1, 5 do
        local layerID = getCurrentLayerID()
        if layerID and createLineRemote then
            createLineRemote:FireServer(
                sameGUID, -- Same GUID each time
                {
                    layerID,
                    {
                        color = Color3.fromRGB(0, 255, 0),
                        transparency = 0,
                        thickness = 0.3
                    },
                    {Vector2.new(150 + i * 3, 0), Vector2.new(150 + i * 3 + 2, 0)}
                }
            )
        end
        task.wait(0.5)
    end
    print("[Test 5] Check if all 5 green lines appeared or just 1")
end

-- ============================================
-- TEST 6: Points per line test
-- ============================================
local function testPointsPerLine()
    print("\n[Test 6] POINTS PER LINE TEST")
    print("[Test 6] Testing if many points in one line bypasses rate limit...")

    local layerID = getCurrentLayerID()
    if not layerID or not createLineRemote then return end

    -- Create one line with MANY points (essentially drawing multiple lines as one)
    local points = {}
    for i = 1, 100 do
        table.insert(points, Vector2.new(200 + i * 0.5, math.sin(i / 5) * 5))
    end

    local startTime = tick()
    createLineRemote:FireServer(
        generateGUID(),
        {
            layerID,
            {
                color = Color3.fromRGB(0, 0, 255),
                transparency = 0,
                thickness = 0.3
            },
            points
        }
    )
    local elapsed = tick() - startTime

    print("[Test 6] Sent 1 line with 100 points in " .. string.format("%.3f", elapsed) .. "s")
    print("[Test 6] Check if the wavy blue line appeared!")
end

-- ============================================
-- TEST 7: Monitor InsertionHash changes
-- ============================================
local function monitorInsertionHash()
    print("\n[Test 7] MONITORING InsertionHash...")

    -- Find InsertionHash
    local insertionHash = nil
    for _, child in ipairs(InsertService:GetChildren()) do
        print("[Test 7] InsertService child:", child.Name, child.ClassName)
        if child.Name == "InsertionHash" then
            insertionHash = child
        end
    end

    if not insertionHash then
        print("[Test 7] InsertionHash not found in InsertService!")
        print("[Test 7] Searching entire game...")

        -- Search workspace
        local found = workspace:FindFirstChild("InsertionHash", true)
        if found then
            print("[Test 7] Found in workspace:", found:GetFullName())
            insertionHash = found
        end
    end

    if insertionHash then
        print("[Test 7] Found InsertionHash!")
        print("[Test 7] Current value:", tostring(insertionHash.Value))
        print("[Test 7] ClassName:", insertionHash.ClassName)

        -- Monitor changes
        insertionHash.Changed:Connect(function(newValue)
            print("[Test 7] InsertionHash CHANGED to:", tostring(newValue))
        end)

        print("[Test 7] Now monitoring... draw some lines!")
    else
        print("[Test 7] Could not find InsertionHash anywhere")
    end
end

-- ============================================
-- TEST 8: Inspect player Trackers structure
-- ============================================
local function inspectTrackers()
    print("\n[Test 8] INSPECTING Player Trackers...")

    local trackers = player:FindFirstChild("Trackers")
    if not trackers then
        print("[Test 8] No Trackers found on player!")
        return
    end

    print("[Test 8] Trackers found!")
    print("[Test 8] Trackers.Value:", tostring(trackers.Value))
    print("[Test 8] Trackers children:")

    for _, tracker in ipairs(trackers:GetChildren()) do
        print("  - " .. tracker.Name .. " (" .. tracker.ClassName .. ")")
        print("    Value:", tostring(tracker.Value))

        -- Print attributes
        local attrs = tracker:GetAttributes()
        for attrName, attrValue in pairs(attrs) do
            print("    Attr[" .. attrName .. "]:", tostring(attrValue))
        end
    end
end

-- ============================================
-- TEST 9: Search for rate limit related code/values
-- ============================================
local function searchForRateLimitClues()
    print("\n[Test 9] SEARCHING for rate limit clues...")

    -- Check ReplicatedStorage for any rate/limit/throttle related items
    local keywords = {"rate", "limit", "throttle", "cooldown", "spam", "flood", "queue"}

    local function searchIn(parent, depth)
        if depth > 5 then return end
        for _, child in ipairs(parent:GetChildren()) do
            local nameLower = child.Name:lower()
            for _, keyword in ipairs(keywords) do
                if nameLower:find(keyword) then
                    print("[Test 9] FOUND:", child:GetFullName())
                end
            end
            searchIn(child, depth + 1)
        end
    end

    print("[Test 9] Searching ReplicatedStorage...")
    searchIn(ReplicatedStorage, 0)

    print("[Test 9] Searching ReplicatedFirst...")
    pcall(function()
        searchIn(game:GetService("ReplicatedFirst"), 0)
    end)

    print("[Test 9] Searching StarterPlayer...")
    pcall(function()
        searchIn(game:GetService("StarterPlayer"), 0)
    end)

    print("[Test 9] Search complete!")
end

-- ============================================
-- TEST 10: Decompile/inspect LocalScripts
-- ============================================
local function findLocalScripts()
    print("\n[Test 10] FINDING LocalScripts...")

    local scripts = {}

    local function searchScripts(parent, depth)
        if depth > 10 then return end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("LocalScript") or child:IsA("ModuleScript") then
                table.insert(scripts, child)
                print("[Test 10] Found:", child:GetFullName())
            end
            pcall(function()
                searchScripts(child, depth + 1)
            end)
        end
    end

    searchScripts(player.PlayerGui, 0)
    searchScripts(player.PlayerScripts, 0)
    pcall(function() searchScripts(game:GetService("ReplicatedFirst"), 0) end)

    print("[Test 10] Found " .. #scripts .. " scripts")
    print("[Test 10] Use decompile() in Dex on these to view source")

    return scripts
end

-- ============================================
-- TEST 11: Test if rate limit is per-layer
-- ============================================
local function testPerLayerRateLimit()
    print("\n[Test 11] TESTING if rate limit is per-layer...")
    print("[Test 11] Theory: Maybe each layer has its own rate limit?")

    -- Get all layer IDs
    local trackers = player:FindFirstChild("Trackers")
    if not trackers then
        print("[Test 11] No trackers found!")
        return
    end

    local layerIDs = {}
    for _, tracker in ipairs(trackers:GetChildren()) do
        local id = tracker:GetAttribute("id")
        if id then
            table.insert(layerIDs, id)
            print("[Test 11] Found layer:", id)
        end
    end

    if #layerIDs < 2 then
        print("[Test 11] Need at least 2 layers to test! Create another layer first.")
        return
    end

    print("[Test 11] Drawing 10 lines alternating between layers...")

    for i = 1, 10 do
        local layerID = layerIDs[(i % #layerIDs) + 1]

        createLineRemote:FireServer(
            generateGUID(),
            {
                layerID,
                {
                    color = Color3.fromRGB(255, 0, 0),
                    transparency = 0,
                    thickness = 0.3
                },
                {Vector2.new(i * 3, 50), Vector2.new(i * 3 + 2, 50)}
            }
        )
        print("[Test 11] Line " .. i .. " on layer " .. layerID)
    end

    print("[Test 11] Done! Check if rate limit was avoided by alternating layers")
end

-- ============================================
-- TEST 12: Extreme points test (the potential bypass)
-- ============================================
local function testExtremePoints()
    print("\n[Test 12] EXTREME POINTS TEST")
    print("[Test 12] Drawing 1 line with 500 points...")

    local layerID = getCurrentLayerID()
    if not layerID then
        print("[Test 12] No layer found!")
        return
    end

    -- Create a complex path with 500 points
    local points = {}
    for i = 1, 500 do
        local x = 250 + math.cos(i / 10) * (i / 20)
        local z = math.sin(i / 10) * (i / 20)
        table.insert(points, Vector2.new(x, z))
    end

    print("[Test 12] Sending line with " .. #points .. " points...")
    local startTime = tick()

    createLineRemote:FireServer(
        generateGUID(),
        {
            layerID,
            {
                color = Color3.fromRGB(255, 0, 255),
                transparency = 0,
                thickness = 0.2
            },
            points
        }
    )

    local elapsed = tick() - startTime
    print("[Test 12] Sent in " .. string.format("%.3f", elapsed) .. "s")
    print("[Test 12] Check for a purple spiral pattern!")
    print("[Test 12] If it appears, we can bypass rate limit with multi-point lines!")
end

-- ============================================
-- MENU
-- ============================================
print("\n========================================")
print("RATE LIMITER TESTING SCRIPT v2")
print("========================================")
print("Commands (run in executor):")
print("")
print("-- Basic Tests --")
print("  testBurstLimit()       -- Test max lines/sec")
print("  testSafeThreshold(0.1) -- Test with delay")
print("  testRecoveryTime()     -- Test cooldown recovery")
print("")
print("-- Discovery --")
print("  inspectRemote()        -- Inspect remote structure")
print("  inspectTrackers()      -- View player layer data")
print("  monitorInsertionHash() -- Watch for GUID tracking")
print("  searchForRateLimitClues() -- Search for keywords")
print("  findLocalScripts()     -- Find scripts to decompile")
print("")
print("-- Bypass Tests --")
print("  testGUIDPatterns()     -- Test GUID behavior")
print("  testPointsPerLine()    -- 100 points in 1 line")
print("  testExtremePoints()    -- 500 points spiral")
print("  testPerLayerRateLimit() -- Alternate layers")
print("========================================")

-- Auto-run some discovery
inspectRemote()
inspectTrackers()
