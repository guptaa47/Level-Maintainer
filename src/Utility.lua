package.loaded.config = nil
local Utility = {}

function Utility.dump(o, depth)
    if depth == nil then depth = 0 end

    if depth > 10 then return "..." end

    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. '[' .. k .. '] = ' .. Utility.dump(v, depth + 1) .. ',\n'
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

function Utility.parser(string)
    if type(string) == "string" then
        local numberString = string.gsub(string, "([^0-9]+)", "")
        if tonumber(numberString) then
            return math.floor(tonumber(numberString) + 0)
        end
        return 0
    else
        return 0
    end
end

function Utility.logInfo(string, color)
    local color_start = "\27[0m"
        if color ~= nil and type(color) == "string" then
            if color == "black" then color_start = "\27[30m"
            elseif color == "red" then color_start = "\27[31m"
            elseif color == "green" then color_start = "\27[32m"
            elseif color == "yellow" then color_start = "\27[33m"
            elseif color == "blue" then color_start = "\27[34m"
            elseif color == "purple" then color_start = "\27[35m"
            elseif color == "cyan" then color_start = "\27[36m"
            elseif color == "white" then color_start = "\27[37m"
            end
        end
    if type(string) == "string" then
        print(color_start .. "[" .. os.date("%H:%M:%S") .. "] " .. string .. "\27[0m")
    end
end

return Utility