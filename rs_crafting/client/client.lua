local Core = exports.vorp_core:GetCore()
local AnimationHandler = {}
local primaryProp
local secondaryProp
local AnimationsConfig = Config.Anim

CreateThread(function()
    if Config.ShowBlip then 
        for i = 1, #Config.BlipZone do 
            local zone = Config.BlipZone[i]
            if zone.blips and type(zone.blips) == "number" then
                local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, zone.coords.x, zone.coords.y, zone.coords.z) 
                SetBlipSprite(blip, zone.blips, 1)
                SetBlipScale(blip, 0.8)
                Citizen.InvokeNative(0x9CB1A1623062F402, blip, zone.blipsName)
                Citizen.InvokeNative(0x662D364ABF16DE2F, blip, GetHashKey("BLIP_MODIFIER_MP_COLOR_32"))
            end
        end
    end
end)

Citizen.CreateThread(function()
    local showingCraftZone = false

    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearCraftZone = false
        local currentZoneId = nil

        for zoneId, zone in pairs(Config.CraftingZones) do
            for _, craftingZoneCoord in ipairs(zone.coords) do
                local distance = #(playerCoords - vector3(craftingZoneCoord.x, craftingZoneCoord.y, craftingZoneCoord.z))
                if distance < 1.5 then
                    nearCraftZone = true
                    currentZoneId = zoneId

                    if not showingCraftZone then
                        SendNUIMessage({
                            type = "showPrompmenu",
                            text = Config.Prompt.textmenu
                        })
                        showingCraftZone = true
                    end

                    if IsControlJustReleased(0, 0x760A9C6F) then
                        TriggerServerEvent('rs_crafting:getCraftableItems', currentZoneId)
                    end

                    break
                end
            end
            if nearCraftZone then break end
        end

        if not nearCraftZone and showingCraftZone then
            SendNUIMessage({ type = "hidePrompmenu" })
            showingCraftZone = false
        end

        Citizen.Wait(nearCraftZone and 0 or 500)
    end
end)

RegisterNetEvent('rs_crafting:openMenuClient')
AddEventHandler('rs_crafting:openMenuClient', function(allItems, playerjob)
    local groupedItems = {}
    local uncategorizedItems = {}
    local hasAllowedItems = false

    for _, craft in ipairs(allItems) do
        local allowedJobs = craft.Job or false
        local category = craft.Category

        local isAllowed = allowedJobs == false or
            (type(allowedJobs) == "string" and allowedJobs == playerjob) or
            (type(allowedJobs) == "table" and table.contains(allowedJobs, playerjob))

        if isAllowed then
            hasAllowedItems = true

            local rewardImage = craft.Reward and craft.Reward[1] and craft.Reward[1].image or "default.png"

            local element = {
                label = craft.Text,
                value = craft,
                image = "nui://vorp_inventory/html/img/items/" .. rewardImage,
                descriptionimages = {}
            }

            for _, item in ipairs(craft.Items) do
                table.insert(element.descriptionimages, {
                    src = "nui://vorp_inventory/html/img/items/" .. item.image,
                    text = item.label,
                    count = " x " .. item.count,
                })
            end

            if category == false or category == nil then
                table.insert(uncategorizedItems, element)
            else
                groupedItems[category] = groupedItems[category] or {}
                table.insert(groupedItems[category], element)
            end
        end
    end

    if hasAllowedItems then
        if #uncategorizedItems > 0 then
            SendNUIMessage({
                type = "openCraftingMenuDirect",
                items = uncategorizedItems,
                prompt = Config.Texts
            })
        else
            local firstCategory = nil
            for catName, _ in pairs(groupedItems) do
                firstCategory = catName
                break
            end

            SendNUIMessage({
                type = "openCraftingMenuGrouped",
                categories = groupedItems,
                prompt = Config.Texts,
                defaultCategory = firstCategory
            })
        end
        SetNuiFocus(true, true)
    else
        TriggerEvent("vorp:NotifyLeft", Config.Texts.Notify.crafting, Config.Texts.Notify.notjob, "menu_textures", "cross", 4000, "COLOR_RED")
    end
end)

RegisterNUICallback("craftItem", function(data, cb)
    local selectedItem = data.item
    local quantity = tonumber(data.quantity)

    if quantity and quantity > 0 then
        TriggerServerEvent('rs_crafting:startCrafting', selectedItem, quantity)
    else
        TriggerEvent("vorp:TipRight", "Cantidad inválida", 3000)
    end

    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback("closeMenu", function(_, cb)
    SetNuiFocus(false, false)
    cb({})
end)

function table.contains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then return true end
    end
    return false
end

Citizen.CreateThread(function()
    local showingCraftPrompt = false

    while true do
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearCraftProp = false
        local propToCheck = nil

        for _, category in pairs(Config.CraftingProps) do
            for _, item in pairs(category.Items) do
                for _, prop in ipairs(item.props) do
                    local hash = GetHashKey(prop)
                    local entity = GetClosestObjectOfType(playerCoords, 3.0, hash, false, false, false)

                    if DoesEntityExist(entity) then
                        local entityCoords = GetEntityCoords(entity)
                        if #(playerCoords - entityCoords) < 3.0 then
                            nearCraftProp = true
                            propToCheck = prop

                            if not showingCraftPrompt then
                                SendNUIMessage({
                                    type = "showProp",
                                    text = Config.Prompt.text
                                })
                                showingCraftPrompt = true
                            end

                            if IsControlJustReleased(0, 0x760A9C6F) then
                                TriggerServerEvent('rs_crafting:requestPropMenu', propToCheck)
                            end

                            break
                        end
                    end
                end
                if nearCraftProp then break end
            end
            if nearCraftProp then break end
        end

        if not nearCraftProp and showingCraftPrompt then
            SendNUIMessage({ type = "hideProp" })
            showingCraftPrompt = false
        end

        Citizen.Wait(nearCraftProp and 0 or 500)
    end
end)

RegisterNetEvent('rs_crafting:openPropMenu')
AddEventHandler('rs_crafting:openPropMenu', function(_, propToCheck, playerJob)
    local groupedItems = {}
    local directItems = {}
    local hasAllowedItems = false

    for _, category in ipairs(Config.CraftingProps) do
        for _, item in ipairs(category.Items) do
            if table.contains(item.props, propToCheck) then
                local allowedJobs = item.Job or false
                local isAllowed =
                    allowedJobs == false or
                    (type(allowedJobs) == "string" and allowedJobs == playerJob) or
                    (type(allowedJobs) == "table" and table.contains(allowedJobs, playerJob))

                if isAllowed then
                    hasAllowedItems = true

                    local rewardImage = item.Reward and item.Reward[1] and item.Reward[1].image or "default.png"
                    local formattedItem = {
                        label = item.Text or "Sin nombre",
                        value = item,
                        image = "nui://vorp_inventory/html/img/items/" .. rewardImage,
                        descriptionimages = {}
                    }

                    for _, reqItem in ipairs(item.Items or {}) do
                        table.insert(formattedItem.descriptionimages, {
                            src = "nui://vorp_inventory/html/img/items/" .. (reqItem.image or "default.png"),
                            text = reqItem.label or "Desconocido",
                            count = " x " .. tostring(reqItem.count or 0),
                        })
                    end

                    if item.Category == false or item.Category == nil then
                        table.insert(directItems, formattedItem)
                    else
                        groupedItems[item.Category] = groupedItems[item.Category] or {}
                        table.insert(groupedItems[item.Category], formattedItem)
                    end
                end
            end
        end
    end

    if not hasAllowedItems then
        TriggerEvent("vorp:NotifyLeft", Config.Texts.Notify.crafting, Config.Texts.Notify.notjob, "menu_textures", "cross", 4000, "COLOR_RED")
        return
    end

    if #directItems > 0 then
        SendNUIMessage({
            type = "openCraftingMenuDirect",
            items = directItems,
            prompt = Config.Texts
        })
    else
        local firstCategory = nil
        for catName, _ in pairs(groupedItems) do
            firstCategory = catName
            break
        end

        SendNUIMessage({
            type = "openCraftingMenuGrouped",
            categories = groupedItems,
            prompt = Config.Texts,
            defaultCategory = firstCategory
        })
    end

    SetNuiFocus(true, true)
end)

AnimationHandler.play = function(ped, animKey)
    local animData = AnimationsConfig[animKey]
    if not DoesAnimDictExist(animData.dict) then return end

    if animData.prop then
        local pedCoords = GetEntityCoords(ped)
        primaryProp = CreateObject(animData.prop.model, pedCoords.x, pedCoords.y, pedCoords.z, true, true, false, false, true)
        local bone = GetEntityBoneIndexByName(ped, animData.prop.bone)

        AttachEntityToEntity(primaryProp, ped, bone,
            animData.prop.coords.x, animData.prop.coords.y, animData.prop.coords.z,
            animData.prop.coords.xr, animData.prop.coords.yr, animData.prop.coords.zr,
            true, true, false, true, 1, true, false, false)

        if animData.prop.subprop then
            local subCoords = GetEntityCoords(secondaryProp)
            secondaryProp = CreateObject(animData.prop.subprop.model, subCoords.x, subCoords.y, subCoords.z, true, true, false, false, true)

            AttachEntityToEntity(secondaryProp, ped, bone,
                animData.prop.subprop.coords.x, animData.prop.subprop.coords.y, animData.prop.subprop.coords.z,
                animData.prop.subprop.coords.xr, animData.prop.subprop.coords.yr, animData.prop.subprop.coords.zr,
                true, true, false, true, 1, true, false, false)
        end
    end

    if animData.type == 'scenario' then
        TaskStartScenarioInPlaceHash(ped, GetHashKey(animData.hash), 12000, true, 0, 0, false)
    elseif animData.type == 'standard' then
        RequestAnimDict(animData.dict)
        while not HasAnimDictLoaded(animData.dict) do Wait(0) end

        TaskPlayAnim(ped, animData.dict, animData.name, 1.0, 1.0, -1, animData.flag, 1.0, false, 0, false, '', false)
    end
end

AnimationHandler.stop = function(animKey)
    local animData = AnimationsConfig[animKey]
    RemoveAnimDict(animData.dict)
    StopAnimTask(PlayerPedId(), animData.dict, animData.name, 1.0)

    if primaryProp then DeleteObject(primaryProp) end
    if secondaryProp then DeleteObject(secondaryProp) end
end

AnimationHandler.stopAll = function()
    ClearPedTasksImmediately(PlayerPedId())
end

AnimationHandler.forceScenarioRest = function(value)
    Citizen.InvokeNative(0xE5A3DD2FF84E1A4B, value)
end

RegisterNetEvent("rs_crafting:craftable")
AddEventHandler("rs_crafting:craftable", function(animation, craftable, countz)
    local playerPed = PlayerPedId()
    iscrafting = true

    animation = animation or "craft"
    AnimationHandler.play(playerPed, animation)

    local duration = Config.CraftTime

    SendNUIMessage({
        type = "showProgressBar",
        duration = duration,
        text = Config.Texts.crafting
    })

    Citizen.SetTimeout(duration, function()
        AnimationHandler.stop(animation)
        iscrafting = false

        SendNUIMessage({ type = "hideProgressBar" })

        TriggerServerEvent("rs_crafting:animationComplete", craftable, countz)
    end)
end)