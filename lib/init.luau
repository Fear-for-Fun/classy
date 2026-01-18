--!strict
local CollectionService = game:GetService("CollectionService")

local Packages = script.Parent

local Janitor = require(Packages.Janitor)
local Signal = require(Packages.Signal)

local Applied = {}
Applied.__index = Applied

local Classy = {}
Classy.__index = Classy

type Validation = "ClassNames" | "Ancestors"

export type Janitor = Janitor.Janitor
export type Signal<T...> = Signal.Signal<T...>

export type Constructable<T> = ((Instance, Janitor) -> T) | {
    new: (Instance, Janitor) -> T,
}

export type ClassyConfig<U> = {
    Predicate: ((Instance) -> boolean)?,
    ClassNames: { string }?,
    Ancestors: { U }?,
}

export type Applied<T, U> = typeof(setmetatable({} :: {
    Classy: Classy<T, U>,
    Instance: Instance,
    Janitor: Janitor,
    Data: T,
}, Applied))

export type Classy<T, U> = typeof(setmetatable({} :: {
    Tag: string,
    Janitor: Janitor,
    ClassNames: { string },
    Ancestors: { U },
    Constructable: Constructable<T>,
    Predicate: ((Instance) -> boolean)?,
    Applied: { [Instance]: Applied<T, U> },
    InstanceAdded: Signal<Instance, Applied<T, U>>,
    InstanceRevoked: Signal<Instance>,
}, Classy))

local function validate(Instance: Instance, List: { string | Instance }, Fn: string): boolean
    if not next(List) then
        return true
    end

    for _, v in List do
        if (Instance::any)[Fn](Instance, v) then
            return true
        end
    end
    
    return false
end

local function safeCall<T>(Data: T, Fn: string, ...: any): ...any
    if typeof(Data) == "table" and typeof(Data[Fn]) == "function" then
        return (Data::any)[Fn](...)
    end

    return 
end

local function safeDestroy<T>(Data: T)
    if typeof(Data) == "table" then
        table.clear(Data::any)
        setmetatable(Data::any, nil)
    end
end

local function construct<T>(Constructable: Constructable<T>, Instance: Instance, JanitorObject: Janitor): T
    if typeof(Constructable) == "function" then
        return Constructable(Instance, JanitorObject)
    end

    if typeof(Constructable) == "table" and typeof(Constructable.new) == "function" then
        return Constructable.new(Instance, JanitorObject)
    end

    error(`[{script.Name}] Invalid Constructable`)
end

function Applied.new<T, U>(Instance: Instance, ClassyObject: Classy<T, U>): Applied<T, U>
    local AppliedJanitor = Janitor.new()
    ClassyObject.Janitor:Add(AppliedJanitor)

    local Data: T = construct(ClassyObject.Constructable, Instance, AppliedJanitor)
    safeCall(Data, "Init", Data)

    return setmetatable({
        Janitor = AppliedJanitor,
        Classy = ClassyObject,
        Instance = Instance,
        Data = Data,
    }, Applied)
end

function Applied.GetData<T, U>(self: Applied<T, U>)
    return self.Data
end

function Applied.Destroy<T, U>(self: Applied<T, U>)
    self.Janitor:Destroy()

    safeCall(self.Data, "Destroy", self.Data)
    safeDestroy(self.Data)

    table.clear(self::any)
    setmetatable(self::any, nil)
end

function Classy.new<T, U>(Tag: string, Constructable: Constructable<T>, ClassyConfig: ClassyConfig<U>?): Classy<T, U>
    local Config: ClassyConfig<U> = ClassyConfig or {} :: any

    return setmetatable({
        Tag = Tag,
        Constructable = Constructable,

        ClassNames = table.freeze(Config.ClassNames or {}),
        Ancestors = table.freeze(Config.Ancestors or {}),
        Predicate = Config.Predicate,

        Applied = {},
        Janitor = Janitor.new(),

        InstanceAdded = Signal.new(),
        InstanceRevoked = Signal.new(),
    }, Classy)
end

function Classy.Init<T, U>(self: Classy<T, U>)
    for _, Instance in CollectionService:GetTagged(self.Tag) do
        if self:CanBeApplied(Instance) then
            self:Apply(Instance)
        end
    end

    self.Janitor:Add(CollectionService:GetInstanceAddedSignal(self.Tag):Connect(function(Instance: Instance)  
        if self:CanBeApplied(Instance) then
            self:Apply(Instance)
        end
    end))

    self.Janitor:Add(CollectionService:GetInstanceRemovedSignal(self.Tag):Connect(function(Instance: Instance)  
        self:Revoke(Instance)
    end))
end

function Classy.CanBeApplied<T, U>(self: Classy<T, U>, Instance: Instance): boolean
    if not validate(Instance, self.ClassNames, "IsA") then
        return false
    end

    if not validate(Instance, (self.Ancestors :: any) :: { Instance }, "IsDescendantOf") then
        return false
    end

    if self.Predicate and not self.Predicate(Instance) then
        return false
    end

    return true
end

function Classy.GetApplied<T, U>(self: Classy<T, U>, Instance: Instance): Applied<T, U>?
    return self.Applied[Instance]
end

function Classy.GetAll<T, U>(self: Classy<T, U>): { [Instance]: Applied<T, U> }
    return self.Applied
end

function Classy.Apply<T, U>(self: Classy<T, U>, Instance: Instance): Applied<T, U>
    local Existing = self:GetApplied(Instance)
    if Existing then return Existing end

    local AppliedObject = Applied.new(Instance, self)
    self.Applied[Instance] = AppliedObject

    local Connection: RBXScriptConnection
    Connection = Instance.AncestryChanged:Connect(function()
        if not self:CanBeApplied(Instance) then
            self:Revoke(Instance)
            Connection:Disconnect()
        end
    end)

    self.InstanceAdded:Fire(Instance, AppliedObject)
    return AppliedObject
end

function Classy.Revoke<T, U>(self: Classy<T, U>, Instance: Instance)
    local AppliedObject = self:GetApplied(Instance)
    if not AppliedObject then return end

    AppliedObject:Destroy()
    self.Applied[Instance] = nil
    
    Instance:RemoveTag(self.Tag)
    self.InstanceRevoked:Fire(Instance)
end

function Classy.Destroy<T, U>(self: Classy<T, U>)
    for Instance in self.Applied do
        self:Revoke(Instance)
    end

    self.Janitor:Destroy()

    table.clear(self::any)
    setmetatable(self::any, nil)
end

return {
    new = function<T, U>(Tag: string, Constructable: Constructable<T>, Config: ClassyConfig<U>?): Classy<T, U>
        local ClassyObject = Classy.new(Tag, Constructable, Config)
        ClassyObject:Init()

        return ClassyObject
    end,
}