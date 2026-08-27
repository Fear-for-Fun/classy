![alt text](Classy.png)

# Classy
Classy library. Classy is a lifecycle manager that builds on tags to make both composition and OOP architecture more appealing in Luau.

## Why Use Classy?
- You have the option of tracking instances with classes or functions.
- Classy handles the cleanup of a class object's metatable and the provided [Janitor](https://github.com/howmanysmall/Janitor) object.
- Full generic type safety is preserved when accessing applied objects.
- If you are a fanatic about object-oriented programming, this is the module for you! Simply create classes for game objects and track them with tags.
- Classy also heavily supports composition, allowing you to register and fetch attached components (ClassyObjects) from an instance.

## Installation
Classy is installable via [wally](https://wally.run/), and you can visit the page [here](https://wally.run/package/jaeymo/classy?version=1.0.1).

## Dependencies
- [Janitor](https://github.com/howmanysmall/Janitor)
- [Signal](https://github.com/Sleitnick/RbxUtil/blob/main/modules/signal/init.luau)
  
## Example Usage
```lua
--!strict
local Classy = require(path.to.classy)

-- Example class
local KillPartClass = {}
KillPartClass.__index = KillPartClass

export type KillPart = typeof(setmetatable({} :: {
	Part: BasePart,	
	Janitor: Classy.Janitor,
}, KillPartClass))

-- Every time a part with the "KillPart" tag is added, this runs.
function KillPartClass.new(part: Instance, janitor: Classy.Janitor): KillPart
	return setmetatable({
		Part = part :: BasePart,
		Janitor = janitor,
	}, KillPartClass)
end

function KillPartClass.Init(self: KillPart) -- Automatically runs!
	self:_watchTouchedEvent()
end

function KillPartClass.DoSomething(self: KillPart)
	print(self)
end

function KillPartClass.Destroy(self: KillPart)
	print("This object has been destroyed!") -- The Janitor and metatable are cleaned externally, no need to do it here.
end

function KillPartClass._watchTouchedEvent(self: KillPart)
	self.Janitor:Add(self.Part.Touched:Connect(function(Hit: BasePart)
		local Humanoid = Hit.Parent and Hit.Parent:FindFirstChildWhichIsA("Humanoid")
		if not Humanoid then 
			return 
		end

		Humanoid.Health = 0
	end))
end

-- Usage
local KillPartClassy = Classy.newClass("KillPart", KillPartClass, {
	ClassNames = { "BasePart" },
	Ancestors = { workspace },
	Logging = true
})

-- Another usage example that does the same thing as the first
local AnotherExample = Classy.new("KillPart", function(instance: Instance, janitor: Classy.Janitor, _, _)
	return KillPartClass.new(instance, janitor)
end, {
	ClassNames = { "BasePart" },
	Ancestors = { workspace },
	Logging = true
})

-- Starts the Classy!
KillPartClassy:Init()
AnotherExample:Init()

-- How to use the ClassyObject
KillPartClassy.InstanceAdded:Connect(function(Instance, Applied)
	Applied:GetData():DoSomething()
end)
```