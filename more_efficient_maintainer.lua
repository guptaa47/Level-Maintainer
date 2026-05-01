package.loaded.config = nil
local cfg = require("config")
local util = require("src.Utility")

local event = require("event")
local component = require("component")
local me = component.me_interface
local me_storage = component.proxy(cfg.interface_storage, "me_interface")
local me_crafting = component.proxy(cfg.interface_crafting, "me_interface")

function logInfo(string)
    if type(string) == "string" then
        print("[" .. os.date("%H:%M:%S") .. "] " .. string)
    end
end

-- First check items are all craftable & unique

print("Checking config")

function getCraftableSearchObj(nme, config)
    return {label = nme}
end


local ok = true
local itemCount = 0
--[[
for item, config in pairs(cfg.items) do
    local craftable = me_crafting.getCraftables(getCraftableSearchObj(item, config))
    itemCount = itemCount + 1
    if #craftable == 1 then
        print("Found recipe for " .. item)
    elseif #craftable == 0 then
        print("No crafting recipe found for " .. item)
        ok = false
    else
        print("Ambiguous item name " .. item .. ", a random one might be chosen.")
        print("Current config: " .. util.dump(config))
        print("Current search: " .. util.dump(getCraftableSearchObj(item, config)))
        for _, c in ipairs(craftable) do
            print(util.dump(c.getItemStack()))
        end
    end
end
--]]

local craftableCache = {}
local reqCount = {}

function levelMaintain()
    local status = {}

    -- Get recipes to request
    local items = me_storage.getItemsInNetwork()
    for _, networkItem in ipairs(items) do
        local lbl = networkItem.label
        if cfg.items[lbl] == nil then
            goto nextItem
        end
        
        -- sets status true if # items >= threshold
        if cfg.items[lbl][2] ~= nil and networkItem.size >= cfg.items[lbl][2] then 
            status[lbl] = true
        end
        ::nextItem::
    end

    local fluids = me_storage.getFluidsInNetwork()
    for _, networkFluid in ipairs(fluids) do
        local lbl = networkFluid.label
        if cfg.fluids[lbl] == nil then
            goto nextFluid
        end

        if cfg.fluids[lbl][2] ~= nil and networkFluid.amount >= cfg.fluids[lbl][2] then
            status[lbl] = true
        end
        ::nextFluid::

    local requests = {}
    for name, cfg in pairs(cfg.items) do
        if status[name] == nil then
            table.insert(requests, {name, cfg[2], getCraftableSearchObj(name, cfg)})
        end
    end
    for name, cfg in pairs(cfg.fluids) do
        if status[name] == nil then
            fluid_name = "drop of " .. name
            table.insert(requests, {name, cfg[2], getCraftableSearchObj(fluid_name, cfg)})
        end
    end

    if #requests == 0 then
        logInfo("All items are above limits")
        return
    end

    -- Get all ongoing recipes
    local cpus = me_crafting.getCpus()
    local in_flight = {}
    for idx, cpu in ipairs(cpus) do
        local finalItem = cpu.cpu.finalOutput()
        if finalItem ~= nil then
            in_flight[finalItem.label] = true
        elseif cpu.cpu.isBusy() then
            print("WARN: CPU #" .. idx .. " does not have a crafting monitor, now using all pending and active recipes of that cpu")
            for _, item in ipairs(cpu.cpu.activeItems()) do
                print(item.label)
                in_flight[item.label] = true
            end
            for _, item in ipairs(cpu.cpu.pendingItems()) do
                print(item.label)
                in_flight[item.label] = true
            end
        end
    end


    local jobCnt = 0
    local jobs = {}
    for _, req in ipairs(requests) do
        if in_flight[req[1]] then
            logInfo("Skipping " .. req[1] .. " as it's already being crafted")
        else
            if reqCount[req[1]] == nil then
                reqCount[req[1]] = 0
            end
            reqCount[req[1]] = reqCount[req[1]] + 1
            if craftableCache[req[3]] == nil then
                local craftables = me_crafting.getCraftables(req[3])
                if #craftables == 0 then
                    print("No recipe is found")
                else
                    if #craftables > 1 then
                        print("Multiple recipe is found")
                    end
                    craftableCache[req[3]] = craftables[1]
                end
            end
            local craftable = craftableCache[req[3]]
            if craftable ~= nil then
                local job = craftable.request(req[2], false)
                table.insert(jobs, {req[1], job, req[3]})
                jobCnt = jobCnt + 1
            end
        end
    end

    while true do
        for idx, job in ipairs(jobs) do
            if not job[2].isComputing() then
                jobs[idx] = nil
                jobCnt = jobCnt - 1
                if job[2].hasFailed() then
                    logInfo("Failed to request " .. job[1])
                    craftableCache[job[3]] = nil
                else
                    logInfo("Requested " .. job[1])
                end
            end
        end
        if jobCnt == 0 then
            break
        end
        local id = event.pull(1, "interrupted")
        if id == "interrupted" then
            logInfo("interrupted")
            break
        end
    end

end

if ok then
    while true do
        logInfo("Started Requesting Items")
        levelMaintain()
        local id = event.pull(cfg.sleep, "interrupted")
        if id == "interrupted" then
            logInfo("interrupted")
            for nme, cnt in pairs(reqCount) do
                logInfo(nme .. ": " .. cnt)
            end
            break
        end
    end
else
    print("Exiting due to error in config")
end