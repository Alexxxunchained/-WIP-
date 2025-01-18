local QBCore = exports['qb-core']:GetCoreObject()
local spawnedVehicles = {}
local damageStates = {}

local function ApplyVisualDamage(vehicle, damage)
    if not DoesEntityExist(vehicle) then return end
    
    if damage.tires and damage.tires.damaged > 0 then
        local damagedTires = {}
        while #damagedTires < damage.tires.damaged do
            local tireIndex = math.random(0, 3) -- 0-3 代表四个轮胎
            if not damagedTires[tireIndex] then
                damagedTires[tireIndex] = true
                SetVehicleTyreBurst(vehicle, tireIndex, true, 1000.0)
            end
        end
    end
    
    if damage.engine then
        SetVehicleEngineHealth(vehicle, 300.0)
        SetVehiclePetrolTankHealth(vehicle, 600.0)
        SetVehicleBodyHealth(vehicle, 800.0)
        SetVehicleEngineOn(vehicle, true, true, false)
        SetVehicleUndriveable(vehicle, true)
    end
    
    if damage.radiator then
        UseParticleFxAssetNextCall('core')
        StartParticleFxLoopedOnEntity('ent_steam_general', vehicle, 0.0, 2.5, 0.0, 0.0, 0.0, 0.0, 2.0, false, false, false)
    end
end

local function SpawnPersistentVehicle(data)
    local model = GetHashKey(data.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    
    local coords = json.decode(data.coords)
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, coords.h, true, true)
    SetEntityAsMissionEntity(vehicle, true, true)
    
    local damage = json.decode(data.damage_data)
    damageStates[vehicle] = damage
    
    ApplyVisualDamage(vehicle, damage)
    
    exports.ox_target:addLocalEntity(vehicle, {
        {
            name = 'inspect_vehicle',
            icon = 'fas fa-car',
            label = '检查载具',
            onSelect = function()
                OpenRepairMenu(vehicle)
            end
        }
    })
    
    spawnedVehicles[vehicle] = true
    Entity(vehicle).state.vehicleId = data.id
    
    return vehicle
end

-- Citizen.CreateThread(function() -- Start Thread (Non Loop)

-- end)

-- Citizen.CreateThread(function() -- Start Thread (Loop)
--     while true do
--         Wait(10)
--     end
-- end)

-- RegisterNetEvent('nameOFscript:client:nameOFwhathappens', function ()
--   -- Templete netevent
-- end)

-- AddEventHandler('onResourceStart', function(resourceName)
--     if (GetCurrentResourceName() ~= resourceName) then
--         return
--     end

-- end)

-- AddEventHandler('onResourceStop', function(resourceName)
--     if (GetCurrentResourceName() ~= resourceName) then
--       return
--     end

-- end)

function OpenRepairMenu(vehicle)
    local damage = damageStates[vehicle]
    local options = {}
    
    local items = {
        tire = exports.ox_inventory:Search('count', Config.RepairItems.tire) or 0,
        radiator = exports.ox_inventory:Search('count', Config.RepairItems.radiator) or 0,
        engine = exports.ox_inventory:Search('count', Config.RepairItems.engine) or 0,
        sparkplug = exports.ox_inventory:Search('count', Config.RepairItems.sparkplug) or 0
    }
    
    -- debug
    print('Config items:', json.encode(Config.RepairItems))
    print('Available items:', json.encode(items))
    
    if damage.tires and damage.tires.damaged > 0 then
        table.insert(options, {
            title = '轮胎状态',
            description = string.format('已损坏: %d/4', damage.tires.damaged),
            icon = 'fas fa-circle',
            disabled = items.tire < 1,
            metadata = {
                {label = '需要物品', value = Config.RepairItems.tire .. ' x1'}
            },
            onSelect = function()
                RepairComponent(vehicle, 'tire')
            end
        })
    end
    
    if damage.radiator then
        table.insert(options, {
            title = '水箱状态',
            description = '已损坏',
            icon = 'fas fa-tint',
            disabled = items.radiator < 1,
            metadata = {
                {label = '需要物品', value = Config.RepairItems.radiator .. ' x1'}
            },
            onSelect = function()
                RepairComponent(vehicle, 'radiator')
            end
        })
    end
    
    if damage.engine then
        table.insert(options, {
            title = '引擎状态',
            description = '已损坏',
            icon = 'fas fa-cog',
            disabled = items.engine < 1,
            metadata = {
                {label = '需要物品', value = Config.RepairItems.engine .. ' x1'}
            },
            onSelect = function()
                RepairComponent(vehicle, 'engine')
            end
        })
    end
    
    if damage.sparkplug then
        table.insert(options, {
            title = '火花塞状态',
            description = '已损坏',
            icon = 'fas fa-bolt',
            disabled = items.sparkplug < 1,
            metadata = {
                {label = '需要物品', value = Config.RepairItems.sparkplug .. ' x1'}
            },
            onSelect = function()
                RepairComponent(vehicle, 'sparkplug')
            end
        })
    end
    
    lib.registerContext({
        id = 'vehicle_repair',
        title = '载具维修',
        options = options
    })
    
    lib.showContext('vehicle_repair')
end

function RepairComponent(vehicle, component)
    -- Debug info
    print("Config.RepairTimes:", json.encode(Config.RepairTimes))
    print("Attempting to repair component:", component)
    
    if component == 'tires' then component = 'tire' end
    
    if not Config.RepairTimes[component] then 
        print("Invalid component type:", component)
        return 
    end
    
    -- Debug info
    print("Starting repair for component:", component)
    if component == 'tire' then
        print("Current tire damage state:", json.encode(damageStates[vehicle].tires))
    end
    
    local vehCoords = GetEntityCoords(vehicle)
    TaskTurnPedToFaceCoord(PlayerPedId(), vehCoords.x, vehCoords.y, vehCoords.z, 2000)
    Wait(1000)
    
    if lib.progressCircle({
        duration = Config.RepairTimes[component],
        position = 'bottom',
        label = '正在修理' .. GetComponentLabel(component),
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer',
            flags = 1
        },
    }) then
        local coords = GetEntityCoords(vehicle)
        if component == 'tire' then
            print("Tire repair progress completed")
            PlaySoundFrontend(-1, "VEHICLES_REPAIR", 0, true)
            UseParticleFxAssetNextCall('core')
            StartParticleFxLoopedAtCoord('ent_amb_welding', coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
            
            local damage = damageStates[vehicle]
            if damage.tires and damage.tires.damaged > 0 then
                print("Starting tire repair, current damaged count:", damage.tires.damaged)
                local tires = {0, 1, 2, 3}
                for _, tireIndex in ipairs(tires) do
                    if IsVehicleTyreBurst(vehicle, tireIndex, true) then
                        print("Repairing tire index:", tireIndex)
                        SetVehicleTyreFixed(vehicle, tireIndex)
                        damage.tires.damaged = damage.tires.damaged - 1
                        break
                    end
                end
                print("Tire damage count after repair:", damage.tires.damaged)
                
                local vehicleId = Entity(vehicle).state.vehicleId
                TriggerServerEvent('persistent_vehicles:server:updateDamageState', vehicleId, json.encode(damage))
            end
        elseif component == 'engine' then
            PlaySoundFrontend(-1, "REPAIR", 0, true)
            RemoveParticleFxFromEntity(vehicle)
        end
        
        TriggerServerEvent('persistent_vehicles:server:removeRepairItem', Config.RepairItems[component])
        
        UpdateVehicleComponent(vehicle, component)
        
        lib.notify({
            title = '修理成功',
            description = GetComponentLabel(component) .. '已修复',
            type = 'success'
        })
    else
        lib.notify({
            title = '已取消',
            description = '取消修理' .. GetComponentLabel(component),
            type = 'error'
        })
    end
end

function GetComponentLabel(component)
    local labels = {
        tire = '轮胎',
        radiator = '水箱',
        engine = '引擎',
        sparkplug = '火花塞'
    }
    return labels[component] or component
end

RegisterNetEvent('persistent_vehicles:client:syncVehicles', function(vehicles)
    print("Received vehicle sync data:", #vehicles, "vehicles")
    
    for vehicle, _ in pairs(spawnedVehicles) do
        if DoesEntityExist(vehicle) then
            DeleteEntity(vehicle)
        end
    end
    spawnedVehicles = {}
    
    for _, vehicleData in pairs(vehicles) do
        print("Spawning vehicle:", vehicleData.model)
        SpawnPersistentVehicle(vehicleData)
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        for vehicle, _ in pairs(spawnedVehicles) do
            if DoesEntityExist(vehicle) then
                if IsEntityDead(vehicle) or IsEntityInWater(vehicle) then
                    local vehicleId = Entity(vehicle).state.vehicleId
                    TriggerServerEvent('persistent_vehicles:server:updateVehicleState', vehicleId, 0)
                    spawnedVehicles[vehicle] = nil
                end
            end
        end
    end
end)

function UpdateVehicleComponent(vehicle, component)
    local damage = damageStates[vehicle]
    if component == 'tire' and damage.tires.damaged > 0 then
        damage.tires.damaged = damage.tires.damaged - 1
        local tires = {0, 1, 2, 3}
        for _, tireIndex in ipairs(tires) do
            if IsVehicleTyreBurst(vehicle, tireIndex, true) then
                SetVehicleTyreFixed(vehicle, tireIndex)
                break
            end
        end
    else
        damage[component] = false
        if component == 'engine' then
            SetVehicleEngineHealth(vehicle, 1000.0)
            SetVehicleEngineOn(vehicle, true, true, false)
            SetVehicleUndriveable(vehicle, false)
        elseif component == 'radiator' then
            RemoveParticleFxFromEntity(vehicle)
        end
    end
    
    local allRepaired = true
    for k, v in pairs(damage) do
        if k == 'tire' and v.damaged > 0 then
            allRepaired = false
            break
        elseif k ~= 'tire' and v then
            allRepaired = false
            break
        end
    end
    
    if allRepaired then
        SetVehicleFixed(vehicle)
        SetVehicleEngineHealth(vehicle, 1000.0)
        lib.notify({
            title = '修理完成',
            description = '载具已完全修复',
            type = 'success'
        })
    end
    
    local vehicleId = Entity(vehicle).state.vehicleId
    TriggerServerEvent('persistent_vehicles:server:updateDamageState', vehicleId, json.encode(damage))
end

local function CheckVehicleStatus(vehicle)
    local damage = damageStates[vehicle]
    if not damage then return false end
    
    local status = {
        canDrive = true,
        issues = {}
    }
    
    if damage.tire and damage.tire.damaged > 0 then
        status.canDrive = false
        table.insert(status.issues, string.format('轮胎损坏 (%d/4)', damage.tire.damaged))
    end
    if damage.radiator then
        status.canDrive = false
        table.insert(status.issues, '水箱损坏')
    end
    if damage.engine then
        status.canDrive = false
        table.insert(status.issues, '引擎损坏')
    end
    if damage.sparkplug then
        status.canDrive = false
        table.insert(status.issues, '火花塞损坏')
    end
    
    return status
end

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if spawnedVehicles[vehicle] then
                local status = CheckVehicleStatus(vehicle)
                if not status.canDrive then
                    SetVehicleEngineOn(vehicle, false, true, true)
                    DisableControlAction(0, 71, true)
                    DisableControlAction(0, 72, true)
                    
                    lib.showTextUI(table.concat(status.issues, '\n'))
                else
                    lib.hideTextUI()
                end
            end
        else
            lib.hideTextUI()
        end
    end
end)

-- 保存载具位置
CreateThread(function()
    while true do
        Wait(10000) -- 每10秒保存一次
        for vehicle, _ in pairs(spawnedVehicles) do
            if DoesEntityExist(vehicle) then
                local coords = GetEntityCoords(vehicle)
                local heading = GetEntityHeading(vehicle)
                local health = GetVehicleEngineHealth(vehicle)
                local vehicleId = Entity(vehicle).state.vehicleId
                
                if vehicleId then
                    print("Saving vehicle position:", json.encode({
                        x = coords.x,
                        y = coords.y,
                        z = coords.z,
                        h = heading
                    }))
                    
                    TriggerServerEvent('persistent_vehicles:server:saveVehiclePosition', vehicleId, {
                        x = coords.x,
                        y = coords.y,
                        z = coords.z,
                        h = heading
                    }, health)
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    
    for vehicle, _ in pairs(spawnedVehicles) do
        if DoesEntityExist(vehicle) then
            local coords = GetEntityCoords(vehicle)
            local heading = GetEntityHeading(vehicle)
            local health = GetVehicleEngineHealth(vehicle)
            local vehicleId = Entity(vehicle).state.vehicleId
            
            if vehicleId then
                print("Saving vehicle position before resource stop:", json.encode({
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    h = heading
                }))
                
                TriggerServerEvent('persistent_vehicles:server:saveVehiclePosition', vehicleId, {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    h = heading
                }, health)
            end
        end
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    
    -- 在玩家离开时保存所有载具位置
    for vehicle, _ in pairs(spawnedVehicles) do
        if DoesEntityExist(vehicle) then
            local coords = GetEntityCoords(vehicle)
            local heading = GetEntityHeading(vehicle)
            local health = GetVehicleEngineHealth(vehicle)
            local vehicleId = Entity(vehicle).state.vehicleId
            
            if vehicleId then
                print("Saving vehicle position before player disconnect:", json.encode({
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    h = heading
                }))
                
                TriggerServerEvent('persistent_vehicles:server:saveVehiclePosition', vehicleId, {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    h = heading
                }, health)
            end
        end
    end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkPlayerEnteredVehicle' then
        local ped, vehicle = args[1], args[2]
        if ped == PlayerPedId() and spawnedVehicles[vehicle] then
            TriggerServerEvent('persistent_vehicles:server:vehicleEntered', NetworkGetNetworkIdFromEntity(vehicle))
        end
    end
end)

local function GetRepairProgress(damage)
    local total = 0
    local repaired = 0
    
    total = total + 4
    repaired = repaired + (4 - (damage.tire and damage.tire.damaged or 0))
    
    for _, component in pairs({'radiator', 'engine', 'sparkplug'}) do
        total = total + 1
        if not damage[component] then
            repaired = repaired + 1
        end
    end
    
    return repaired, total
end

function ShowRepairProgress(vehicle)
    local damage = damageStates[vehicle]
    if not damage then return end
    
    local repaired, total = GetRepairProgress(damage)
    local percentage = math.floor((repaired / total) * 100)
    
    lib.showTextUI(string.format([[
修复进度: %d%%
已修复: %d/%d
    
剩余问题:
%s
]], percentage, repaired, total, GetRemainingIssues(damage)))
end

function GetRemainingIssues(damage)
    local issues = {}
    
    if damage.tire and damage.tire.damaged > 0 then
        table.insert(issues, string.format('- 轮胎 (%d个需要修理)', damage.tire.damaged))
    end
    if damage.radiator then
        table.insert(issues, '- 水箱需要更换')
    end
    if damage.engine then
        table.insert(issues, '- 引擎需要维修')
    end
    if damage.sparkplug then
        table.insert(issues, '- 火花塞需要更换')
    end
    
    return #issues > 0 and table.concat(issues, '\n') or '无'
end