a--[=[
	BATCH TO ROBLOX LUA
	EXAMPLES:

rem This is a comment
rem Set a variable "yourname" to John Doe
set yourname=John Doe
rem Print "Welcome, John Doe!"
echo Welcome, %yourname%!
rem Do a for i loop
rem In this compiler, we do NOT do %%index, instead we do %index% (as a variable like Roblox Lua)
for /l %index% in (1, 1, 5) do (
    echo New count: %index%
)
rem If ___ then (conditions):
rem You should NOT add "(", otherwise it will syntax error (TODO: fix this)
if workspace:FindFirstChild("Hey") ~= nil
	workspace:FindFirstChild("Hey"):Destroy()
	echo Your name is %yourname%!
)
rem Example script that kills the player everytime a character spawns (serverside only!)
local compiler = require(game:GetService("ReplicatedStorage"):FindFirstChild("batch2lua"))

compiler.compile([[
game:GetService("Players").PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		Humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
		if Humanoid ~= nil
			Humanoid:TakeDamage(100000000000000000)
		)
	end)
end)
]]).execute();

--]=]

local isRobloxStudio = not select(1, pcall(function()
	debug.getinfo(2, "f")
end))

if not isRobloxStudio then
	function string.split(input, delimiter)
		local result = {}
		local pattern = string.format("([^%s]+)", delimiter)
		input:gsub(pattern, function(substring)
			table.insert(result, substring)
		end)
		return result
	end
end

-- Function to translate a batch script line to Lua equivalent
local isLua5_1 = (not getfenv and true) or false
local function translateBatchLine(line)
	line = line:gsub("^%s+", "")

	line = line:gsub("%%%%(%w+)%%%%", "%%%1%")
	line = line:gsub("%%(.-)%%", function(var)
		return ('{%s}'):format(var)
	end)

	if line:lower():find("^echo") then
		local message = line:sub(5):gsub('"', '\\"')
		message = message:gsub("%%%w+%%", function(var)
			return ('{%s}'):format(var:sub(2, -2))
		end)
		if isLua5_1 then
			return ("print([[%s]])"):format(message)
		else
			return ('print(`%s`)'):format(message)
		end
	elseif line:lower():find("^set") then
		local var, value = line:match("^set%s+(.-)=(.*)$")
		if var and value then
			return ('%s = "%s"'):format(var, value)
		else
			print("Invalid set command:", line)
		end
	elseif line:lower():find("^for /l") then
		-- Handle for /l loop syntax
		local iterator, params = line:match("^for%s+/l%s+(%%%w+)%%%s+in%s+%(([^%)]+)%)%s+do$")
		if iterator and params then
			local parts = string.split(params, ",")
			if #parts == 3 then
				local start = parts[1]:gsub("%s+", "")
				local step = parts[2]:gsub("%s+", "")
				local finish = parts[3]:gsub("%s+", "")
				return ('for %s = %s, %s, %s do'):format(iterator:sub(2, -2), start, finish, step)
			else
				print("Invalid for /l loop syntax:", line)
			end
		else
			print("Invalid for /l loop syntax:", line)
		end
	elseif line:lower():find("^@echo off") or line:lower():find("^rem") then
		-- Ignore @echo off and REM lines
		return nil
	elseif line:lower():match("^if") then
		local condition = line:match("^if%s+(.+)$")
		if condition then
			return ('if (%s) then'):format(condition)
		else
			print("Invalid if command syntax:", line)
		end
	elseif line:lower() == ")" then
		return "end"
	else
		return line
	end
end

local function batchToLua(batchScript)
	local luaScript = {}
	for line in batchScript:gmatch("[^\r\n]+") do
		local translatedLine = translateBatchLine(line)
		if translatedLine then
			table.insert(luaScript, translatedLine)
		end
	end
	return table.concat(luaScript, "\n")
end

local compiler = {}

function compiler.new(code)
	local self = {}
	local success, lua, error = nil--pcall((load or loadstring), batchToLua(code))
	
	if not isRobloxStudio then
		success, lua, error = pcall((load or loadstring), batchToLua(code))
	else
		success, lua, error = pcall(require(script.Loadstring), batchToLua(code))
	end
	
	function self.execute()
		print(lua, error)
		local success, error = pcall(lua)
		
		if error then
			warn("Batch2Lua:", error)
		end
		
		return self
	end
	
	self.get_lua_return = function() return batchToLua(code) end
	
	function self.change_code(code)
		if not isRobloxStudio then
			success, lua, error = pcall((load or loadstring), batchToLua(code))
		else
			success, lua, error = pcall(require(script.Loadstring), batchToLua(code))
		end

		self.execute = function()
			local success, error = pcall(lua)

			if error then
				warn("Batch2Lua:", error)
			end

			return self
		end
		
		self.get_lua_return = function() return batchToLua(code) end
	end
	
	return self
end

return compiler
