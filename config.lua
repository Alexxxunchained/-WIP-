Config = {
    Debug = true,
    Notification = 'ox',
    Progress = 'ox',
    
    -- 生成点位配置 Spawn Locations for spacial vehicle
    SpawnLocations = {
        {
            coords = vector4(241.32, -748.13, 34.61, 69.76), -- x, y, z, heading
            label = "卡林" -- actually not using just for check index for myself
        },
    },
    
    -- 可生成的载具列表 the veh will spawn in the Spawn Locations
    Vehicles = {
        {model = "sultan", label = "卡林王者"},
        {model = "buffalo", label = "水牛"},
    },
    
    -- 修理所需物品 Repair Items to fix the vehicle
    RepairItems = {
        tire = "sparetire",      -- 轮胎
        radiator = "carbattery",     -- 水箱
        engine = "engine1",   -- 引擎
        sparkplug = "sparkplugs"    -- 火花塞
    },
    
    -- 修理进度条配置 Repair Progress Bar
    RepairTimes = {
        tire = 5000,      -- in ms 
        radiator = 8000,
        engine = 12000,
        sparkplug = 6000
    }
}

-- Will Set The Inv For You
AddEventHandler("onResourceStart", function()
    Wait(100)
    if GetResourceState('ox_inventory') == 'started' then
        Config.Inventory = 'ox'
    elseif GetResourceState('qb-inventory') == 'started' then
        Config.Inventory = 'qb'
    end
end)