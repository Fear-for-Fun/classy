# Classy
Classy library. Class is a tag-driven lifecycle manager that makes a composition approach much easier in luau!

## Why Use Classy?
- You have the option of tracking instances with classes or functions.
- Classy handles the cleanup of a class object's metatable and the provided [Janitor](https://github.com/howmanysmall/Janitor) object.
- Full generic type safety is preserved when accessing applied objects.
- If you are a fanatic about object-oriented programming, this is the module for you! Simply create classes for game objects and track them with tags.

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

-- every time a part with the "KillPart" tag is added, this runs.
function KillPartClass.new(Part: Instance, JanitorObject: Classy.Janitor): KillPart
    return setmetatable({
        Part = Part :: BasePart,
        Janitor = JanitorObject,
    }, KillPartClass)
end

function KillPartClass.Init(self: KillPart) -- automatically runs!
    self:WatchTouchedEvent()
end

function KillPartClass.DoSomething(self: KillPart)
    print(self)
end

function KillPartClass.WatchTouchedEvent(self: KillPart)
    self.Janitor:Add(self.Part.Touched:Connect(function(Hit: BasePart)
        local Humanoid = Hit.Parent and Hit.Parent:FindFirstChildWhichIsA("Humanoid")
        if not Humanoid then return end

        Humanoid.Health = 0
    end))
end

function KillPartClass.Destroy(self: KillPart)
    print("This object has been destroyed!") -- the Janitor and metatable are cleaned externally, no need to do it here.
end

-- Usage
local KillPartClassy = Classy.new("KillPart", KillPartClass, {
    ClassNames = { "BasePart" },
    Ancestors = { workspace },
})

KillPartClassy.InstanceAdded:Connect(function(Instance: Instance, Applied)
    Applied:GetData():DoSomething()
end)
```
