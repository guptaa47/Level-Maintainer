local ae2 = require("src.AE2")
local cfg = require("config")
local util = require("src.Utility") 

logInfo("Items in maintained storage network:")
ae2.getMaintained("items")
logInfo("Fluids in maintained storage network:")
ae2.getMaintained("fluids")
