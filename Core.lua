local ADDON, ns = ...
local L = ns.L

local floor, min, max, abs, sin, pi, random = math.floor, math.min, math.max, math.abs, math.sin, math.pi, math.random
local format, pairs, ipairs, select, tostring = string.format, pairs, ipairs, select, tostring
local band = bit.band

local NAMEPLATE_BORDER = "Interface\\Tooltips\\Nameplate-Border"
local MINE = COMBATLOG_OBJECT_AFFILIATION_MINE or 0x00000001
local PET_OR_GUARDIAN = (COMBATLOG_OBJECT_TYPE_PET or 0x00001000) + (COMBATLOG_OBJECT_TYPE_GUARDIAN or 0x00002000)
local AUTO_SHOT, WAND = 75, 5019        -- ranged "auto attacks"
local MAX_TEXTS = 60
-- Blizzard_CombatText crit timings: grow to twice the size, then shrink back
local POP_GROW, POP_SHRINK = 0.05, 0.2
local LINE_GAP = 2                       -- classic mode: pixels between stacked numbers

local FONTS = {
    standard = STANDARD_TEXT_FONT,
    damage = DAMAGE_TEXT_FONT or STANDARD_TEXT_FONT,
    names = UNIT_NAME_FONT or STANDARD_TEXT_FONT,
    narrow = "Fonts\\ARIALN.TTF",
}

-- The old in-world damage text: white melee, yellow spells, green heals, red damage taken.
local CLASSIC = {
    auto = { 1, 1, 1 },
    spell = { 1, 1, 0 },
    heal = { 0, 1, 0 },
    miss = { 1, 1, 1 },
    taken = { 1, 0.1, 0.1 },
    takenHeal = { 0, 1, 0 },
}
ns.SCHOOLS = { 1, 2, 4, 8, 16, 32, 64 }
ns.COLOR_KEYS = { "auto", "spell", "dot", "pet", "crit", "heal", "miss", "taken", "takenHeal" }

local defaults = {
    enabled = true,
    font = "damage",
    size = 20,
    outline = "OUTLINE",
    alpha = 1,
    yOffset = 14,
    truncate = true,
    commas = false,

    periodic = true,
    pets = true,
    heals = false,
    misses = true,
    colorMode = "classic",                  -- classic | school | custom
    critColor = false,                      -- custom mode: crits get their own colour
    colors = {
        auto = { 1, 1, 1 },
        spell = { 1, 0.95, 0.2 },
        dot = { 1, 0.82, 0.35 },
        pet = { 0.85, 0.85, 1 },
        crit = { 1, 0.55, 0.1 },
        heal = { 0.35, 1, 0.45 },
        miss = { 0.75, 0.75, 0.75 },
        taken = { 1, 0.3, 0.25 },
        takenHeal = { 0.35, 1, 0.45 },
    },
    schools = {
        [1] = { 1.00, 0.95, 0.30 },   -- physical
        [2] = { 1.00, 0.90, 0.55 },   -- holy
        [4] = { 1.00, 0.52, 0.10 },   -- fire
        [8] = { 0.45, 1.00, 0.35 },   -- nature
        [16] = { 0.50, 0.90, 1.00 },  -- frost
        [32] = { 0.68, 0.52, 1.00 },  -- shadow
        [64] = { 1.00, 0.50, 1.00 },  -- arcane
    },
    icons = "left",
    hideBlizzard = false,
    personal = false,

    mode = "classic",
    laneSpacing = 40,                       -- classic mode: side columns; 0 = centre only                       -- classic: one column per plate, no overlaps; free: per-kind animations
    anim = { auto = "fountain", ability = "fountain", crit = "classic", miss = "up", heal = "up", personal = "down" },
    duration = 1.5,
    distance = 60,
    critScale = 1.5,
    pow = true,
    offTarget = true,
    offTargetScale = 0.7,
    offTargetAlpha = 0.55,
    petScale = 0.8,
}
ns.defaults = defaults

local db
local playerGUID

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff9482c9PlateSCT|r " .. msg)
end
ns.Print = Print

local function Copy(src, dst)
    dst = dst or {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = Copy(v, type(dst[k]) == "table" and dst[k] or {})
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

------------------------------------------------------------------------
-- Nameplates: which plate shows which GUID (no unit API on 3.3.5)
------------------------------------------------------------------------

local plates = {}       -- [plate] = { name = fontstring, highlight = texture }
local guidPlate = {}    -- [guid] = plate
local plateGuid = {}    -- [plate] = guid
local plateBoundName = {}

local function PlateName(plate)
    return plates[plate].name:GetText()
end

local function Unbind(plate)
    local guid = plateGuid[plate]
    if guid and guidPlate[guid] == plate then guidPlate[guid] = nil end
    plateGuid[plate], plateBoundName[plate] = nil, nil
end

local function Bind(plate, guid)
    if plateGuid[plate] == guid then return end
    local prev = guidPlate[guid]
    if prev and prev ~= plate then plateGuid[prev], plateBoundName[prev] = nil, nil end
    Unbind(plate)
    guidPlate[guid], plateGuid[plate], plateBoundName[plate] = plate, guid, PlateName(plate)
end

local function IsNameplate(f)
    if f:GetName() then return false end
    local _, border = f:GetRegions()
    return border and border.GetObjectType and border:GetObjectType() == "Texture"
        and border:GetTexture() == NAMEPLATE_BORDER
end

local numChildren = 0
local function ScanPlates()
    local n = WorldFrame:GetNumChildren()
    if n == numChildren then return end
    for i = numChildren + 1, n do
        local f = select(i, WorldFrame:GetChildren())
        if f and not plates[f] and IsNameplate(f) then
            local highlight, name = select(6, f:GetRegions()), select(7, f:GetRegions())
            plates[f] = { name = name, highlight = highlight }
            f:HookScript("OnHide", Unbind)
            f:HookScript("OnShow", Unbind)
        end
    end
    numChildren = n
end

-- The one visible plate called `name` that passes `test`, if exactly one does.
local function UniquePlate(name, test)
    local found
    for plate in pairs(plates) do
        if plate:IsShown() and PlateName(plate) == name and (not test or test(plate)) then
            if found then return end
            found = plate
        end
    end
    return found
end

local function IsTargetPlate(plate) return plate:GetAlpha() > 0.99 end
local function IsMousePlate(plate) return plates[plate].highlight:IsShown() end
local function Free(plate) return not plateGuid[plate] end

local targetChangedAt, mouseoverChangedAt = 0, 0

local function LearnPlates(now)
    for plate, info in pairs(plates) do
        if plateGuid[plate] and plateBoundName[plate] ~= info.name:GetText() then Unbind(plate) end
    end
    if UnitExists("target") and now - targetChangedAt > 0.15 then
        local plate = UniquePlate(UnitName("target"), IsTargetPlate)
        if plate then Bind(plate, UnitGUID("target")) end
    end
    if UnitExists("mouseover") and now - mouseoverChangedAt > 0.15 then
        local guid = UnitGUID("mouseover")
        local plate = UniquePlate(UnitName("mouseover"), IsMousePlate)
        -- mouseover only fills gaps; it never moves an existing link
        if plate and Free(plate) and not guidPlate[guid] then Bind(plate, guid) end
    end
end

local function StripRealm(name)
    return name and (name:match("^[^%-]+") or name)
end

-- Best plate for a combat log destination, or nil when it has none on screen.
local function PlateFor(guid, name)
    local api = WarlockPlatesAPI
    local plate = api and api.PlateFor and api.PlateFor(guid)
    if plate then return plate end

    plate = guidPlate[guid]
    if plate and plate:IsShown() then return plate end

    name = StripRealm(name)
    if not name then return end
    if guid == UnitGUID("target") then
        plate = UniquePlate(name, IsTargetPlate)
        if plate then return plate end
    end
    return UniquePlate(name, Free)
end

------------------------------------------------------------------------
-- Text engine
------------------------------------------------------------------------

local container = CreateFrame("Frame", "PlateSCTFrame", UIParent)
container:SetFrameStrata("MEDIUM")
container:SetAllPoints(UIParent)

local personalAnchor = CreateFrame("Frame", nil, UIParent)
personalAnchor:SetWidth(1)
personalAnchor:SetHeight(1)
personalAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, -60)

local pool, active = {}, {}

-- path(t, dir, dist) -> x, y for t in 0..1; dir is -1 or 1
local PATHS = {
    up = function(t, _, d) return 0, d * t end,
    down = function(t, _, d) return 0, -d * t end,
    fountain = function(t, dir, d) return dir * d * 0.6 * t, d * (1.8 * t - 2.2 * t * t) end,
    rainbow = function(t, dir, d) return dir * d * 0.8 * t, d * 0.5 * sin(pi * t) end,
    side = function(t, dir, d) return dir * d * t, 0 end,
    -- classic crit: hangs where it landed, then drifts up
    classic = function(t, _, d)
        if t < 0.35 then return 0, 0 end
        return 0, d * 0.6 * (t - 0.35) / 0.65
    end,
    shake = function(t)
        if t > 0.25 then return 0, 0 end
        return random(-4, 4), random(-3, 3)
    end,
}
ns.ANIMATIONS = { "fountain", "up", "down", "rainbow", "side", "classic", "shake", "off" }

local function Recycle(i)
    local f = active[i]
    f:Hide()
    table.remove(active, i)
    pool[#pool + 1] = f
end

local function Acquire()
    if #active >= MAX_TEXTS then Recycle(1) end
    local f = table.remove(pool)
    if not f then
        f = CreateFrame("Frame", nil, container)
        f:SetWidth(1)
        f:SetHeight(1)
        f.fs = f:CreateFontString(nil, "OVERLAY")
        f.fs:SetPoint("CENTER")
        f.fs:SetShadowOffset(1, -1)
    end
    active[#active + 1] = f
    return f
end

local function Place(f, now)
    local age = now - f.start
    local t = age / db.duration
    local x, y = f.path(t, f.dir, db.distance)

    -- Sizes go through SetFont: a parent's SetScale does not resize text on 3.3.5, and
    -- SetTextHeight only stretches the rendered glyphs, which blurs them.
    if f.popping then
        local h
        if age < POP_GROW then
            h = f.height * (1 + age / POP_GROW)
        elseif age < POP_GROW + POP_SHRINK then
            h = f.height * (2 - (age - POP_GROW) / POP_SHRINK)
        else
            h, f.popping = f.height, false
        end
        local size = floor(h + 0.5)
        if size ~= f.size then
            f.size = size
            f.fs:SetFont(f.font, size, f.flags)
        end
    end
    f:ClearAllPoints()
    -- whole pixels keep the text sharp
    f:SetPoint("CENTER", f.anchor, "CENTER", floor(f.x + x + 0.5), floor(f.y + y + f.push + 0.5))

    local a = 1
    if age < 0.06 and not f.pow then a = age / 0.06 elseif t > 0.7 then a = (1 - t) / 0.3 end
    f:SetAlpha(max(0, a) * f.alpha)
end

local function OnUpdate()
    local now = GetTime()
    for i = #active, 1, -1 do
        local f = active[i]
        if now - f.start >= db.duration or not f.anchor:IsShown() or f.push > db.distance * 2 then
            Recycle(i)
        else
            Place(f, now)
        end
    end
    if #active == 0 then container:SetScript("OnUpdate", nil) end
end

-- kind: auto | ability | crit | miss | heal | personal
-- Classic mode: numbers stack in columns (centre, left, right). In a column the
-- newest number must sit a full line above the new one; a column that is not
-- clear yet gets lifted.
local LANES = { 0, -1, 1 }
local laneCursor = setmetatable({}, { __mode = "k" })   -- [anchor] = last lane index
local serial = 0                                        -- spawn order; bursts share one GetTime()

local function Need(f, lane)
    local newest
    for _, o in ipairs(active) do
        if o ~= f and o.stacked and o.anchor == f.anchor and o.lane == lane
            and (not newest or o.serial > newest.serial) then
            newest = o
        end
    end
    if not newest then return 0 end
    local rise = db.distance * (f.start - newest.start) / db.duration
    return (newest.height + f.height) / 2 + LINE_GAP - (rise + newest.push)
end

local function MakeRoom(f)
    local count = db.laneSpacing > 0 and #LANES or 1
    local first = (laneCursor[f.anchor] or 0) % count + 1
    local best, bestNeed
    for k = 0, count - 1 do                     -- round robin, first clear column wins
        local idx = (first + k - 1) % count + 1
        local need = Need(f, LANES[idx])
        if need <= 0 then best, bestNeed = idx, 0 break end
        if not bestNeed or need < bestNeed then best, bestNeed = idx, need end
    end
    laneCursor[f.anchor] = best
    f.lane = LANES[best]
    -- laneSpacing is the gap from the centre line to the inner edge of a side number
    f.x = f.lane * (db.laneSpacing + f.fs:GetStringWidth() / 2)
    if bestNeed > 0 then
        for _, o in ipairs(active) do
            if o ~= f and o.stacked and o.anchor == f.anchor and o.lane == f.lane then o.push = o.push + bestNeed end
        end
    end
end

local function Spawn(anchor, text, color, kind, scale, alpha)
    local anim = db.anim[kind]
    local classic = db.mode == "classic"
    local path = PATHS[classic and anim ~= "off" and "up" or anim]
    if not path then return end

    local f = Acquire()
    local font = FONTS[db.font] or STANDARD_TEXT_FONT
    f.height = max(6, floor(db.size * (kind == "crit" and db.critScale or 1) * (scale or 1) + 0.5))
    f.font, f.flags, f.size = font, db.outline ~= "NONE" and db.outline or nil, f.height
    f.fs:SetFont(font, f.height, f.flags)
    f.fs:SetText(text)
    f.fs:SetTextColor(color[1], color[2], color[3])

    f.anchor, f.path, f.start = anchor, path, GetTime()
    f.dir = random(2) == 1 and -1 or 1
    f.alpha = db.alpha * (alpha or 1)
    f.pow = kind == "crit" and db.pow
    f.popping = f.pow
    serial = serial + 1
    f.push, f.stacked, f.serial = 0, classic, serial
    local base = anchor == personalAnchor and 0 or db.yOffset
    if classic then
        f.y = base
        MakeRoom(f)
    else
        local spread = anim == "shake" and 0 or 14
        f.x = random(-spread, spread)
        f.y = base + random(0, 8)
    end
    Place(f, f.start)
    f:Show()
    container:SetScript("OnUpdate", OnUpdate)
end

------------------------------------------------------------------------
-- Formatting
------------------------------------------------------------------------

local function Commas(n)
    local s = tostring(n)
    local k
    repeat s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end

local function Number(n)
    if db.truncate then
        if n >= 1e6 then return format("%.1fm", n / 1e6) end
        if n >= 1e4 then return format("%.1fk", n / 1e3) end
    end
    return db.commas and Commas(n) or tostring(n)
end

local iconCache = {}
local function Icon(spellId)
    if not spellId or db.icons == "none" then return end
    local icon = iconCache[spellId]
    if icon == nil then
        icon = select(3, GetSpellInfo(spellId)) or false
        iconCache[spellId] = icon
    end
    return icon and format("|T%s:0:0:0:0:64:64:5:59:5:59|t", icon) or nil
end

local function Decorate(text, spellId)
    local icon = Icon(spellId)
    if not icon then return text end
    local mode = db.icons
    if mode == "right" then return text .. " " .. icon end
    if mode == "both" then return icon .. " " .. text .. " " .. icon end
    return icon .. " " .. text
end

local function SchoolColor(school)
    local schools = db.schools
    if not school then return schools[1] end
    if schools[school] then return schools[school] end
    for i = #ns.SCHOOLS, 2, -1 do                -- multi-school: its highest magic bit
        local b = ns.SCHOOLS[i]
        if band(school, b) ~= 0 then return schools[b] end
    end
    return schools[1]
end

-- key: auto | spell | dot | heal | miss | taken | takenHeal
local function Color(key, school, isPet, critical)
    local mode, c = db.colorMode, db.colors
    if mode == "classic" then
        return CLASSIC[key] or CLASSIC.spell
    end
    if mode == "custom" then
        if critical and db.critColor and key ~= "miss" then return c.crit end
        if isPet and (key == "auto" or key == "spell" or key == "dot") then return c.pet end
        return c[key]
    end
    if key == "spell" or key == "dot" then return SchoolColor(school) end
    return c[key]
end

function ns.ResetColors()
    db.colors = Copy(defaults.colors)
    db.schools = Copy(defaults.schools)
end

local function MissText(missType)
    return _G[missType] or missType
end

------------------------------------------------------------------------
-- Combat log (3.3.5 argument order, no hideCaster)
------------------------------------------------------------------------

local DAMAGE = { SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true, DAMAGE_SHIELD = true, SPELL_BUILDING_DAMAGE = true }
local MISSED = { SPELL_MISSED = true, SPELL_PERIODIC_MISSED = true, RANGE_MISSED = true, DAMAGE_SHIELD_MISSED = true }
local HEALED = { SPELL_HEAL = true, SPELL_PERIODIC_HEAL = true }

local function Outgoing(event, dstGUID, dstName, isPet, ...)
    local spellId, school, amount, critical, missType
    if event == "SWING_DAMAGE" then
        amount, school, critical = (...), select(3, ...), select(7, ...)
    elseif DAMAGE[event] then
        spellId, amount, school, critical = (...), select(4, ...), select(6, ...), select(10, ...)
    elseif event == "SWING_MISSED" then
        missType = ...
    elseif MISSED[event] then
        spellId, missType = (...), select(4, ...)
    elseif HEALED[event] then
        if not db.heals then return end
        local amt, over
        spellId, amt, over, critical = (...), select(4, ...), select(5, ...), select(7, ...)
        amount = amt - (over or 0)
        if amount <= 0 then return end
    else
        return
    end
    if not db.periodic and (event == "SPELL_PERIODIC_DAMAGE" or event == "SPELL_PERIODIC_MISSED") then return end
    if missType and not db.misses then return end

    local plate = PlateFor(dstGUID, dstName)
    if not plate then return end

    local scale, alpha = isPet and db.petScale or 1, 1
    if dstGUID ~= UnitGUID("target") then
        if not db.offTarget then return end
        scale, alpha = scale * db.offTargetScale, db.offTargetAlpha
    end

    local auto = event:sub(1, 5) == "SWING" or spellId == AUTO_SHOT or spellId == WAND
    if missType then
        Spawn(plate, Decorate(MissText(missType), not auto and spellId), Color("miss"), "miss", scale, alpha)
    elseif HEALED[event] then
        Spawn(plate, Decorate("+" .. Number(amount), spellId), Color("heal", nil, isPet, critical),
            critical and "crit" or "heal", scale, alpha)
    elseif amount and amount > 0 then
        local kind = critical and "crit" or (auto and "auto" or "ability")
        local key = auto and "auto" or (event == "SPELL_PERIODIC_DAMAGE" and "dot" or "spell")
        Spawn(plate, Decorate(Number(amount), not auto and spellId), Color(key, school, isPet, critical), kind, scale, alpha)
    end
end

local function Incoming(event, ...)
    local amount, missType, heal
    if event == "SWING_DAMAGE" then
        amount = ...
    elseif DAMAGE[event] or event == "ENVIRONMENTAL_DAMAGE" then
        amount = event == "ENVIRONMENTAL_DAMAGE" and select(2, ...) or select(4, ...)
    elseif event == "SWING_MISSED" then
        missType = ...
    elseif MISSED[event] then
        missType = select(4, ...)
    elseif HEALED[event] then
        amount = select(4, ...) - (select(5, ...) or 0)
        heal = true
    else
        return
    end
    if missType then
        if db.misses then Spawn(personalAnchor, MissText(missType), Color("miss"), "personal") end
    elseif amount and amount > 0 then
        Spawn(personalAnchor, (heal and "+" or "-") .. Number(amount), Color(heal and "takenHeal" or "taken"), "personal")
    end
end

local function OnCombatLog(_, event, srcGUID, _, srcFlags, dstGUID, dstName, _, ...)
    if dstGUID == playerGUID then
        if db.personal then Incoming(event, ...) end
        return
    end
    if srcGUID == playerGUID then
        Outgoing(event, dstGUID, dstName, false, ...)
    elseif db.pets and srcFlags and band(srcFlags, MINE) ~= 0 and band(srcFlags, PET_OR_GUARDIAN) ~= 0 then
        Outgoing(event, dstGUID, dstName, true, ...)
    end
end

------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------

local function ApplyBlizzard()
    local v = db.hideBlizzard and "0" or "1"
    if db.hideBlizzard or db.blizzardHidden then
        SetCVar("CombatDamage", v)
        SetCVar("CombatHealing", v)
    end
    db.blizzardHidden = db.hideBlizzard or nil
end

local driver = CreateFrame("Frame")

function ns.Refresh()
    ApplyBlizzard()
    if db.enabled then
        driver:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    else
        driver:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    end
end

function ns.ResetSettings()
    local hidden = db and db.blizzardHidden
    PlateSCTDB = Copy(defaults)
    db = PlateSCTDB
    db.version = 2
    db.blizzardHidden = hidden            -- so the CVars get restored
    ns.db = db
    ns.Refresh()
end

-- Sample numbers on the target's plate (or the screen centre without one).
local SAMPLES = {
    { 1234, 32, "ability", 47809 }, { 3802, 32, "crit", 47843 }, { 612, 32, "ability", 47813, true },
    { 845, 1, "auto" }, { "MISS", nil, "miss" }, { 2210, 4, "ability", 47811 },
    { 5120, 4, "crit", 47825 }, { 731, 32, "ability", 47864, true },
}
local queue = {}

function ns.Test()
    local plate = UnitExists("target") and PlateFor(UnitGUID("target"), UnitName("target"))
    if not plate then Print(L["no visible nameplate on your target; showing in the centre"]) end
    local now = GetTime()
    for i, s in ipairs(SAMPLES) do
        queue[#queue + 1] = { at = now + i * 0.22, sample = s, anchor = plate or personalAnchor }
    end
end

local function RunQueue(now)
    for i = #queue, 1, -1 do
        local q = queue[i]
        if now >= q.at then
            table.remove(queue, i)
            local amount, school, kind, spellId = q.sample[1], q.sample[2], q.sample[3], q.sample[4]
            local text = kind == "miss" and MissText(amount) or Number(amount)
            local key = kind == "miss" and "miss" or (kind == "auto" and "auto" or (q.sample[5] and "dot" or "spell"))
            local color = Color(key, school, false, kind == "crit")
            Spawn(q.anchor, Decorate(text, spellId), color, kind)
        end
    end
end

------------------------------------------------------------------------
-- Driver
------------------------------------------------------------------------

local elapsedSince = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    ScanPlates()
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < 0.1 then return end
    elapsedSince = 0
    local now = GetTime()
    LearnPlates(now)
    if #queue > 0 then RunQueue(now) end
end)

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_TARGET_CHANGED")
driver:RegisterEvent("UPDATE_MOUSEOVER_UNIT")

driver:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog(...)
    elseif event == "PLAYER_TARGET_CHANGED" then
        targetChangedAt = GetTime()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        mouseoverChangedAt = GetTime()
    elseif event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        PlateSCTDB = Copy(defaults, PlateSCTDB)
        db = PlateSCTDB
        if (db.version or 1) < 2 then          -- 1.1: crits default to the classic pop
            db.anim.crit, db.version = "classic", 2
        end
        ns.db = db
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        ns.Refresh()
    end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------

SLASH_PLATESCT1 = "/psct"
SLASH_PLATESCT2 = "/platesct"
SlashCmdList.PLATESCT = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "test" then
        ns.Test()
    elseif cmd == "toggle" then
        db.enabled = not db.enabled
        ns.Refresh()
        Print(db.enabled and L["on"] or L["off"])
    elseif cmd == "reset" then
        ns.ResetSettings()
        if ns.OnOptionsChanged then ns.OnOptionsChanged() end
        Print(L["settings reset"])
    elseif cmd == "" then
        ns.OpenOptions()
    else
        Print(L["/psct - options, /psct test - sample, /psct toggle, /psct reset"])
    end
end
