package.loaded.config = nil
local component = require("component")
local cfg = require("config")
-- local ME = component.me_interface
local ME_storage = component.proxy(cfg.interface_storage, "me_interface")
local ME_crafting = component.proxy(cfg.interface_crafting, "me_interface")

local AE2 = {}
--[[
-- Lightweight cache for specific items only
local itemCache = {}
local cacheTimestamp = 0
local CACHE_DURATION = 600 -- 10 minutes in seconds

-- Function to get or cache a specific craftable item
local function getCraftableForItem(itemName)
    local currentTime = os.time()
    
    -- Check if we have a cached version of this specific item and it's still valid
    if itemCache[itemName] and currentTime - cacheTimestamp < CACHE_DURATION then
        return itemCache[itemName]
    end
    
    -- If cache is too old, clear it completely to save memory
    if currentTime - cacheTimestamp >= CACHE_DURATION then
        itemCache = {}
        cacheTimestamp = currentTime
    end
    
    -- Look for this specific item in craftables
    local craftables = ME_crafting.getCraftables({["label"] = itemName})
    if #craftables >= 1 then
        itemCache[itemName] = craftables[1] -- Cache only this one item
        return craftables[1]
    end
    
    itemCache[itemName] = nil -- Cache that it's not craftable
    return nil
end

function AE2.requestItem(name, threshold, count, fluidName)
    local craftable = getCraftableForItem(name)

    if craftable then
        local item = craftable.getItemStack()
        if threshold ~= nil then
            local itemInSystem = nil
            
            if fluidName then
                local fluidTag = '{Fluid:' .. fluidName .. '}'
                itemInSystem = ME_storage.getItemInNetwork("ae2fc:fluid_drop", 0, fluidTag)
            else
                if item.name then
                    if item.tag then
                        itemInSystem = me_interface.getItemInNetwork(item.name, item.damage or 0, item.tag)
                    end
                    
                    -- Fallback: try with just the internal name and damage
                    if itemInSystem == nil then
                        itemInSystem = ME_storage.getItemInNetwork(item.name, item.damage or 0)
                    end
                end
            end
            
            if itemInSystem ~= nil and itemInSystem.size >= threshold then 
                return table.unpack({false, "The amount of " .. (itemInSystem.label or name) .. " (" .. itemInSystem.size .. ") meets or exceeds threshold (" .. threshold .. ")! Aborting request."})
            end
        end
        
        if item.label == name then
            local craft = craftable.request(count)

            while craft.isComputing() == true do
                os.sleep(1)
            end
            if craft.hasFailed() then
                return table.unpack({false, "Failed to request " .. name .. " x " .. count})
            else
                return table.unpack({true, "Requested " .. name .. " x " .. count})
            end
        end
    end
    return table.unpack({false, name .. " is not craftable!"})
end

function AE2.checkIfCrafting()
    local cpus = ME_crafting.getCpus()
    local items = {}
    for k, v in pairs(cpus) do
        local finaloutput = v.cpu.finalOutput()
        if finaloutput ~= nil then
            items[finaloutput.label] = true
        end
    end

    return items
end

-- Function to manually clear the cache if needed
function AE2.clearCache()
    itemCache = {}
    cacheTimestamp = 0
end
--]]

-- Function to return everything in maintained storage network
function AE2.getMaintained(_type)
    local items = nil
    if _type == "items" then
        items = ME_storage.getItemsInNetwork()
    elseif _type == "fluids" then
        items = ME_storage.getFluidsInNetwork()
    else
        return
    end
    return items
end

return AE2