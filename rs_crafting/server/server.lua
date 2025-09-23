local Core = exports.vorp_core:GetCore()

RegisterNetEvent('rs_crafting:getCraftableItems', function(zoneId)
    local _source = source
    local Character = Core.getUser(_source).getUsedCharacter
    local playerjob = Character.job

    local allCraftableItems = {}

    local zone = Config.CraftingZones[zoneId]

    if zone then
        for _, category in ipairs(zone.craftingItems) do
            for _, craft in ipairs(category.Items) do
                table.insert(allCraftableItems, craft)
            end
        end
    end

    TriggerClientEvent('rs_crafting:openMenuClient', _source, allCraftableItems, playerjob)
end)

RegisterNetEvent('rs_crafting:startCrafting', function(craftable, countz)
    local _source = source
    local Character = Core.getUser(_source).getUsedCharacter
    local playerjob = Character.job

    local canCraft = false
    local allowedJobs = craftable.Job

    if allowedJobs == false then
        canCraft = true
    elseif type(allowedJobs) == "string" and allowedJobs == playerjob then
        canCraft = true
    elseif type(allowedJobs) == "table" then
        for _, job in ipairs(allowedJobs) do
            if job == playerjob then
                canCraft = true
                break
            end
        end
    end

    if not canCraft then
        Core.NotifyLeft(_source, Config.Texts.Notify.crafting, Config.Texts.Notify.notjob, "menu_textures", "cross", 3000, "COLOR_RED")
        return
    end

    local inventory = exports.vorp_inventory:getUserInventoryItems(_source)
    if not inventory then return end

    local requiredItems = {}
    for _, item in ipairs(craftable.Items) do
        requiredItems[item.name] = { required = item.count * countz, found = 0 }
    end

    for _, value in pairs(inventory) do
        if requiredItems[value.name] then
            requiredItems[value.name].found = requiredItems[value.name].found + value.count
        end
    end

    for _, req in pairs(requiredItems) do
        if req.found < req.required then
            Core.NotifyLeft(_source, Config.Texts.Notify.crafting, Config.Texts.Notify.notmaterials, "menu_textures", "cross", 3000, "COLOR_RED")
            return
        end
    end

    local canCarryItems = true
    if craftable.Type == "weapon" then
        for _, reward in ipairs(craftable.Reward) do
            local canCarry = exports.vorp_inventory:canCarryWeapons(_source, reward.count * countz, nil, reward.name)
            if not canCarry then
                canCarryItems = false
                break
            end
        end
    elseif craftable.Type == "item" then
        for _, reward in ipairs(craftable.Reward) do
            exports.vorp_inventory:canCarryItem(_source, reward.name, reward.count * countz, function(canCarry)
                if not canCarry then
                    canCarryItems = false
                end
            end)
            if not canCarryItems then break end
        end
    end

    if not canCarryItems then
        Core.NotifyLeft(_source, Config.Texts.Notify.crafting, Config.Texts.Notify.space, "menu_textures", "cross", 3000, "COLOR_RED")
        return
    end

    for _, item in ipairs(craftable.Items) do
        exports.vorp_inventory:subItem(_source, item.name, item.count * countz)
    end
    TriggerClientEvent("rs_crafting:craftable", _source, craftable.Animation, craftable, countz)
end)

RegisterNetEvent("rs_crafting:finishCrafting")
AddEventHandler("rs_crafting:finishCrafting", function(craftable, countz)
    local _source = source
    local character = Core.getUser(_source).getUsedCharacter
    if not character then return end

    if craftable.Type == "weapon" then
        for _, reward in ipairs(craftable.Reward) do
            for _ = 1, countz do
                for _ = 1, reward.count do
                    exports.vorp_inventory:createWeapon(_source, reward.name, {}, {})
                end
            end
        end
    elseif craftable.Type == "item" then
        for _, reward in ipairs(craftable.Reward) do
            exports.vorp_inventory:addItem(_source, reward.name, reward.count * countz)
        end
    else
        Core.NotifyLeft(_source, Config.Texts.Notify.crafting, Config.Texts.Notify.invalid, "menu_textures", "cross", 3000, "COLOR_RED")
        return
    end
    Core.NotifyLeft(_source,Config.Texts.Notify.crafting, Config.Texts.Notify.success, "generic_textures", "tick", 4000, "COLOR_GREEN")
end)

RegisterNetEvent("rs_crafting:animationComplete")
AddEventHandler("rs_crafting:animationComplete", function(craftable, countz)
    local _source = source
    local character = Core.getUser(_source).getUsedCharacter
    if not character then return end

    for _, reward in ipairs(craftable.Reward) do
        if craftable.Type == "weapon" then
            for _ = 1, countz do
                for _ = 1, reward.count do
                    exports.vorp_inventory:createWeapon(_source, reward.name, {}, {})
                end
            end
        else
            exports.vorp_inventory:addItem(_source, reward.name, reward.count * countz)
        end
    end
    Core.NotifyLeft(_source,Config.Texts.Notify.crafting, Config.Texts.Notify.success, "generic_textures", "tick", 4000, "COLOR_GREEN")
end)

RegisterServerEvent('rs_crafting:requestPropMenu')
AddEventHandler('rs_crafting:requestPropMenu', function(propToCheck)
    local _source = source
    local Character = Core.getUser(_source).getUsedCharacter
    local playerjob = Character.job
    TriggerClientEvent('rs_crafting:openPropMenu', _source, nil, propToCheck, playerjob)
end)