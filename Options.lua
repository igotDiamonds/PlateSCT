local _, ns = ...

local L = ns.L

local floor, format, ipairs = math.floor, string.format, ipairs

local ACCENT = { 0.58, 0.51, 0.79 }   -- warlock class colour
local WHITE = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------------------
-- Widget helpers: every widget gets :Refresh() which reads the setting
------------------------------------------------------------------------

local widgets = {}
local uid = 0

local function NextName()
    uid = uid + 1
    return "PlateSCTOption" .. uid
end

local function RefreshAll()
    for _, w in ipairs(widgets) do w:Refresh() end
end
ns.OnOptionsChanged = RefreshAll

local function Changed()
    ns.Refresh()
end

local function Tip(frame, title, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if text then GameTooltip:AddLine(text, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true) end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

local function Header(parent, text, x, y, width)
    local h = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    h:SetPoint("TOPLEFT", x, y)
    h:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(WHITE)
    line:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.45)
    line:SetHeight(1)
    line:SetWidth(width or 270)
    line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -4)
    return h
end

local function Check(parent, label, tip, x, y, get, set)
    local cb = CreateFrame("CheckButton", NextName(), parent, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    _G[cb:GetName() .. "Text"]:SetText(label)
    cb:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        PlaySound(on and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        set(on)
        Changed()
    end)
    Tip(cb, label, tip)
    cb.Refresh = function(self) self:SetChecked(get() and true or false) end
    widgets[#widgets + 1] = cb
    return cb
end

local function Slider(parent, label, tip, x, y, lo, hi, step, fmt, get, set)
    local name = NextName()
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", x, y)
    s:SetWidth(250)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    _G[name .. "Low"]:SetText(fmt(lo))
    _G[name .. "High"]:SetText(fmt(hi))
    local text = _G[name .. "Text"]

    local function Label(v)
        text:SetText(label .. ":  |cffffffff" .. fmt(v) .. "|r")
    end

    s:SetScript("OnValueChanged", function(self, v)
        v = tonumber(format("%.3f", floor(v / step + 0.5) * step))
        Label(v)
        if self.refreshing or v == get() then return end
        set(v)
        Changed()
    end)
    Tip(s, label, tip)
    s.Refresh = function(self)
        self.refreshing = true
        self:SetValue(get())
        self.refreshing = false
        Label(get())
    end
    widgets[#widgets + 1] = s
    return s
end

local function Dropdown(parent, label, x, y, options, get, set)
    local name = NextName()
    local caption = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    caption:SetPoint("TOPLEFT", x, y)
    caption:SetText(label)

    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", -16, -3)
    UIDropDownMenu_SetWidth(dd, 190)

    local function TextFor(v)
        for _, o in ipairs(options) do
            if o[1] == v then return o[2] end
        end
        return ""
    end

    dd.Refresh = function() _G[name .. "Text"]:SetText(TextFor(get())) end

    UIDropDownMenu_Initialize(dd, function()
        for _, o in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = o[2], o[1]
            info.checked = get() == o[1]
            info.func = function()
                set(o[1])
                Changed()
                RefreshAll()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    widgets[#widgets + 1] = dd
    return dd
end

-- A colour square that opens the standard colour picker; colours are {r, g, b} arrays.
local function Swatch(parent, get)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(18)
    b:SetHeight(18)
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    b:SetBackdropBorderColor(0, 0, 0, 1)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(WHITE)
    hl:SetAllPoints()
    hl:SetBlendMode("ADD")
    hl:SetVertexColor(1, 1, 1, 0.2)

    b.Refresh = function()
        local c = get()
        b:SetBackdropColor(c[1], c[2], c[3])
    end

    b:SetScript("OnClick", function()
        local c = get()
        ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        ColorPickerFrame.hasOpacity, ColorPickerFrame.opacityFunc = false, nil
        ColorPickerFrame.previousValues = { c[1], c[2], c[3] }
        ColorPickerFrame.func = function()
            c[1], c[2], c[3] = ColorPickerFrame:GetColorRGB()
            b.Refresh()
        end
        ColorPickerFrame.cancelFunc = function(prev)
            c[1], c[2], c[3] = prev[1], prev[2], prev[3]
            b.Refresh()
        end
        ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
        ColorPickerFrame:Hide()
        ShowUIPanel(ColorPickerFrame)
    end)
    Tip(b, L["Click to change the colour"])

    widgets[#widgets + 1] = b
    return b
end

local function ColorRow(parent, label, x, y, get)
    local sw = Swatch(parent, get)
    sw:SetPoint("TOPLEFT", x, y)
    local text = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", sw, "RIGHT", 8, 0)
    text:SetText(label)
    return sw
end

local function Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(width)
    b:SetHeight(22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end


------------------------------------------------------------------------
-- Panels
------------------------------------------------------------------------

local function NewPanel(name, parent, title, subtitle)
    local f = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
    f.name, f.parent = name, parent
    f:Hide()

    local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText(title)

    local s = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    s:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    s:SetJustifyH("LEFT")
    s:SetText(subtitle)

    f.default = function()
        ns.ResetSettings()
        RefreshAll()
    end
    f:SetScript("OnShow", function(self)
        if self.Build then
            self:Build()
            self.Build = nil
        end
        RefreshAll()
    end)
    InterfaceOptions_AddCategory(f)
    return f
end

StaticPopupDialogs.PLATESCT_RESET = {
    text = L["Reset all PlateSCT settings?"],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        ns.ResetSettings()
        RefreshAll()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
}

local function DB() return ns.db end

local function Int(v) return format("%d", v) end
local function Pct(v) return format("%d%%", v * 100 + 0.5) end
local function Dec(v) return format("%.1f", v) end
local function Sec(v) return format("%.1f", v) .. " " .. SECONDS_ABBR end

local function Key(key)
    return function() return DB()[key] end, function(v) DB()[key] = v end
end

local function Anim(kind)
    return function() return DB().anim[kind] end, function(v) DB().anim[kind] = v end
end

-- Page 1: text and sources ------------------------------------------

local main = NewPanel("PlateSCT", nil, "|cff9482c9Plate|rSCT",
    L["Combat text that flies out of nameplates. Changes apply instantly."])

function main:Build()
    local L1, R1 = 16, 330

    Header(self, L["Text"], L1, -72)
    Check(self, L["Enabled"], nil, L1, -90, Key("enabled"))
    Dropdown(self, L["Font"], L1, -124,
        { { "damage", L["Damage"] }, { "standard", L["Standard"] }, { "names", L["Unit names"] }, { "narrow", L["Narrow"] } },
        Key("font"))
    Slider(self, L["Font size"], nil, L1 + 4, -190, 10, 40, 1, Int, Key("size"))
    Dropdown(self, L["Outline"], L1, -218,
        { { "NONE", L["None"] }, { "OUTLINE", L["Thin"] }, { "THICKOUTLINE", L["Thick"] } }, Key("outline"))
    Slider(self, L["Opacity"], nil, L1 + 4, -284, 0.1, 1, 0.05, Pct, Key("alpha"))
    Slider(self, L["Height above the plate"], nil, L1 + 4, -329, -40, 80, 1, Int, Key("yOffset"))
    Check(self, L["Shorten large numbers (12.3k)"], nil, L1, -357, Key("truncate"))
    Check(self, L["Thousands separators"], nil, L1, -383, Key("commas"))

    Header(self, L["What to show"], R1, -72)
    Check(self, L["Damage over time"], nil, R1, -90, Key("periodic"))
    Check(self, L["Pet and guardian damage"], nil, R1, -116, Key("pets"))
    Check(self, L["Healing"], nil, R1, -142, Key("heals"))
    Check(self, L["Misses, dodges, resists"], nil, R1, -168, Key("misses"))
    Dropdown(self, L["Spell icons"], R1, -194,
        { { "left", L["Left"] }, { "right", L["Right"] }, { "both", L["Both sides"] }, { "none", L["None"] } },
        Key("icons"))
    Check(self, L["Hide Blizzard damage numbers"], L["Turns off the default floating damage and healing over the target."],
        R1, -246, Key("hideBlizzard"))
    Check(self, L["Incoming damage and healing"], L["Shows what you take below your character, in the middle of the screen."],
        R1, -272, Key("personal"))

    local test = Button(self, L["Try it"], 140, ns.Test)
    test:SetPoint("TOPLEFT", R1, -316)
    Tip(test, L["Try it"], L["Shows sample numbers on your target's nameplate."])

    local reset = Button(self, L["Reset all settings"], 180, function() StaticPopup_Show("PLATESCT_RESET") end)
    reset:SetPoint("LEFT", test, "RIGHT", 8, 0)
end

-- Page 2: animation --------------------------------------------------

local anim = NewPanel(L["Animation"], "PlateSCT", L["Animation"], L["How each kind of text moves."])

function anim:Build()
    local L1, R1 = 16, 330
    local NAMES = { fountain = L["Fountain"], up = L["Up"], down = L["Down"], rainbow = L["Rainbow"],
        side = L["Sideways"], classic = L["Classic"], shake = L["Shake"], off = L["Off"] }
    local options = {}
    for _, a in ipairs(ns.ANIMATIONS) do options[#options + 1] = { a, NAMES[a] } end

    Header(self, L["Animation"], L1, -72)
    Dropdown(self, L["Mode"], L1, -90,
        { { "classic", L["Classic: columns, no overlaps"] }, { "free", L["Free: animations below"] } }, Key("mode"))
    Slider(self, L["Side columns"], L["Classic mode: gap between the centre line and the left and right columns. 0 keeps a single column."],
        L1 + 4, -152, 0, 120, 5, Int, Key("laneSpacing"))
    local kinds = {
        { "auto", L["Auto attacks"] }, { "ability", L["Abilities"] }, { "crit", L["Critical hits"] },
        { "miss", L["Misses"] }, { "heal", L["Heals"] }, { "personal", L["Incoming"] },
    }
    for i, k in ipairs(kinds) do
        Dropdown(self, k[2], L1, -180 - (i - 1) * 42, options, Anim(k[1]))
    end

    local test = Button(self, L["Try it"], 140, ns.Test)
    test:SetPoint("TOPLEFT", L1, -440)
    Tip(test, L["Try it"], L["Shows sample numbers on your target's nameplate."])

    Header(self, L["Text"], R1, -72)
    Slider(self, L["Duration"], nil, R1 + 4, -110, 0.6, 3, 0.1, Sec, Key("duration"))
    Slider(self, L["Distance"], nil, R1 + 4, -155, 20, 150, 5, Int, Key("distance"))
    Slider(self, L["Critical size"], nil, R1 + 4, -200, 1, 3, 0.1, Dec, Key("critScale"))
    Check(self, L["Crits pop"], L["A critical hit starts big and snaps to size."], R1, -228, Key("pow"))
    Check(self, L["Show on other nameplates"], L["Text on mobs you are not targeting is smaller and fainter."],
        R1, -254, Key("offTarget"))
    Slider(self, L["Size on other targets"], nil, R1 + 4, -300, 0.3, 1, 0.05, Pct, Key("offTargetScale"))
    Slider(self, L["Opacity on other targets"], nil, R1 + 4, -345, 0.1, 1, 0.05, Pct, Key("offTargetAlpha"))
    Slider(self, L["Pet text size"], nil, R1 + 4, -390, 0.3, 1.5, 0.05, Pct, Key("petScale"))
end

-- Page 3: colours -----------------------------------------------------

local colours = NewPanel(L["Colours"], "PlateSCT", L["Colours"],
    L["Classic: white melee, yellow spells. By school: spells take their school's colour. Custom: every kind uses the colours below."])

function colours:Build()
    local L1, R1 = 16, 330

    Header(self, L["Colour mode"], L1, -72)
    Dropdown(self, L["Colour mode"], L1, -90,
        { { "classic", L["Classic"] }, { "school", L["By spell school"] }, { "custom", L["Custom"] } }, Key("colorMode"))
    Check(self, L["Own colour for crits"], L["Custom mode: critical hits use the Critical hits colour."], R1, -100, Key("critColor"))

    local NAMES = {
        auto = L["Auto attacks"], spell = L["Spells"], dot = L["Damage over time"], pet = L["Pet"],
        crit = L["Critical hits"], heal = L["Heals"], miss = L["Misses"], taken = L["Damage taken"], takenHeal = L["Healing taken"],
    }
    Header(self, L["Kinds"], L1, -150)
    for i, key in ipairs(ns.COLOR_KEYS) do
        ColorRow(self, NAMES[key], L1, -170 - (i - 1) * 26, function() return DB().colors[key] end)
    end

    local SCHOOL_NAMES = {
        [1] = STRING_SCHOOL_PHYSICAL or "Physical", [2] = STRING_SCHOOL_HOLY or "Holy", [4] = STRING_SCHOOL_FIRE or "Fire",
        [8] = STRING_SCHOOL_NATURE or "Nature", [16] = STRING_SCHOOL_FROST or "Frost",
        [32] = STRING_SCHOOL_SHADOW or "Shadow", [64] = STRING_SCHOOL_ARCANE or "Arcane",
    }
    Header(self, L["Spell schools"], R1, -150)
    for i, school in ipairs(ns.SCHOOLS) do
        ColorRow(self, SCHOOL_NAMES[school], R1, -170 - (i - 1) * 26, function() return DB().schools[school] end)
    end

    local test = Button(self, L["Try it"], 140, ns.Test)
    test:SetPoint("TOPLEFT", L1, -420)
    Tip(test, L["Try it"], L["Shows sample numbers on your target's nameplate."])

    local reset = Button(self, L["Reset colours"], 180, function()
        ns.ResetColors()
        RefreshAll()
    end)
    reset:SetPoint("LEFT", test, "RIGHT", 8, 0)
end

function ns.OpenOptions()
    -- 3.3.5 needs two calls the first time to scroll to and select the panel
    InterfaceOptionsFrame_OpenToCategory(main)
    InterfaceOptionsFrame_OpenToCategory(main)
end
