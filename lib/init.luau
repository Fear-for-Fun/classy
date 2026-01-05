--!strict
local Packages = script.Parent

local Janitor = require(Packages.Janitor)
local Signal = require(Packages.Signal)

local PREFIX = "WRAPPER"

local Classy = {}
Classy.__index = Classy

export type Properties = {
    Predicate: ((Instance) -> boolean)?,
    Ancestor: Instance?,
    Tag: string?,
}

export type Classy<T> = typeof(setmetatable({} :: {
    Class: T,
    Instance: Instance,
    Properties: Properties,

    Tracked: { [Instance]: {
        Janitor: Janitor.Janitor,
        Object: T,
    }},

    OnApplied: Signal.Signal<Instance, T>,
    OnRevoked: Signal.Signal<Instance, T>,
}, Classy))

local function isInstanceTypeof(Instance: Instance): boolean
    return typeof(Instance) == "Instance"
end

local function verifyAncestor(Descendant: Instance, Ancestor: Instance): boolean
    return Descendant:IsDescendantOf(Ancestor)
end

local function verifyTag(Instance: Instance, Tag: string): boolean
    return Instance:HasTag(Tag)
end

function Classy.new<T>(Instance: Instance, Class: T, Properties: Properties): Classy<T>
    if not isInstanceTypeof(Instance) then
        error(`[{PREFIX}] Expected typeof "Instance", got: {typeof(Instance)}`)
    end

    local self = setmetatable({}, Classy)
    self.Properties = Properties 
    self.Instance = Instance
    self.Class = Class

    self.Tracked = {}

    self.OnApplied = Signal.new()
    self.OnRevoked = Signal.new()

    return self
end

function Classy.Apply<T>(self: Classy<T>, Instance: Instance)
    local Properties = self.Properties

    if Properties.Ancestor and not verifyAncestor(Instance, Properties.Ancestor) then return end
    if Properties.Predicate and not Properties.Predicate(Instance) then return end
    if Properties.Tag and not verifyTag(Instance, Properties.Tag) then return end

    local JanitorObject = Janitor.new()
    self.Tracked[Instance] = JanitorObject
end

function Classy.Revoke<T>(self: Classy<T>, Instance: Instance)
    
end

function Classy.Destroy<T>(self: Classy<T>)
    table.clear(self::any)
    setmetatable(self::any, nil)
end

return Classy