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
            local cur_amount = getAmount(item)
            
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
                name, 
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

function assignJobs(jobs, jobCnt, requests, in_flight)
    for _, req in ipairs(requests) do
        local name, batch_size, query = req[1], req[2], req[3]
        if in_flight[name] then
            util.logInfo("Skipping " .. name .. " as it's already being crafted")
        else

            reqCount[name] = (reqCount[name] or 0) + 1
            local craftable = craftableCache[query]
            if craftable == nil then
                local craftables = me_crafting.getCraftables(query)
                if #craftables == 0 then
                    util.logInfo("No recipe found for " .. name, "red")
                else
                    if #craftables > 1 then
                        print("Multiple recipes found for " .. name .. "... selecting the first one", "yellow")
                    end
                    craftable = craftables[1]
                    craftableCache[query] = craftable
                end
            end

            if craftable ~= nil then
                local job = craftable.request(batch_size, false)
                table.insert(jobs, {name, job, query})
                jobCnt = jobCnt + 1
            end
        end
    end
end

local function trackPending(jobs, jobCnt)
    while true do
        for idx, job in ipairs(jobs) do
            local name, _job, query = job[1], job[2], job[3]
            if not _job.isComputing() then
                jobs[idx] = nil
                jobCnt = jobCnt - 1
                if _job.hasFailed() then
                    util.logInfo("Failed to request " .. name, "yellow")
                    craftableCache[query] = nil
                else
                    util.logInfo("Requested " .. name)
                end
            end
        end
        if jobCnt == 0 then
            break
        end
        local id = event.pull(1, "interrupted")
        if id == "interrupted" then
            util.logInfo("interrupted")
            break
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
        function(x) return x.size end,
    )
    updateStatus(
        status,
        me_storage.getFluidsInNetwork(),
        cfg.fluids,
        function(x) return x.amount end,
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
    local jobCnt = 0
    local jobs = {}
    assignJobs(jobs, jobCnt, request, in_flight)
    trackPending(jobs, jobCnt)
end

local function sleepHandler()
    local id = event.pull(cfg.sleep, "interrupted")
    if id == "interrupted" then
        util.logInfo("interrupted, printing counts of all requests")
        for nme, cnt in pairs(reqCount) do
            util.logInfo(nme .. ": " .. cnt)
        end
        break
    end
end

if ok then
    while true do
        util.logInfo("Started Requesting Items", "blue")
        levelMaintain()
        util.logInfo("Waiting For Next Cycle", "blue")
        sleepHandler()
    end
else
    print("Exiting due to error in config")
end