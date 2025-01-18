local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    Wait(1000)
    print('^2[浩劫 - 载具系统] ^7初始化数据库...')
    
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS persistent_vehicles (
            id VARCHAR(50) PRIMARY KEY,
            model VARCHAR(50) NOT NULL,
            coords JSON NOT NULL,
            damage_data JSON NOT NULL,
            last_state TINYINT DEFAULT 1,
            last_health FLOAT DEFAULT 1000.0
        )
    ]], {}, function(success)
        if success then
            print('^2[浩劫 - 载具系统] ^7数据库初始化完成')
            -- 初始化完成后检查并生成载具
            CheckAndInitializeVehicles()
        end
    end)
end)

local function GenerateRandomDamage()
    local damage = {
        tires = { damaged = 0 },
        radiator = false,
        engine = false,
        sparkplug = false
    }
    
    local numDamaged = math.random(1, 4)
    local components = {'tires', 'radiator', 'engine', 'sparkplug'}
    
    for i = #components, 2, -1 do
        local j = math.random(i)
        components[i], components[j] = components[j], components[i]
    end
    
    for i = 1, numDamaged do
        local component = components[i]
        if component == 'tires' then
            damage.tires.damaged = math.random(1, 4)
        else
            damage[component] = true
        end
    end
    
    return json.encode(damage)
end

local function GenerateUniqueId()
    return string.format('%s-%s', os.time(), math.random(1000, 9999))
end

function CheckAndInitializeVehicles()
    exports.oxmysql:execute('SELECT COUNT(*) as count FROM persistent_vehicles WHERE last_state = 1', {}, function(result)
        local count = result[1].count
        print('^2[浩劫 - 载具系统] ^7检索到: ' .. count .. ' 活跃载具')
        
        if count == 0 then
            print('^2[浩劫 - 载具系统] ^7初始化新载具...')
            for _, location in pairs(Config.SpawnLocations) do
                local vehicle = Config.Vehicles[math.random(#Config.Vehicles)]
                local coords = {
                    x = location.coords.x,
                    y = location.coords.y,
                    z = location.coords.z,
                    h = location.coords.w
                }
                
                exports.oxmysql:insert('INSERT INTO persistent_vehicles (id, model, coords, damage_data, last_state) VALUES (?, ?, ?, ?, ?)',
                    {
                        GenerateUniqueId(),
                        vehicle.model,
                        json.encode(coords),
                        GenerateRandomDamage(),
                        1
                    }, function()
                        print('^2[浩劫 - 载具系统] ^7新载具已生成: ' .. json.encode(coords))
                    end
                )
            end
            Wait(1000)
            BroadcastVehicleData()
        else
            print('^2[浩劫 - 载具系统] ^7同步至所有玩家...')
            BroadcastVehicleData()
        end
    end)
end

function BroadcastVehicleData()
    exports.oxmysql:execute('SELECT * FROM persistent_vehicles WHERE last_state = 1', {}, function(vehicles)
        if vehicles and #vehicles > 0 then
            print('^2[浩劫 - 载具系统] ^7正在同步载具: ' .. #vehicles .. ' 至全服活跃玩家')
            TriggerClientEvent('persistent_vehicles:client:syncVehicles', -1, vehicles)
        else
            print('^1[浩劫 - 载具系统] ^7当前无活跃载具')
        end
    end)
end

AddEventHandler('playerJoining', function()
    local src = source
    Wait(2000)
    exports.oxmysql:execute('SELECT * FROM persistent_vehicles WHERE last_state = 1', {}, function(vehicles)
        if vehicles and #vehicles > 0 then
            print('^2[浩劫 - 载具系统] ^7正在同步载具: ' .. #vehicles .. ' 至新玩家')
            TriggerClientEvent('persistent_vehicles:client:syncVehicles', src, vehicles)
        end
    end)
end)

RegisterNetEvent('persistent_vehicles:server:updateVehicleState', function(vehicleId, newState)
    local src = source
    exports.oxmysql:update('UPDATE persistent_vehicles SET last_state = ? WHERE id = ?',
        {newState, vehicleId},
        function(affectedRows)
            if affectedRows > 0 then
                BroadcastVehicleData()
            end
        end
    )
end)

RegisterNetEvent('persistent_vehicles:server:updateDamageState', function(vehicleId, damageData)
    exports.oxmysql:update('UPDATE persistent_vehicles SET damage_data = ? WHERE id = ?',
        {damageData, vehicleId}
    )
end)

RegisterNetEvent('persistent_vehicles:server:saveVehiclePosition', function(vehicleId, coords, health)
    print("^6[浩劫 - 载具保存] 载具ID:", vehicleId, "坐标:", json.encode(coords))
    
    exports.oxmysql:execute('UPDATE persistent_vehicles SET coords = ?, last_health = ? WHERE id = ?',
        {json.encode(coords), health, vehicleId},
        function(affectedRows)
            if affectedRows then
                print("^6[浩劫 - 载具保存] 载具保存成功 ID:", vehicleId)
            else
                print("^1[浩劫 - 载具保存] 载具保存失败 ID:", vehicleId)
            end
        end
    )
end)

RegisterNetEvent('persistent_vehicles:server:removeRepairItem', function(item)
    local src = source
    exports.ox_inventory:RemoveItem(src, item, 1)
end)

RegisterNetEvent('persistent_vehicles:server:vehicleEntered', function(vehicleNetId)
    local src = source
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if vehicle then
        SetEntityAsMissionEntity(vehicle, true, true)
    end
end)

function IsVehicleEligibleForDeletion(vehicleId)
    exports.oxmysql:execute('SELECT damage_data FROM persistent_vehicles WHERE id = ?', 
        {vehicleId}, 
        function(result)
            if result and #result > 0 then
                local damage = json.decode(result[1].damage_data)
                for k, v in pairs(damage) do
                    if k == 'tires' and v.damaged > 0 then
                        return false
                    elseif k ~= 'tires' and v then
                        return false
                    end
                end
                return true
            end
            return false
        end
    )
end