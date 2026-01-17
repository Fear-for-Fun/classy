--!strict
local Classy = require(script.Parent)

local KillPartClass = {}
KillPartClass.__index = KillPartClass

export type KillPart = typeof(setmetatable({} :: {
    Janitor: Classy.Janitor,
    KillPart: BasePart,
}, KillPartClass))


function KillPartClass.new(Instance, Janitor, Shared): KillPart
    print(Instance, Janitor, Shared)

    return setmetatable({
        KillPart = Instance :: BasePart,
        Janitor = Janitor,
        Shared = Shared
    }, KillPartClass)
end

function KillPartClass.Init(self: KillPart)
    print(self)
end

function KillPartClass.Destroy(self: KillPart)
    print(self)
end

local ClassyObject = Classy.new("KillPart", KillPartClass, {
    ClassNames = { "BasePart" },
    Ancestors = { workspace },
    Shared = {
        Foo = 1,
    },
})

ClassyObject.InstanceAdded:Connect(function(Inst: Instance, Applied)  
    Applied:GetData():Destroy()
end)

return {}