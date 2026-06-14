--!strict
local Internal = script.Parent

local Types = require(Internal.Types)

return {
	constructClass = function<T>(
		Constructable: Types.ClassConstructable<T>,
		Instance: Instance,
		JanitorObject: Types.Janitor,
		Metadata: { [string]: any }?,
		Context: { any }
	): T
		if typeof(Constructable) == "table" and typeof(Constructable.new) == "function" then
			return Constructable.new(Instance, JanitorObject, Context, Metadata)
		end

		error(`[{script.Name}] Invalid Constructable`)
	end,
	
	constructFunction = function<T>(
		Constructable: Types.FunctionConstructable<T>,
		Instance: Instance,
		JanitorObject: Types.Janitor,
		Metadata: { [string]: any }?,
		Context: { any }
	): T
	if typeof(Constructable) == "function" then
		return Constructable(Instance, JanitorObject, Context, Metadata)
	end

	error(`[{script.Name}] Invalid Constructable`)
	end,
}