--!strict
local Packages = script.Parent.Parent.Parent

local Janitor = require(Packages.Janitor)
local Signal = require(Packages.Signal)

export type Signal<T...> = Signal.Signal<T...>

export type Connection = Signal.Connection

export type Janitor = Janitor.Janitor

export type ConstructorKind = "Class" | "Function"

export type ClassConstructable<T> = {
	new: (
		Instance,
		Janitor,
		{any},
		{[string]: any}?
	) -> T,
}

export type FunctionConstructable<T> =
	(
		Instance,
		Janitor,
		{any},
		{[string]: any}?
	) -> T

export type ClassyConfig = {
	Predicate: ((Instance) -> boolean)?,
	ClassNames: { string }?,
	NamingConvention: {
		Init: string?,
		Destroy: string?,
	}?,
	AutoInit: boolean?,
	Nuke: boolean?,
	Context: any?,
	RemoveTagOnCleanup: boolean?,
	Logging: boolean?,
	Ancestors: { Instance }?,
	WaitForMetadata: boolean?,
}

return 0