package.loaded.config = nil
local ae2 = require("src.AE2")
local cfg = require("config")
local util = require("src.Utility") 

local stored = {}
function log_items(items)
    if items ~= nil then
        for _, item in pairs(items) do
            print(item.label)
            stored[item.label] = true
end

util.logInfo("Items in maintained storage network:", "green")
log_items(ae2.getMaintained("items"))

util.logInfo("Fluids in maintained storage network:", "blue")
log_items(ae2.getMaintained("fluids"))

util.logInfo("All items and fluids maintained, but not in storage:", "red")
for name, _ in pairs(cfg.items) do
    if stored[name] == nil then print(name) end
for name, _ in pairs(cfg.fluids) do
    if stored[name] == nil then print(name) end