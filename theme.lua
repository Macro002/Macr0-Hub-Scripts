-- Macr0 Hub Theme
-- Load this in your scripts: loadstring(game:HttpGet("https://raw.githubusercontent.com/Macro002/Macr0-Hub-Scripts/main/theme.lua"))()

local WindUI = _G.WindUI or WindUI

if not WindUI then
    warn("[Macr0 Theme] WindUI not found - load WindUI first!")
    return
end

WindUI:AddTheme({
    Name = "Macr0",

    -- Core
    Accent = Color3.fromHex("#a855f7"),
    Background = Color3.fromHex("#15121f"),
    Outline = Color3.fromHex("#2a2535"),
    Text = Color3.fromHex("#ffffff"),
    Placeholder = Color3.fromHex("#888888"),
    Icon = Color3.fromHex("#a855f7"),
    Button = Color3.fromHex("#1c1828"),
    Hover = Color3.fromHex("#c084fc"),
    BackgroundTransparency = 0,

    -- Window - Dark purple base
    WindowBackground = Color3.fromHex("#0e0b14"),
    WindowShadow = Color3.fromHex("#000000"),

    -- Topbar - purple buttons
    WindowTopbarButtonIcon = Color3.fromHex("#a855f7"),
    WindowTopbarTitle = Color3.fromHex("#ffffff"),
    WindowTopbarAuthor = Color3.fromHex("#a855f7"),
    WindowTopbarIcon = Color3.fromHex("#a855f7"),

    -- Tabs - Darker purple for separation
    TabBackground = Color3.fromHex("#1a1528"),
    TabTitle = Color3.fromHex("#ffffff"),
    TabIcon = Color3.fromHex("#a855f7"),

    -- Elements - Slightly lighter so they pop
    ElementBackground = Color3.fromHex("#1c1828"),
    ElementTitle = Color3.fromHex("#ffffff"),
    ElementDesc = Color3.fromHex("#aaaaaa"),
    ElementIcon = Color3.fromHex("#a855f7"),

    -- Popups
    PopupBackground = Color3.fromHex("#18141f"),
    PopupBackgroundTransparency = 0,
    PopupTitle = Color3.fromHex("#ffffff"),
    PopupContent = Color3.fromHex("#cccccc"),
    PopupIcon = Color3.fromHex("#a855f7"),

    -- Dialogs
    DialogBackground = Color3.fromHex("#18141f"),
    DialogBackgroundTransparency = 0,
    DialogTitle = Color3.fromHex("#ffffff"),
    DialogContent = Color3.fromHex("#cccccc"),
    DialogIcon = Color3.fromHex("#a855f7"),

    -- Toggle - purple bar when on, white knob
    Toggle = Color3.fromHex("#a855f7"),
    ToggleBar = Color3.fromHex("#ffffff"),

    -- Checkbox
    Checkbox = Color3.fromHex("#2a2535"),
    CheckboxIcon = Color3.fromHex("#ffffff"),

    -- Slider
    Slider = Color3.fromHex("#2a2535"),
    SliderThumb = Color3.fromHex("#a855f7"),
})

WindUI:SetTheme("Macr0")

return true
