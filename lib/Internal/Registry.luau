--!strict
return {
	GlobalRegistry = {} :: { [string]: any },
	AliasRegistry = {} :: { [string]: { [string]: any } },

	InstanceRegistry = (setmetatable({}, {
		__mode = "k",
	}) :: any) :: { [Instance]: { [string]: any? } }
}