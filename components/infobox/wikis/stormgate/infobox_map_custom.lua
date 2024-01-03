---
-- @Liquipedia
-- wiki=stormgate
-- page=Module:Infobox/Map/Custom
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local Abbreviation = require('Module:Abbreviation')
local Array = require('Module:Array')
local Class = require('Module:Class')
local Lua = require('Module:Lua')
local Operator = require('Module:Operator')
local String = require('Module:StringUtils')
local Table = require('Module:Table')

local Injector = Lua.import('Module:Infobox/Widget/Injector', {requireDevIfEnabled = true})
local Map = Lua.import('Module:Infobox/Map', {requireDevIfEnabled = true})

local Widgets = require('Module:Infobox/Widget/All')
local Cell = Widgets.Cell
local Title = Widgets.Title

local CustomMap = Class.new()

local CustomInjector = Class.new(Injector)

local CAMPS = {
	{key = 'resourcecamps', name = 'Resource Camp(s)'},
	{key = 'speedcamps', name = 'Speed Camp(s)'},
	{key = 'healthcamps', name = 'Health Camp(s)'},
	{key = 'siegecamps', name = 'Siege Camp(s)'},
}
--currently the ingame icons are still temporary
--use placeholders until ingame icons are final and we get them
local RESOURCE_ICONS = {
	luminite = Abbreviation.make('Lum', 'Luminite'),
	therium = Abbreviation.make('The', 'Therium'),
}
local LADDER_HISTORY = {
	{key = '1v1history', name = '1v1 Ladder'},
	{key = '3v3history', name = '3v3 Ladder'},
}
---@enum StormgateManualMapTypes
local ManualMapTypes = {
	COOP = 'COOP',
	MISC = 'MISC',
}
local LADDER_MAP_TYPE_KEY = 'LADDER'

---@enum StormgateMapTypes
local MapTypes = {
	LADDER = 'Ladder',
	COOP = 'Co-Op',
	MISC = 'Miscellaneous',
}

local _args

---@param frame Frame
---@return Html
function CustomMap.run(frame)
	local customMap = Map(frame)

	customMap.createWidgetInjector = CustomMap.createWidgetInjector
	customMap.addToLpdb = CustomMap.addToLpdb
	customMap.args = CustomMap._parseArgs(customMap.args)
	_args = customMap.args

	return customMap:createInfobox()
end

---@param args table
---@return table
function CustomMap._parseArgs(args)
	local keysThatShouldHaveNumberValues = Array.extend({
			'rushDistance',
			'height',
			'width',
			'luminite',
			'therium',
			'closedTherium',
		},
		Array.map(CAMPS, Operator.property('key'))
	)
	Array.forEach(keysThatShouldHaveNumberValues, function(key)
		local value = tonumber(args[key])
		args[key] = value ~= 0 and value or nil
	end)
	args.types =  Array.map(mw.text.split((args.type or ManualMapTypes.MISC):upper(), ','), String.trim)

	--check for invalid type input
	assert(
		Array.all(args.types, function(mapType) return ManualMapTypes[mapType] ~= nil end),
		'"|type=' .. (args.type or '') .. '" contains at least one invalid type'
	)

	args.isLadder = Array.any(LADDER_HISTORY, function(histData)
		return String.isNotEmpty(args[histData.key])
	end)
	if args.isLadder then
		table.insert(args.types, 1, LADDER_MAP_TYPE_KEY)
	end

	args.players = tonumber(args.players) or Table.size(mw.text.split(args.positions))

	return args
end

---@return WidgetInjector
function CustomMap:createWidgetInjector()
	return CustomInjector()
end

---@param widgets Widget[]
---@return Widget[]
function CustomInjector:addCustomCells(widgets)
	local typeName = Table.size(_args.types) == 1 and 'Type' or 'Types'
	local hasCampData = Array.any(CAMPS, function(campData)
		return _args[campData.key]
	end)
	return Array.extend(
		widgets,
		{
			Cell{name = typeName, content = CustomMap._displayTypes(_args.types)},
			Cell{name = 'Tileset', content = {_args.tileset}},
			Cell{name = 'Size', content = {CustomMap._getSizeDisplay(_args)}},
			Cell{name = 'Spawn Positions', content = {CustomMap._getSpawnDisplay(_args)}},
			Cell{name = 'Versions', content = {_args.versions}},
			Cell{name = 'Rush distance', content = {_args.rushDistance and (_args.rushDistance .. ' seconds') or nil}},
			Cell{name = 'Available Resources', content = {CustomMap._resourcesDisplay(_args)}},
		},
		CustomMap._addCellsFromDataTable(_args, LADDER_HISTORY),
		{hasCampData and Title{name = 'Camp Information'} or nil},
		CustomMap._addCellsFromDataTable(_args, CAMPS)
	)
end

---@param args table
---@param tbl {key: string, name: string}[]
---@return Widget[]
function CustomMap._addCellsFromDataTable(args, tbl)
	return Array.map(tbl, function(data)
		return Cell{name = data.name, content = {args[data.key]}}
	end)
end

---@param args table
---@return string
function CustomMap._resourcesDisplay(args)
	local toValueWithIcon = function(key)
		return args[key] and (RESOURCE_ICONS[key] .. ' ' .. args[key]) or nil
	end

	local theriumAppend = ''
	if args.closedTherium then
		args.therium = args.therium or 0
		theriumAppend = ' (+ ' .. args.closedTherium .. ' closed)'
	end
	local therium = toValueWithIcon('therium')

	return table.concat({toValueWithIcon('luminite'), therium and (therium .. theriumAppend)}, ' ')
end

---@param types string[]
---@return string[]
function CustomMap._displayTypes(types)
	return Array.map(types, function(mapType)
		return MapTypes[mapType]
	end)
end

---@param args table
---@return string?
function CustomMap._getSizeDisplay(args)
	if not args.width or not args.height then return end
	return args.width .. 'x' .. args.height
end

---@param args table
---@return string?
function CustomMap._getSpawnDisplay(args)
	return table.concat({args.players, args.positions}, ' at ')
end

---@param lpdbData table
---@param args table
---@return table
function CustomMap:addToLpdb(lpdbData, args)
	---@param val string?
	---@return string?
	local resolveOrNil = function(val)
		return val and mw.ext.TeamLiquidIntegration.resolve_redirect(val) or nil
	end

	lpdbData.extradata = {
		creator = resolveOrNil(args.creator),
		creator2 = resolveOrNil(args.creator2),
		spawns = args.players,
		spawnpositions = args.positions,
		height = args.height or 0,
		width = args.width or 0,
		rush = args.rushDistance,
		luminite = args.luminite or 0,
		therium = args.therium or 0,
		closedtherium = args.closedTherium or 0,
	}

	Array.forEach(LADDER_HISTORY, function(data)
		lpdbData.extradata[data.key] = tostring(String.isNotEmpty(args[data.key]))
	end)

	Array.forEach(CAMPS, function(data)
		lpdbData.extradata[data.key] = args[data.key]
	end)

	for mapType in pairs(MapTypes) do
		lpdbData.extradata[mapType:lower()] = tostring(Table.includes(args.types, mapType))
	end

	return lpdbData
end

return CustomMap