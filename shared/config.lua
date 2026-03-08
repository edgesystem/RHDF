Config = {}

-- Load garage and vehicle data from JSON files
GarageZone = lib.loadJson('data.garages') ---@type table<string, GarageData>
CNV = lib.loadJson('data.vehiclesname') ---@type table<string, CustomName>

Config.Target = 'ox'           -- ox / qb
Config.RadialMenu = 'ox'       --- ox / qb / rhd
Config.FuelScript = 'cdn-fuel' --- rhd_fuel / ox_fuel / LegacyFuel / ps-fuel / cdn-fuel
Config.changeNamePrice = 1000 --- price for changing the name of the vehicle in the garage
Config.SpawnInVehicle = false  --- change this to true if you want the player to immediately enter the vehicle when the vehicle is taken out of the garage
Config.VehiclesInAllGarages = true --- Opção ZAP: deixe true para todos os veículos do player aparecerem em todas as garagens
Config.DisableVehicleCamera = true --- Desativa a movimentação de câmera ao puxar o veículo
Config.LocateVehicleOutGarage = true --- Opção ZAP: encontrar veículos fora da garagem

--- Additional: (Requires ox_target or qb-target resource)
Config.UseJobVechileShop = false --- Change this to false if you do not want to use the work vehicle shop system from rhd
Config.UsePoliceImpound = true  --- change it to false if you don't want to use the police impound system from rhd

Config.InDevelopment = true     --- Turn this off when you have finished setting up this garage

-- Vehicle transfer settings
Config.TransferVehicle = {
    enable = true,  --- Enable or disable vehicle transfer functionality
    price = 500     --- Price for transferring a vehicle
}

-- Garage swap settings
Config.SwapGarage = {
    enable = true,  --- Enable or disable garage swapping functionality
    price = 500     --- Price for swapping garages
}

Config.GiveKeys = {
    tempkeys = false, -- true se você quiser dar chaves temporárias quando spawnar o veículo
    enable = true,
    onspawn = true, --- Opção ZAP: deixe true para seu player ganhar do nada uma chave do carro quando spawnar o veículo e remover quando ele guardar (ao invés dele ter que ir comprar em um chaveiro uma cópia)
    price = 500
}

-- Icon animation settings
Config.IconAnimation = "fade" --- Animation type for icons

-- Icons for different vehicle types
Config.Icons = {
    [8] = "motorcycle",  --- Icon for motorcycles
    [13] = "bicycle",    --- Icon for bicycles
    [14] = "sailboat",   --- Icon for sailboats
    [15] = "helicopter", --- Icon for helicopters
    [16] = "plane",      --- Icon for planes
}

-- Prices for impounding different vehicle types
Config.ImpoundPrice = {
    [0] = 1500,  --- Price for compact cars
    [1] = 1500,  --- Price for sedans
    [2] = 1500,  --- Price for SUVs
    [3] = 1500,  --- Price for coupes
    [4] = 1500,  --- Price for muscle cars
    [5] = 1500,  --- Price for sports classics
    [6] = 1500,  --- Price for sports cars
    [7] = 1500,  --- Price for super cars
    [8] = 1500,  --- Price for motorcycles
    [9] = 1500,  --- Price for off-road vehicles
    [10] = 1500, --- Price for industrial vehicles
    [11] = 1500, --- Price for utility vehicles
    [12] = 1500, --- Price for vans
    [13] = 1500, --- Price for cycles
    [14] = 1500, --- Price for boats
    [15] = 1500, --- Price for helicopters
    [16] = 1500, --- Price for planes
    [17] = 1500, --- Price for service vehicles
    [18] = 0,     --- Price for emergency vehicles
    [19] = 1500, --- Price for military vehicles
    [20] = 1500, --- Price for commercial vehicles
    [21] = 0      --- Price for trains (not applicable)
}

-- Police impound settings
Config.PoliceImpound = {
    Target = {
        groups = {
            police = 0  --- Groups allowed to access police impound
        }
    },
    location = {
        [1] = {
            blip = {
                enable = true,       --- Enable or disable the blip on the map
                sprite = 473,        --- Sprite ID for the blip
                colour = 40          --- Colour ID for the blip
            },
            label = "Pátio da Polícia",  --- Label for the police impound location
            zones = {
                points = {
                    vec3(824.69000244141, -1334.0200195312, 26.0),  --- Coordinates for the impound zone
                    vec3(831.70001220703, -1337.2700195312, 26.0),
                    vec3(831.73999023438, -1354.0300292969, 26.0),
                    vec3(832.10998535156, -1355.4799804688, 26.0),
                    vec3(824.72998046875, -1352.0400390625, 26.0),
                },
                thickness = 4.0,  --- Thickness of the zone boundaries
            },
        }
    }
}

-- Job vehicle shop settings
Config.JobVehicleShop = {
    {
        job = 'police',  --- Job associated with the vehicle shop
        label = 'Police Vehicle Shop',  --- Label for the vehicle shop
        ped = {
            model = 'csb_trafficwarden',  --- Pedestrian model for the shop
            coords = vec(457.9160, -1026.4635, 28.4376, 57.2678)  --- Coordinates for the shop
        },
        spawn = vec(443.9391, -1021.4270, 28.2857, 92.6928),  --- Coordinates where vehicles spawn
        vehicle = {
            police = {
                price = 500,  --- Price for the police vehicle
                label = 'Police 1',  --- Label for the vehicle
                prefixPlate = 'POL',  --- Prefix for the vehicle plate
                forRank = {
                    [0] = true,  --- Rank 0 can access this vehicle
                    [1] = true,  --- Rank 1 can access this vehicle
                    [2] = true   --- Rank 2 can access this vehicle
                }
            },
            police2 = {
                price = 500,  --- Price for the second police vehicle
                label = 'Police 2',  --- Label for the second vehicle
                prefixPlate = 'POL',  --- Prefix for the vehicle plate
                forRank = {
                    [0] = true,  --- Rank 0 can access this vehicle
                    [1] = true,  --- Rank 1 can access this vehicle
                    [2] = true   --- Rank 2 can access this vehicle
                }
            }
        },
    }
}

--- Do not modify this section
Config.HouseGarages = {}
