--- Options > Mods: every installed mod, whether it loaded, and why not.
---
--- Also where Continue lands when a saved run was played with a different set of mods
--- (`Game:check_saved_run_mods`): the page then leads with what to install or remove before
--- that run can be resumed. The run itself is left on the card untouched.
---
--- The page is one scrolling column of wrapped lines, because a load error is free text of any
--- length and a 320 px screen will not fit a table of them.

local ModLoader = require("mod_loader")

local ModsUI = {}

local SCREEN_W, SCREEN_H = 320, 240
local LIST_X, LIST_Y, LIST_W = 14, 34, SCREEN_W - 28
local LIST_BOTTOM = SCREEN_H - 38
local LINE_GAP = 1

function ModsUI.open(game)
    game._menu_sub_state = "mods"
    game._mods_scroll = 0
    Sfx.play("paper1")
end

function ModsUI.close(game)
    game._menu_sub_state = "main"
    game._mods_continue_block = nil
    Sfx.play("cancel")
end

--- Every line the page shows, before wrapping: `{ text, colour_key, font = "small"|"medium" }`.
function ModsUI.lines(game)
    local out = {}
    local block = game._mods_continue_block
    if block then
        out[#out + 1] = { I18N.text("mods.mismatch_1", nil, "This run was saved with different mods."), "RED" }
        out[#out + 1] = { I18N.text("mods.mismatch_2", nil, "Change them to continue it:"), "RED" }
        for _, line in ipairs(ModLoader.describe_mismatch(block)) do
            out[#out + 1] = { "  " .. line, "WHITE" }
        end
        out[#out + 1] = { " ", "WHITE" }
    end
    local mods = ModLoader.mods or {}
    if #mods == 0 then
        out[#out + 1] = { I18N.text("mods.none", nil, "No mods installed."), "GREY" }
        out[#out + 1] = { I18N.text("mods.where", { dir = ModLoader.DIR }, "Put mods in " .. ModLoader.DIR .. "/ in the save folder."), "GREY" }
        return out
    end
    for _, mod in ipairs(mods) do
        local ok = mod.status == "loaded"
        out[#out + 1] = { ("%s  v%s"):format(mod.name or mod.id, mod.version or "?"),
            ok and "GREEN" or "RED", font = "medium" }
        if ok then
            local reg = mod.registered or {}
            local parts = {}
            for _, kind in ipairs({ { "jokers", "Joker" }, { "consumables", "Consumable" }, { "vouchers", "Voucher" }, { "deck_skins", "Card Art Set" } }) do
                local n = #(reg[kind[1]] or {})
                if n > 0 then
                    parts[#parts + 1] = I18N.text("mods.count." .. kind[1], { count = n },
                        ("%d %s%s"):format(n, kind[2], n == 1 and "" or "s"))
                end
            end
            if #parts == 0 then parts[1] = I18N.text("mods.nothing_added", nil, "Nothing added") end
            out[#out + 1] = { table.concat(parts, I18N.text("common.list_separator", nil, ", ")) .. ((mod.author ~= nil and mod.author ~= "")
                and I18N.text("mods.by", { author = mod.author }, "  -  by " .. mod.author) or ""), "GREY" }
        else
            out[#out + 1] = { I18N.text("mods.not_loaded", nil, "Not loaded: ") .. tostring(mod.error), "RED" }
        end
        for _, err in ipairs(mod.runtime_errors or {}) do
            out[#out + 1] = { I18N.text("mods.error", nil, "Error: ") .. tostring(err), "ORANGE" }
        end
    end
    out[#out + 1] = { " ", "WHITE" }
    out[#out + 1] = { I18N.text("mods.details", nil, "Details: ") .. ModLoader.LOG_PATH, "GREY" }
    return out
end

local function font_for(game, which)
    return which == "medium" and game.FONTS.PIXEL.MEDIUM or game.FONTS.PIXEL.SMALL
end

--- The lines wrapped to the list width: `{ text, colour, font, h }`.
local function wrapped(game)
    local out = {}
    for _, line in ipairs(ModsUI.lines(game)) do
        local font = font_for(game, line.font)
        local pieces = { line[1] }
        if font.getWrap then
            local _, w = font:getWrap(line[1], LIST_W)
            if type(w) == "table" and #w > 0 then pieces = w end
        end
        for _, piece in ipairs(pieces) do
            out[#out + 1] = { piece, line[2], font, font:getHeight() + LINE_GAP }
        end
    end
    return out
end

--- How far the list can scroll, in lines.
local function max_scroll(rows)
    local h, n = 0, 0
    for i = #rows, 1, -1 do
        h = h + rows[i][4]
        if h > LIST_BOTTOM - LIST_Y then break end
        n = n + 1
    end
    return math.max(0, #rows - n)
end

function ModsUI.draw(game)
    local C = game.C
    love.graphics.setColor(C.PANEL)
    love.graphics.rectangle("fill", 0, 0, SCREEN_W, SCREEN_H)
    love.graphics.setFont(game.FONTS.PIXEL.MEDIUM)
    love.graphics.setColor(C.WHITE)
    love.graphics.printf(I18N.text("menu.entry.mods", nil, "Mods"), 0, 10, SCREEN_W, "center")

    local rows = wrapped(game)
    local top = math.max(0, math.min(max_scroll(rows), math.floor(tonumber(game._mods_scroll) or 0)))
    game._mods_scroll = top
    local y = LIST_Y
    for i = top + 1, #rows do
        local row = rows[i]
        if y + row[4] > LIST_BOTTOM then break end
        love.graphics.setFont(row[3])
        love.graphics.setColor(C[row[2]] or C.WHITE)
        love.graphics.print(row[1], LIST_X, y)
        y = y + row[4]
    end
    if max_scroll(rows) > 0 then
        love.graphics.setFont(game.FONTS.PIXEL.SMALL)
        love.graphics.setColor(C.GREY)
        love.graphics.printf(I18N.text("mods.scroll_hint", nil, "Up/Down to scroll"), 0, LIST_BOTTOM + 1, SCREEN_W, "center")
    end

    game._mods_back_rect = { x = 20, y = SCREEN_H - 30, w = SCREEN_W - 40, h = 24 }
    local r = game._mods_back_rect
    love.graphics.setColor(C.MULT)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 4, 4)
    love.graphics.setColor(C.WHITE)
    love.graphics.setFont(game.FONTS.PIXEL.SMALL)
    local font = love.graphics.getFont()
    love.graphics.printf(I18N.text("common.back", nil, "Back"), r.x, r.y + math.floor((r.h - font:getHeight()) / 2), r.w, "center")
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", r.x + 0.5, r.y + 0.5, r.w - 1, r.h - 1)
end

function ModsUI.scroll(game, delta)
    game._mods_scroll = math.max(0, math.floor(tonumber(game._mods_scroll) or 0) + delta)
end

function ModsUI.handle_touch(game, x, y)
    local back = game._mods_back_rect
    if back and game:_point_in_rect_simple(x, y, back) then
        ModsUI.close(game)
        return true
    end
    -- Top and bottom halves of the list scroll, the way a thumb reaches for them.
    if y >= LIST_Y and y < LIST_BOTTOM then
        ModsUI.scroll(game, y < (LIST_Y + LIST_BOTTOM) / 2 and -3 or 3)
        return true
    end
    return false
end

function ModsUI.handle_button(game, btn)
    if btn == "dpup" or btn == "up" then
        ModsUI.scroll(game, -1)
    elseif btn == "dpdown" or btn == "down" then
        ModsUI.scroll(game, 1)
    elseif (game.is_menu_back and game:is_menu_back(btn))
        or (game.is_menu_activate and game:is_menu_activate(btn)) then
        ModsUI.close(game)
    end
end

return ModsUI
