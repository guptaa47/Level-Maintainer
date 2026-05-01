package.loaded.config = nil
local cfg = require("config")
local util = require("src.Utility")

local event = require("event")
local component = require("component")
local me = component.me_interface
local me_storage = component.proxy(cfg.interface_storage, "me_interface")
local me_crafting = component.proxy(cfg.interface_crafting, "me_interface")

print("Checking config")

local ok = true
local craftableCache = {}
local reqCount = {}

local function updateStatus(status, items, config, getAmount)
    for _, networkItem in ipairs(items) do
        local lbl = networkItem.label
        local itemConfig = config[lbl]

        if itemConfig == nil then
            util.logInfo("WARN: " .. lbl .. " is visible to OC storage subnet, but not being maintained", "yellow")
        else
            local threshold = itemConfig[2]
            local cur_amount = getAmount(networkItem)
            
            status[lbl] = (threshold ~= nil and cur_amount >= threshold)
        end
    end
end

local function updateRequests(requests, config, status, nameTransform)
    for name, vals in pairs(config) do
        if status[name] ~= true then
            if status[name] == nil then
                util.logInfo(
                    "CRITICAL: " .. lbl .. " is NOT visible to OC storage subnet, so cannot manage threshold",
                    "red")
            end

            table.insert(requests, {
                nameTransform(name), 
                vals[2], 
                {label = nameTransform(name)}
            })
        end
    end
end

local function ongoingRecipes(in_flight)
    local cpus = me_crafting.getCpus()
    local available_cpus = 0
    for idx, cpu in ipairs(cpus) do
        local finalItem = cpu.cpu.finalOutput()
        if finalItem ~= nil then
            in_flight[finalItem.label] = true
        elseif cpu.cpu.isBusy() then
            util.logInfo("WARN: CPU #" .. idx .. " does not have a crafting monitor, now using all pending and active recipes of that cpu", "yellow")
            for _, item in ipairs(cpu.cpu.activeItems()) do
                in_flight[item.label] = true
            end
            for _, item in ipairs(cpu.cpu.pendingItems()) do
                in_flight[item.label] = true
            end
        else
            available_cpus = available_cpus + 1
        end
    end
    return available_cpus
end

function assignJobs(jobs, requests, in_flight)
    for _, req in ipairs(requests) do
        local name, batch_size, query = req[1], req[2], req[3]
        if in_flight[name] then
            util.logInfo("Skipping " .. name .. " as it's already being crafted")
        else

            reqCount[name] = (reqCount[name] or 0) + 1
            local craftable = craftableCache[name]
            if craftable == nil then
                local craftables = me_crafting.getCraftables(query)
                if #craftables == 0 then
                    util.logInfo("No recipe found for " .. name, "red")
                else
                    if #craftables > 1 then
                        print("Multiple recipes found for " .. name .. "... selecting the first one", "yellow")
                    end
                    craftable = craftables[1]
                    craftableCache[name] = craftable
                end
            end

            if craftable ~= nil then
                local job = craftable.request(batch_size, false)
                if not job.isComputing() and not job.isDone() then
                    util.logInfo("Possibly insufficient inputs for " .. name, "yellow")
                end
                table.insert(jobs, {name, job})
            end
        end
    end
end

local function trackPending(jobs)
    while next(jobs) do
        for i = #jobs, 1, -1 do
            local row = jobs[i]
            local name, job = row[1], row[2]

            if not job.isComputing() then
                table.remove(jobs, i)

                if job.hasFailed() then
                    util.logInfo("Failed to request " .. name, "yellow")
                    craftableCache[name] = nil
                elseif job.isCanceled() then
                    util.logInfo("Canceled request for " .. name, "yellow")
                else
                    util.logInfo("Requested " .. name)
                end
            end
        end
        local id = event.pull(1, "interrupted")
        if id == "interrupted" then
            util.logInfo("interrupted")
            return
        end
    end
end

function levelMaintain()
    -- Compute items with insufficient quantity
    local status = {}
    updateStatus(
        status,
        me_storage.getItemsInNetwork(),
        cfg.items,
        function(x) return x.size end
    )
    updateStatus(
        status,
        me_storage.getFluidsInNetwork(),
        cfg.fluids,
        function(x) return x.amount end
    )

    -- Build recipe requests
    local requests = {}
    updateRequests(requests, cfg.items, status, function(x) 
        return x
    end)
    updateRequests(requests, cfg.fluids, status, function(x)
        return "drop of " .. x
    end)

    if #requests == 0 then
        util.logInfo("All items are above limits")
        return
    end

    -- Determine items currently being crafted
    local in_flight = {}
    local available_cpus = ongoingRecipes(in_flight)
    if available_cpus < #requests then
        util.logInfo("WARN: Fewer CPUs than requested crafts. Some crafts may get delayed", "yellow")
    end

    -- Send requests to crafting network
    local jobs = {}
    assignJobs(jobs, requests, in_flight)
    print("assigned jobs")
    trackPending(jobs)
    print("done pending")
end

local function sleepHandler()
    local id = event.pull(cfg.sleep, "interrupted")
    if id == "interrupted" then
        util.logInfo("interrupted, printing counts of all requests")

        for nme, cnt in pairs(reqCount) do
            util.logInfo(nme .. ": " .. cnt)
        end

        return false
    end
    return true
end

if ok then
    while true do
        util.logInfo("Started Requesting Items", "blue")
        levelMaintain()
        util.logInfo("Waiting For Next Cycle", "blue")
        if not sleepHandler() then break end
    end
else
    print("Exiting due to error in config")
end