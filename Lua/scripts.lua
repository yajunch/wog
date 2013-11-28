-- !!! init variable

local _G = _G
local internal = debug.getregistry()

local type = type
local unpack = unpack
local assert = assert
local format = string.format
local string_match = string.match
local string_find = string.find
local string_lower = string.lower

local next = next
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local rawget = rawget
local rawset = rawset
local getfenv = getfenv
local setfenv = setfenv
local pcall = pcall
local pcall2 = pcall2
local xpcall = xpcall

local load = load
local loadfile = loadfile
local loadstring = loadstring
internal.load = load
internal.loadfile = loadfile
internal.loadstring = loadstring
local table_insert = table.insert
local table_remove = table.remove
local table_concat = table.concat
local math_min = math.min
local math_floor = math.floor
local math_ceil = math.ceil
local abs = math.abs
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_running = coroutine.running
local dofile = dofile
local debug_getinfo = debug.getinfo

local error = error
local events = events
local make_events = events.new
local tostring2 = tostring2
local table_copy = table.copy
local path_find = path.find
local path_setext = path.setext
local path_addslash = path.addslash
local path_name = path.name
local io_LoadString = io.LoadString
local call = mem.call
local pchar = mem.pchar
local topointer = mem.topointer
local i4, i2, i1, u4, u2, u1 = mem.i4, mem.i2, mem.i1, mem.u4, mem.u2, mem.u1
local mem_DynStrShort = mem.DynStrShort
local mem_hookcall = mem.hookcall
local mem_string = mem.string

local getmetatable = debug.getmetatable
local setmetatable = setmetatable
local ErrorMessage = ErrorMessage

local AppPath = AppPath
local setmetatableW = internal.setmetatableW
local protectMetatable = internal.protectMetatable
local LuaGetLastError = internal.LuaGetLastError
local roError = internal.roError
local readonly = internal.readonly
local FindReciever = internal.FindReciever
local persist = internal.persist
local unpersist = internal.unpersist

local LoadModOptions = internal.LoadModOptions

local print = print
local dump = dump

----------- No globals from this point ------------

local _NOGLOBALS

----------- Scripts events ------------

local map_events
local gen_events = _G.events
local int_events = internal.events

local function event_call(...)
	gen_events.call(...)
	map_events.call(...)
end

local function event(...)
	int_events.call(...)
	pcall2(event_call, ...)
end
internal.event = event
-- _G.event = event

----------- Scripts support ------------

local map

local function user_index(t, a)
	local ret = map[a]
	if ret ~= nil then  return ret  end

	ret = _G[a]
	if ret ~= nil then  return ret  end
	
	ret = FindReciever(a)
	if ret ~= nil then  return ret  end
end

local function scriptenv(env)
	return setmetatable(env, setmetatableW({__index = user_index, __persist = true}, {__persist = 0}))
end

----------- require ------------

local StoredScripts  -- {chunk text, chunk name, package name, env} or {ERM dyn string id, reload path (for mapnam.lua script)}
local PackageLoadedGlobal
local PackageLoaded = {}
local PackageScripts = {}
local ScriptPath = {}
_G.package = nil

local function LoadPackage(ftext, chunkname, name, env)
	if not env then
		local ModName = string_match(name, "([^%.]*)%.")
		env = {start = true, ModName = ModName, ModPath = ModName and internal.ModsPath..ModName.."\\"}
	end
	env = scriptenv(env)

	PackageLoaded[name] = env
	if PackageLoadedGlobal then
		StoredScripts[#StoredScripts + 1] = {ftext, chunkname, name, env}
	end

	local f = assert(loadstring(ftext, chunkname))
	setfenv(f, env)
	pcall2(f)
	local start = env.start
	env.start = start ~= true and start
	return env
end

local function LoadPackageScript(name)
	local r = PackageScripts[name]
	if r then
		PackageScripts[name] = nil
		return LoadPackage(unpack(r))
	end
end

local function AddModName(name)
	local mod = getfenv(debug_getinfo(3, 'f').func).ModName
	return mod and format("%s.%s", mod, name)
end

local function require(name)
	name = string_lower(name)
	if not string_find(name, ".", 1, true) then
		name = AddModName(name) or name
	end
	local r = PackageLoaded[name] or LoadPackageScript(name)
	if r then
		return r
	end
	local fname = ScriptPath[name] or	error(format("%q script not found", name), 2)
	return LoadPackage(io_LoadString(fname), '@'..path_name(fname), name)
end
_G.require = require


local function scripts_index(_, name)
	name = string_lower(name)
	return PackageLoaded[name] or PackageLoaded[AddModName(name)]
end
_G.scripts = setmetatableW({}, {__index = scripts_index})


local function scriptvars_get(name)
	local r = PackageLoaded[name]
	if r then
		return r
	end
	r = PackageScripts[name]
	if r then
		return r[4]
	end
end

local function scriptvars_index(_, name)
	name = string_lower(name)
	local r = scriptvars_get(name) or scriptvars_get(AddModName(name))
end
_G.scriptvars = setmetatableW({}, {__index = scriptvars_index})


local function ResetPackage()
	PackageLoadedGlobal = PackageLoadedGlobal or PackageLoaded
	PackageLoaded = setmetatable({}, {__index = PackageLoadedGlobal})
end
internal.ResetPackage = ResetPackage

----------- context, triggers ------------

local triggers
internal.context = "menu"
local DefScriptEnv

function internal.CallTrigger(typeN, i)
	if typeN == 0 then
		triggers[i]()
	end
end

function internal.LoadTriggers()
end

local function createMap(cont)
	if map_events then
		event("LeaveContext", cont)
	end
	local campaign
	if internal.context ~= "menu" and cont ~= "menu" then
		campaign = map.campaign
	end
	StoredScripts = {}
	map_events = make_events{new = make_events}
	map = {events = map_events, campaign = campaign}
	map._G = map
	internal.map = map
	triggers = {}
	internal.triggers = triggers
	DefScriptEnv = scriptenv{start = true}
	internal.context = cont
	_G.context = cont
	if internal.BaseOptions then
		internal.CurOptions = internal.CopyOptionsTable(internal.BaseOptions)
	end
end
createMap("menu")

local function LoadContext(cont)
	createMap(cont)
	ResetPackage()
end


local ResetERMMainMenuPtr = internal.ResetERMMainMenuPtr

function internal.ExitToContext(cont)
	if cont == "menu" and internal.context ~= "menu" or internal.context == "map" then
		call(ResetERMMainMenuPtr, 0)
		createMap(cont)
		ResetPackage()
		event("EnterContext")
	end
end

--------------------------- load* functions --------------------------

local function loadscript(load, ...)
	local f, err = load(...)
	if f then
		rawset(DefScriptEnv, "start", true)
		setfenv(f, DefScriptEnv)
	end
	return f, err
end

function _G.dofile(path, ...)
	local f, err = loadscript(loadfile, path)
	if f then
		return f(...)
	end
	error(err)
end

function _G.dofile2(path, ...)
	local f, err = loadscript(loadfile, path)
	if f then
		return pcall2(f, ...)
	end
	ErrorMessage(err)
	return false, err
end

function _G.loadfile(...)
	return loadscript(loadfile, ...)
end

function _G.loadstring(...)
	return loadscript(loadstring, ...)
end

function _G.load(...)
	return loadscript(load, ...)
end

--------------------------- Load Mods -------------------------

local ScriptFolders = {
	scripts = {},
	global = {},
	map = {},
	wogify = {},
}

local ErmFolders = {}
local ErtFolders = {}
-- local ErsFolders = {}

local function FetchModScripts(mask, mod)
	local files = {mod = mod}
	for f, t in path_find(mask) do
		local name = string_lower(string_match(t.FileName, "[^%.]*"))
		local fullname = mod.."."..name
		if ScriptPath[fullname] then
			error(format("duplicate script name found: %s, %s", ScriptPath[fullname], f))
		end
		ScriptPath[fullname] = f
		files[#files + 1] = fullname
	end
	return files
end

local function FetchFiles(mask, mod)
	local files = {mod = mod}
	for f in path_find(mask) do
		files[#files + 1] = f
	end
	return files
end

local function LoadMod(path, name)
	if string_find(name, ".", 1, true) then
		return
	end
	name = string_lower(name)
	for folder, t in pairs(ScriptFolders) do
		t[#t + 1] = FetchModScripts(format("%s%s\\*.lua", path, folder), name)
	end
	ErmFolders[#ErmFolders + 1] = FetchFiles(path.."erm\\*.erm", name)
	ErtFolders[#ErtFolders + 1] = FetchFiles(path.."replace\\*.ert", name)
	-- ErsFolders[#ErsFolders + 1] = FetchFiles(path.."erm\\*.ers", name)
	LoadModOptions(name, path)
end

-- load mods now
-- TODO: mods ordering, dependancies, other mod info
for f, t in path_find(internal.ModsPath.."*", true) do
	LoadMod(path_addslash(f), t.FileName)
end
internal.AllOptionsLoaded()

--------------------------- Load scripts -------------------------

local function LoadStoredScripts(first)
	local LoadGame = not first
	if LoadGame then
		PackageScripts = {}
	end
	for i = first or 1, #StoredScripts do
		local t = StoredScripts[i]
		if not t.erm then
			PackageScripts[t[3]] = t
		end
	end
	for i = first or 1, #StoredScripts do
		local t = StoredScripts[i]
		if not t.erm then
			pcall2(LoadPackageScript, t[3])
		else
			if LoadGame and t.ReloadFrom then
				local ok, s = pcall2(io_LoadString, t.ReloadFrom)
				if ok then
					mem_DynStrShort[internal.ErmDynString + 12*t[1]] = s;
				end
			end
			internal.ERM_RunScript(t[1])
		end
	end
end

local function LoadScripts(folder)
	for _, t in ipairs(ScriptFolders[folder]) do
		for _, s in ipairs(t) do
			pcall2(require, s)
		end
	end
end
internal.LoadScripts = LoadScripts

--------------------------- Persist --------------------------

local permanents = {_G, internal, _G.scripts}
local persistProc
local AutoPersist = internal.AutoPersist

do
	local simple = {number = true, string = true, boolean = true}
	local perm = _G.table.invert(permanents)
	function persistProc(t)
		local tp = type(t)
		if simple[tp] then
			return t
		end
		local v = perm[t]
		if v ~= nil then
			return v
		end
		if tp == "table" then
			local m = getmetatable(t)
			if type(m) ~= "table" or m.__persist == true then
				return t
			end
		end
	end
end

function internal.SaveGame()
	event("SaveGame")
	local saves = {map = map, scripts = StoredScripts, options = internal.SaveGameOptions()}
	for k in pairs(AutoPersist) do
		saves[k] = internal[k]
	end
	local data, err = persist(saves, persistProc)
	if err then
		ErrorMessage(err)
	end
	internal.Saver(data)
end

function internal.LoadGame()
	LoadContext("map")
	local saves, err = unpersist(internal.Loader(), permanents)
	if err then
		ErrorMessage(err)
	end
	for k in pairs(AutoPersist) do
		internal[k] = saves[k]
	end
	StoredScripts = saves.scripts
	map = saves.map
	internal.map = map
	internal.LoadGameOptions(saves.options or {})
end

---------------------------  --------------------------

local function LoadAllERT()
	for _, t in ipairs(ErmFolders) do
		for _, s in ipairs(t) do
			for f in path_find(path_setext(s, ".ert")) do
				internal.LoadERT(f)
			end
		end
	end
	for _, t in ipairs(ErtFolders) do
		for _, s in ipairs(t) do
			internal.LoadERT(s, true)
		end
	end
end

local function FromFileERM(path)
	local ok, s = pcall2(io_LoadString, path)
	if ok and internal.ERM_CheckScript(topointer(s), #s) then
		return {
			internal.ERM_DynString(topointer(s), #s),  -- str index
			path,  -- name for error messages
			erm = true
		}
	end
end

local function LoadAllERM()
	local nstored = #StoredScripts
	for _, t in ipairs(ErmFolders) do
		for _, name in ipairs(t) do
			StoredScripts[#StoredScripts + 1] = FromFileERM(name)
		end
	end
	LoadStoredScripts(nstored + 1)
end

-- function internal.LoadAllERS()
	-- local i = 0
	-- for _, t in ipairs(ErsFolders) do
		-- for _, s in ipairs(t) do
			-- internal.LoadERS(s, i)
			-- i = i + 1
		-- end
	-- end
-- end


local EventNames = {}

mem_hookcall(0x4FC86F, 2, 0, function(d, def, stream, p)
	def(stream, p)
	EventNames[#EventNames + 1] = mem_DynStrShort[p + 4]
end)

local function LoadMapScript(evtName, evt)
	local lua = false
	local t
	local ptext = evt + 4
	local name = string_match(evtName, "^(ZVSL.[^%.]*)")
	if name then
		t = {
			mem_DynStrShort[ptext],  -- chunk text
			"@"..name,  -- chunk name
			string_lower(name),  -- script name
		}
		lua = true
	elseif internal.ERM_CheckScript(u4[ptext], i4[ptext + 4]) then
		t = {
			internal.ERM_DynString(u4[ptext], i4[ptext + 4]),  -- str index
			"["..evtName.."]",  -- name for error messages
			erm = true
		}
	end
	if t then
		StoredScripts[#StoredScripts + 1] = t
		-- remove global event
		mem_DynStrShort[ptext] = ""
		u1[evt + 0x2C] = 0
	end
	return lua
end

local function RunMapScripts()
	local ver = u4[u4[0x699538] + 0x1F86C]
	map.version = ver
	
	LoadAllERT()
	event("EnterContext")
	
	LoadScripts("map")
	event("BeforeMapScripts")

	local hasScripts, hasExternal, hasLua = false, false, false
	-- execute map scripts if it's a WoG map
	if ver == 0x33 then
		local nstored = #StoredScripts
		-- load scripts from global events
		local evt = u4[u4[0x699538] + 0x1FBF4]
		for i = 1, #EventNames do
			hasLua = LoadMapScript(EventNames[i], evt) or hasLua
			evt = evt + 0x34
		end
		hasScripts = nstored ~= #StoredScripts
		-- load mapname.erm
		for f in path_find(AppPath.."Maps\\"..path_setext(mem_string(u4[0x699538] + 0x1F6D9), ".erm")) do
			local t = FromFileERM(f)
			if t then
				t.ReloadFrom = f
				StoredScripts[#StoredScripts + 1] = t
				hasExternal = true
			end
		end
		-- run all scripts
		LoadStoredScripts(nstored + 1)
	end
	EventNames = {}
	event("AfterMapScripts")
	-- check if it should be WoGified
	local wogify = internal.ERM_CheckWogify(hasScripts, hasExternal, hasLua)
	map.wogified = wogify
	internal.wogified = wogify
	-- load WoGification scripts
	if wogify then
		--LoadAllERT()
		LoadScripts("wogify")
		-- LoadAllERM()
	end
end

function internal.EnterMapNewGame()
	if internal.wogified then
		event("Wogify")
		LoadAllERM()
		event("Wogified")
	else
		event("NotWogified")
	end
end

function internal.EnterMap(Loaded)
	if Loaded == 0 then
		LoadContext("map")
		RunMapScripts()
	else
		event("EnterContext")
		LoadStoredScripts()
		event("LoadGame", call(internal.HasAnyAtThisPCPtr, 0) ~= 0)
	end
end

--------------------------- ERM Errors -------------------------

function internal.ERMErrorInfo(pos, OneLine)
	local str = mem_string(pos, 200) or ""
	if OneLine then
		str = string_match(str, "[^\n\r]*")
	end
	for _, t in ipairs(StoredScripts) do
		if t.erm then
			local p = internal.ErmDynString + 12*t[1]
			if pos >= u4[p] and pos < u4[p] + i4[p + 4] then
				local n = 1
				for i = u4[p], pos - 1 do
					if u1[i] == 10 then  -- "\n"
						n = n + 1
					end
				end
				local fmt = (OneLine and "%s:%d:\n%s" or "{%s:%d:}\n%s")
				return format(fmt, t[2], n, str)
			end
		end
	end
	return str
end
