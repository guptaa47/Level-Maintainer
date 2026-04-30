local cfg = {}

-- ITEM EXAMPLE --

-- [item_name] = {threshold, batch_size} -- threshold not required
-- ["Platinum Dust"] = {1000, 64} -- regular item with threshold
-- ["Osmium Dust"] = {nil, 64} -- regular item without threshold


cfg["items"] = {
    ["Fluxed Electrum Dust"] = {1e4, 100},
    ["Lead Foil"] = {1000, 100}
    ["Tungstencarbide Foil"] = {1000, 100},
}

-- FLUID EXAMPLE --

-- [fluid_name] = {threshold, batch_size} -- threshold not required
-- ["Molten Soldering Alloy"] = {1e6, 1e4} -- regular fluid with threshold
-- ["Sulfuric Acid"] = {nil, 1000} -- regular fluid without threshold

cfg["fluids"] = {
    ["Gelid Cryotheum"] = {1e9, 1e6},
    ["Molten Atomic Separation Catalyst"] = {1e9, 1e6},
}

cfg["sleep"] = 60 -- in seconds --


cfg["interface_storage"] = nil -- INSERT ADDRESS OF ME INTERFACE TO MAINTAINED STORAGE NETWORK HERE --

cfg["interface_crafting"] = nil -- INSERT ADDRESS OF ME INTERFACE TO CRAFTING/MAIN NETWORK HERE --


return cfg