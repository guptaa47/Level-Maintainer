package.loaded.config = nil
local ae2 = require("src.AE2")
local cfg = require("config")
local util = require("src.Utility") 

util.logInfo("Items in maintained storage network:")
ae2.getMaintained("items")
util.logInfo("Fluids in maintained storage network:")
ae2.getMaintained("fluids")
