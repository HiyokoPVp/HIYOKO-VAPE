--[[
    Vape V4 URL Configuration
    All GitHub URLs managed here
--]]

local URLs = {
    -- Base Configuration
    Owner = "YourUsername",
    Repo = "YourRepo",
    Branch = "main",
    
    -- Auto-generated base URL
    _baseURL = nil,
}

-- Generate base URL
function URLs:GetBaseURL()
    if not self._baseURL then
        self._baseURL = string.format("https://raw.githubusercontent.com/%s/%s/%s", 
            self.Owner, self.Repo, self.Branch)
    end
    return self._baseURL
end

-- Get full URL for any path
function URLs:Get(path)
    -- Remove leading slash if present
    if path:sub(1, 1) == "/" then
        path = path:sub(2)
    end
    return self:GetBaseURL() .. "/" .. path
end

-- Main files
function URLs:GetLoader()
    return self:Get("loader.lua")
end

function URLs:GetMain()
    return self:Get("main.lua")
end

function URLs:GetNewMain()
    return self:Get("NewMainScript.lua")
end

-- Libraries
function URLs:GetLibrary(name)
    return self:Get("libraries/" .. name .. ".lua")
end

-- GUIs
function URLs:GetGUI(name)
    return self:Get("guis/" .. name .. ".lua")
end

-- Games
function URLs:GetGame(gameId)
    if gameId == "universal" then
        return self:Get("games/universal.lua")
    else
        return self:Get("games/" .. tostring(gameId) .. ".lua")
    end
end

-- Assets
function URLs:GetAsset(path)
    return self:Get("assets/" .. path)
end

return URLs
