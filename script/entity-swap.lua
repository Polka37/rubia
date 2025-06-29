--Derived from Maraxsis
--This file focuses on swapping a specific entity with another while on rubia.
local entity_swap = {}

--Dic of: entity while outside rubia => entity while on rubia
local swap_target_rubia = {
    ["rocket-silo"] = "rubia-rocket-silo",
}
--Find auto-generated prototypes
local prefix = rubia.RUBIA_AUTO_ENTITY_PREFIX
for name, _ in pairs(prototypes.entity) do
    if string.sub(name, 1, string.len(prefix)) == prefix then
        local orig_name = string.sub(name, string.len(prefix) + 1, -1)
        swap_target_rubia[orig_name] = prefix .. orig_name
    end
end

local swap_target_outside_rubia={}
for key, value in pairs(swap_target_rubia) do
    swap_target_outside_rubia[value] = key
end

--True if the given entity is supposed to be swappable
local function is_swappable_entity(entity)
    local name = entity.name == "entity-ghost" and entity.ghost_name or entity.name
    return swap_target_rubia[name] or swap_target_outside_rubia[name]
end

--On an event triggered by a building action, check to see if we need to do an entity swap. If so, then do it!
entity_swap.try_entity_swap = function(entity, player_index)
    --local entity = event.entity; local player_index = event.player_index
    if not entity.valid then return end

    if not is_swappable_entity(entity) then return end
    local surface = entity.surface
    local is_ghost = entity.name == "entity-ghost"
    local name = is_ghost and entity.ghost_name or entity.name

    local is_rubia = surface and surface.name == "rubia"

    local swap_target --The string for the entity we plan to be when done

    if is_rubia then swap_target = swap_target_rubia[name]
    else swap_target = swap_target_outside_rubia[name] 
    end
    --game.print("Is rubia = " .. tostring(is_rubia) .. ", swap target = " .. (swap_target or "nil") .. ", name = " .. name)
    if not swap_target then return end --It is swappable, but it already matches the surface

    local player = player_index and game.get_player(player_index)

    local new_entity = surface.create_entity {
        name = is_ghost and "entity-ghost" or swap_target,
        inner_name = is_ghost and swap_target or nil,
        tags = is_ghost and entity.tags or nil,
        position = entity.position,
        direction = entity.direction,
        force = entity.force_index,
        quality = entity.quality,
        health = entity.health,
        raise_built = true,
        player = player,
    }
    if not new_entity or not new_entity.valid then return end
    new_entity.mirroring = entity.mirroring
    new_entity.copy_settings(entity)

    --Transfer modules, but only if the entity has them!
    local module_inventory = entity.get_module_inventory() 
    if not is_ghost and module_inventory then
        local modules = module_inventory.get_contents()
        for _, item in pairs(modules) do
            local inserted_count = new_entity.insert(item)
            if inserted_count < item.count then
                item.count = item.count - inserted_count
                surface.spill_item_stack {
                    position = entity.position,
                    stack = item,
                    enable_looted = true,
                    force = entity.force_index,
                    allow_belts = false
                }
            end
        end
    end

    entity.destroy()

    --Special case for new entity is a rubian silo to disable requester
    if swap_target == "rubia-rocket-silo" then
        req_point = new_entity.get_requester_point()
        --There is no point if it is a ghost
        if req_point then req_point.enabled = false end
        new_entity.use_transitional_requests = false
    end
end

--Some swapped entities need special GUI



---When an entity UI is updated, check and correct the given Rubia rocket silo settings.
---@param entity LuaEntity
---@param player_index uint
entity_swap.rocket_silo_update = function(entity, player_index)
    if not entity.valid or entity.name ~= "rubia-rocket-silo" then return end
    --No need to fix if it is already configured right.
    if not entity.use_transitional_requests then return end

    --We do need to fix and issue a warning
    entity.use_transitional_requests = false
    local print_target = (player_index and game.players[player_index]) or game

    print_target.print({"alert.rubia-rocket-silo-setting-warning"}, rubia.WARNING_PRINT_SETTINGS)
    print_target.play_sound{path="utility/cannot_build"}--, position=player.position, volume_modifier=1}
end


--[[
--When a GUI is opened, check if it belongs to a relevant entity, and modify if needed.
entity_swap.try_modified_gui = function(event)
    local entity = event.entity
    if not entity.valid then return end
    local is_ghost = entity.name == "entity-ghost"
    local name = is_ghost and entity.ghost_name or entity.name
    local player = game.get_player(event.player_index)

    --Rubia rocket silo needs to block the GUI for logi requests.
    if name == "rubia-rocket-silo" and event.gui_type == defines.gui_type.entity then
        --log(serpent.block(player.get_associated_characters().opened))
        log(serpent.block(event))

        local menu = event.element
        --for i, entry in pairs(menu.children) do
        --    log(tostring(i) .. " - " ..  entry.name .. " - ".. tostring(entry.caption))
        --end

    end

end]]

--#region Events
local event_lib = require("__rubia__.lib.event-lib")
event_lib.on_built_early("entity-swap", entity_swap.try_entity_swap)

event_lib.on_entity_gui_update("silo-update", entity_swap.rocket_silo_update)
--#endregion

return entity_swap