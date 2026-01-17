-- Rate Limiter Testing Script v4
-- Auto-runs tests, no manual function calls needed

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Your current position area
local BASE_X = -790
local BASE_Z = 394

print("\n========================================")
print("RATE LIMITER TESTING SCRIPT v4")
print("========================================")

-- Find createLine remote
local createLineRemote = ReplicatedStorage
    :WaitForChild("packages")
    :WaitForChild("_Index")
    :WaitForChild("vorlias_net@2.1.4")
    :WaitForChild("net")
    :WaitForChild("_NetManaged")
    :WaitForChild("createLine")

print("[Setup] createLine remote found:", createLineRemote ~= nil)

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
    local trackers = player:FindFirstChild("Trackers")
    if trackers then
        for _, tracker in ipairs(trackers:GetChildren()) do
            local id = tracker:GetAttribute("id")
            if id then
                print("[Setup] Found layer ID:", id)
                return id
            end
        end
    end

    -- Fallback: check workspace
    local container = workspace:FindFirstChild("Container(Drawing)")
    if container then
        local myCollector = container:FindFirstChild("Collector(" .. player.UserId .. ")")
        if myCollector then
            for _, layer in ipairs(myCollector:GetChildren()) do
                if layer.Name:match("^Layer%(") then
                    local id = layer.Name:match("%((.+)%)")
                    print("[Setup] Found layer ID from workspace:", id)
                    return id
                end
            end
        end
    end
    return nil
end

local layerID = getCurrentLayerID()
if not layerID then
    warn("[Setup] NO LAYER FOUND! Make sure you have a layer selected in the game.")
    return
end

print("[Setup] Using layer:", layerID)
print("[Setup] Drawing near position:", BASE_X, BASE_Z)
print("")

-- ============================================
-- TEST 1: Single line with many points (BYPASS TEST)
-- ============================================
print("[Test 1] MULTI-POINT LINE TEST")
print("[Test 1] Drawing 1 line with 200 points...")

local points = {}
for i = 1, 200 do
    -- Create a spiral pattern
    local angle = i * 0.1
    local radius = i * 0.05
    local x = BASE_X + math.cos(angle) * radius
    local z = BASE_Z + math.sin(angle) * radius
    table.insert(points, Vector2.new(x, z))
end

createLineRemote:FireServer(
    generateGUID(),
    {
        layerID,
        {
            color = Color3.fromRGB(255, 0, 255), -- Purple
            transparency = 0,
            thickness = 0.2
        },
        points
    }
)

print("[Test 1] SENT! Look for a PURPLE SPIRAL near your position")
print("[Test 1] If it appears = BYPASS CONFIRMED (points don't count toward limit)")
print("")

task.wait(1)

-- ============================================
-- TEST 2: Burst test - rapid fire lines
-- ============================================
print("[Test 2] BURST TEST - 20 lines as fast as possible")

local startTime = tick()
for i = 1, 20 do
    createLineRemote:FireServer(
        generateGUID(),
        {
            layerID,
            {
                color = Color3.fromRGB(255, 0, 0), -- Red
                transparency = 0,
                thickness = 0.3
            },
            {
                Vector2.new(BASE_X + 20 + i, BASE_Z),
                Vector2.new(BASE_X + 20 + i + 0.5, BASE_Z + 2)
            }
        }
    )
end
local elapsed = tick() - startTime

print("[Test 2] Sent 20 lines in " .. string.format("%.3f", elapsed) .. "s")
print("[Test 2] Look for RED LINES to the right of spiral")
print("[Test 2] If you see 'too fast' message, rate limit kicked in around line 15-20")
print("")

task.wait(2)

-- ============================================
-- TEST 3: Safe rate test
-- ============================================
print("[Test 3] SAFE RATE TEST - 10 lines with 0.5s delay")

for i = 1, 10 do
    createLineRemote:FireServer(
        generateGUID(),
        {
            layerID,
            {
                color = Color3.fromRGB(0, 255, 0), -- Green
                transparency = 0,
                thickness = 0.3
            },
            {
                Vector2.new(BASE_X + 50 + i * 2, BASE_Z),
                Vector2.new(BASE_X + 50 + i * 2, BASE_Z + 3)
            }
        }
    )
    print("[Test 3] Line " .. i .. " sent")
    task.wait(0.5)
end

print("[Test 3] Look for GREEN LINES further right")
print("[Test 3] These should all appear without rate limit")
print("")

-- ============================================
-- TEST 4: Mega line test
-- ============================================
print("[Test 4] MEGA LINE - 500 points in one line")

local megaPoints = {}
for i = 1, 500 do
    local x = BASE_X - 30 + (i % 50) * 0.5
    local z = BASE_Z - 20 + math.floor(i / 50) * 2
    table.insert(megaPoints, Vector2.new(x, z))
end

createLineRemote:FireServer(
    generateGUID(),
    {
        layerID,
        {
            color = Color3.fromRGB(0, 255, 255), -- Cyan
            transparency = 0,
            thickness = 0.15
        },
        megaPoints
    }
)

print("[Test 4] SENT! Look for CYAN zigzag pattern to the left")
print("[Test 4] 500 points in 1 request = only 1 toward rate limit!")
print("")

-- ============================================
-- RESULTS
-- ============================================
print("========================================")
print("RESULTS SUMMARY")
print("========================================")
print("Look for these colors:")
print("  PURPLE SPIRAL - Multi-point bypass test")
print("  RED LINES     - Burst test (may be incomplete if rate limited)")
print("  GREEN LINES   - Safe rate test (should be complete)")
print("  CYAN ZIGZAG   - Mega 500-point line")
print("")
print("CONCLUSION:")
print("If purple spiral and cyan zigzag appear fully,")
print("the BYPASS IS CONFIRMED - use multi-point lines!")
print("========================================")
