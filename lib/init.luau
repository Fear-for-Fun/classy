--!strict

--[[
	Classy: A Classy is useful because writing code for instances becomes much better!
	Author: Jaeymo
	Version: 1.7.7
	License: MIT
	Created: 01/18/2026

	For issues or feedback message `jaeymo` on Discord!
]]

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local Packages = script.Parent

local Janitor = require(Packages.Janitor)
local Signal = require(Packages.Signal)

local METADATA_TIMEOUT = 7

--[=[
	@class Applied
	The Applied class is what Classy manages and attaches instances to
]=]
local Applied = {}
Applied.__index = Applied

--[=[
	@class Classy
	A Classy is useful for instantiating and managing instances of
	based on tags
]=]
local Classy = {}
Classy.__index = Classy

export type Janitor = Janitor.Janitor
export type Connection = Signal.Connection
export type Signal<T...> = Signal.Signal<T...>

export type Constructable<T> = ((Instance, Janitor, { any }, { [string]: any }?) -> T) | {
	new: (Instance, Janitor, { any }, { [string]: any }?) -> T,
}

export type ClassyConfig<U> = {
	Predicate: ((Instance) -> boolean)?,
	ClassNames: { string }?,
	NamingConvention: {
		Init: string?,
		Destroy: string?,
	}?,
	Context: any?,
	RemoveTagOnCleanup: boolean?,
	Logging: boolean?,
	Ancestors: { U }?,
	WaitForMetadata: boolean?,
}

export type Applied<T, U> = typeof(setmetatable(
	{} :: {
		Classy: Classy<T, U>,
		Instance: Instance,
		Janitor: Janitor,
		Data: T,
		Triggers: { [string]: string }?,
	},
	Applied
	))

export type Classy<T, U> = typeof(setmetatable(
	{} :: {
		Tag: string,
		Janitor: Janitor,
		Logging: boolean,
		Ancestors: { U },
		ClassNames: { string },
		NamingConvention: {
			Init: string,
			Destroy: string,
		},
		WaitForMetadata: boolean,
		Context: { any },
		RemoveTagOnCleanup: boolean,
		Constructable: Constructable<T>,
		Predicate: ((Instance) -> boolean)?,
		Applied: { [Instance]: Applied<T, U> },
		InstanceAdded: Signal<Instance, Applied<T, U>>,
		InstanceRevoked: Signal<Instance>,
	},
	Classy
	))

local GlobalRegistry = {} :: { [string]: any }
local AliasRegistry = {} :: { [string]: { [string]: any } }

local InstanceRegistry = (setmetatable({}, {
	__mode = "k",
}) :: any) :: { [Instance]: { [string]: Applied<any, any> } }

--[=[
    @private
    Creates/reuses a Classy alias that points to a base component.
]=]
local function resolveClassyForTag(Tag: string, Metadata: { [string]: any }?): any
	local BaseTag = Metadata and (Metadata.useComponent or Metadata.UseComponent)
	if not BaseTag then
		return GlobalRegistry[Tag]
	end

	if typeof(BaseTag) ~= "string" then
		warn(`[Classy] Invalid useComponent for tag {Tag}`)
		return GlobalRegistry[Tag]
	end

	if BaseTag == Tag then
		return GlobalRegistry[Tag]
	end

	AliasRegistry[BaseTag] = AliasRegistry[BaseTag] or {}

	local ExistingAlias = AliasRegistry[BaseTag][Tag]
	if ExistingAlias then
		return ExistingAlias
	end

	local BaseClassy = GlobalRegistry[BaseTag]
	if not BaseClassy then
		warn(`[Classy] Missing base component: {BaseTag} (requested by {Tag})`)
		return nil
	end

    local AliasContext = {}
    AliasContext = table.clone(BaseClassy.Context)
    AliasContext.tag = Tag


	local AliasClassy = Classy.new(Tag, BaseClassy.Constructable, {
		Predicate = BaseClassy.Predicate,
		ClassNames = BaseClassy.ClassNames,
		NamingConvention = {
			Init = BaseClassy.NamingConvention.Init,
			Destroy = BaseClassy.NamingConvention.Destroy,
		},
		Context = AliasContext,
		RemoveTagOnCleanup = BaseClassy.RemoveTagOnCleanup,
		Logging = BaseClassy.Logging,
		Ancestors = BaseClassy.Ancestors,
		WaitForMetadata = BaseClassy.WaitForMetadata,
	} :: any)
	AliasClassy:Init()

	AliasRegistry[BaseTag][Tag] = AliasClassy
	GlobalRegistry[Tag] = AliasClassy

	return AliasClassy
end

--[=[
	@private
]=]
local function validate(Instance: Instance, List: { string | Instance }, Fn: string): boolean
	if not next(List) then
		return true
	end

	for _, v in List do
		if (Instance :: any)[Fn](Instance, v) then
			return true
		end
	end

	return false
end

--[=[
	@private
]=]
local function safeCall<T>(Data: T, Fn: string, ...: any): ...any
	if typeof(Data) == "table" and typeof((Data :: any)[Fn]) == "function" then
		return (Data :: any)[Fn](...)
	end

	return
end

--[=[
	@private
]=]
local function safeDestroy<T>(Data: T)
	if typeof(Data) == "table" then
		table.clear(Data :: any)
		setmetatable(Data :: any, nil)
	end
end

--[=[
	@private
]=]
local function construct<T>(
	Constructable: Constructable<T>,
	Instance: Instance,
	JanitorObject: Janitor,
	Metadata: { [string]: any }?,
	Context: { any }
): T
	if typeof(Constructable) == "function" then
		return Constructable(Instance, JanitorObject, Context, Metadata)
	end

	if typeof(Constructable) == "table" and typeof(Constructable.new) == "function" then
		return Constructable.new(Instance, JanitorObject, Context, Metadata)
	end

	error(`[{script.Name}] Invalid Constructable`)
end

--[=[
	@private
]=]
local function emitInternal(Instance: Instance, TriggerName: string, Context: any?)
	local Registry = InstanceRegistry[Instance]
	if not Registry then
		return
	end

	for _, AppliedValue in Registry do
		local Triggers = AppliedValue.Triggers
		if not Triggers then
			continue
		end

		local MethodName = Triggers[TriggerName]
		if not MethodName then
			continue
		end

		local Data = (AppliedValue :: any):GetData()
		local Method = Data and (Data :: any)[MethodName]

		if typeof(Method) == "function" then
			(Method :: any)(Data, Context)
		end
	end
end

--[=[
	@private
	Waits for metadata on an instance if WaitForMetadata is enabled.
	Returns decoded metadata or nil if timeout.
]=]
local function waitForMetadata(Instance: Instance, Tag: string): { [string]: any }?
	local ATTRIBUTE = `__{string.lower(Tag)}.._metadata`

	if not Instance:GetAttribute(ATTRIBUTE) then
		local Changed = Instance:GetAttributeChangedSignal(ATTRIBUTE)
		local StartTime = os.clock()

		while os.clock() - StartTime < METADATA_TIMEOUT do
			Changed:Wait()
			if Instance:GetAttribute(ATTRIBUTE) then
				break
			end
		end
	end

	local Raw = Instance:GetAttribute(ATTRIBUTE)
	if Raw then
		return HttpService:JSONDecode(Raw :: any)
	end

	return nil
end

--[=[
	Instantiates a new Applied object.
    @param Instance Instance
    @param ClassyObject Classy<T, U>
    @param ... any?
	@return Applied<T, U>
]=]
function Applied.new<T, U>(Instance: Instance, ClassyObject: Classy<T, U>, Metadata: { [string]: any }?): Applied<T, U>
	local AppliedJanitor = Janitor.new()
	ClassyObject.Janitor:Add(AppliedJanitor)

	local Data: T = construct(ClassyObject.Constructable, Instance, AppliedJanitor, Metadata, ClassyObject.Context)

	safeCall(Data, ClassyObject.NamingConvention.Init, Data)

	return setmetatable({
		Janitor = AppliedJanitor,
		Classy = ClassyObject,
		Instance = Instance,
		Data = Data,
		Triggers = Metadata and (Metadata.triggers or Metadata.Triggers),
	}, Applied)
end

--[=[
	@return T
	Returns the T of an Applied object, either referring to a custom
    return from a function constructable or a object from a class
]=]
function Applied.GetData<T, U>(self: Applied<T, U>): T
	return self.Data
end

--[=[
	Destroys the Janitor and the attached data of an Applied object

	:::warning Metatable Removal
	Running this will make any further attempts to call a method of Applied
	error
	:::
]=]
function Applied.Destroy<T, U>(self: Applied<T, U>)
	self.Janitor:Destroy()

	safeCall(self.Data, self.Classy.NamingConvention.Destroy, self.Data)
	safeDestroy(self.Data)

	table.clear(self :: any)
	setmetatable(self :: any, nil)
end

--[=[
	When an instance gets an object applied into Classy
	@prop InstanceAdded Signal<Instance, Applied<T, U>>
	@within Classy
]=]
--[=[
	When an instance gets an object revoked from Classy
	@prop InstanceRevoked Signal<Instance>
	@within Classy
]=]

--[=[
	Instantiates a new Classy object
    @param Tag string
    @param Constructable Constructable<T>
    @param ClassyConfig ClassyConfig<U>
	@return Classy<T, U>
]=]
function Classy.new<T, U>(Tag: string, Constructable: Constructable<T>, ClassyConfig: ClassyConfig<U>?): Classy<T, U>
	local Config: ClassyConfig<U> = ClassyConfig or {} :: any

	return setmetatable({
		Tag = Tag,
		Constructable = Constructable,

		ClassNames = Config.ClassNames or {},
		Ancestors = Config.Ancestors or {},
		Logging = Config.Logging or false,
		Predicate = Config.Predicate,
		RemoveTagOnCleanup = if Config.RemoveTagOnCleanup ~= nil then Config.RemoveTagOnCleanup else true,

		NamingConvention = {
			Init = Config.NamingConvention and Config.NamingConvention.Init or "Init",
			Destroy = Config.NamingConvention and Config.NamingConvention.Destroy or "Destroy",
		},

		WaitForMetadata = Config.WaitForMetadata or false,
		Context = Config.Context or {},

		Applied = {},
		Janitor = Janitor.new(),

		InstanceAdded = Signal.new(),
		InstanceRevoked = Signal.new(),
	}, Classy)
end

--[=[
	Initializes a Classy object
]=]
function Classy.Init<T, U>(self: Classy<T, U>)
	for _, Instance in CollectionService:GetTagged(self.Tag) do
		if self:CanBeApplied(Instance) then
			local Metadata = self.WaitForMetadata and waitForMetadata(Instance, self.Tag) or nil
			self:Apply(Instance, Metadata)
		end
	end

	self.Janitor:Add(CollectionService:GetInstanceAddedSignal(self.Tag):Connect(function(Instance: Instance)
		if self:CanBeApplied(Instance) then
			local Metadata = self.WaitForMetadata and waitForMetadata(Instance, self.Tag) or nil
			self:Apply(Instance, Metadata)
		end
	end))

	self.Janitor:Add(CollectionService:GetInstanceRemovedSignal(self.Tag):Connect(function(Instance: Instance)
		self:Revoke(Instance)
	end))
end

--[=[
	Returns if an Instance passes all of the checks to be applied
    @param Instance Instance
    @return boolean
]=]
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

--[=[
	Returns if an Instance passes all of the checks to be applied
    @param Instance Instance
    @return boolean
]=]
function Classy.GetApplied<T, U>(self: Classy<T, U>, Instance: Instance): Applied<T, U>?
	return self.Applied[Instance]
end

--[=[
	Returns all applied instances
    @return { [Instance]: Applied<T, U> }
]=]
function Classy.GetAll<T, U>(self: Classy<T, U>): { [Instance]: Applied<T, U> }
	return self.Applied
end

--[=[
	Bypasses the `CanBeApplied` check and applies an instance
    
    ```lua
    local AppliedObject = ClassyObject:Apply(SomeInstance)
    AppliedObject:GetData():DoSomething()
    ```

    @param Instance Instance
    @param Metadata: {[string]: any}?
    @return Applied<T, U>
]=]
function Classy.Apply<T, U>(self: Classy<T, U>, Instance: Instance, Metadata: { [string]: any }?): Applied<T, U>
	if self.WaitForMetadata and not Metadata then
		Metadata = waitForMetadata(Instance, self.Tag)
	end

	if Metadata then
		Instance:SetAttribute(`_{string.lower(self.Tag)}_metadata`, HttpService:JSONEncode(Metadata))
	end

	local Existing = self:GetApplied(Instance)
	if Existing then
		return Existing
	end

	if self.Logging then
		print(`[Classy] Applied instance: {Instance:GetFullName()}`)
	end

	local AppliedObject = Applied.new(Instance, self, Metadata)
	self.Applied[Instance] = AppliedObject

	InstanceRegistry[Instance] = InstanceRegistry[Instance] or {}
	InstanceRegistry[Instance][self.Tag] = AppliedObject

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

--[=[
	Revokes an Instance from Classy
    
    :::info Note
	This will nullify the object's metatable, so you will not be able to use it's
	object after revoking it from Classy
	:::

    ```lua
    if ClassyObject:GetApplied(SomeInstance) then
        ClassyObject:Revoke(SomeInstance)
    end
    ```

    @param Instance Instance
]=]
function Classy.Revoke<T, U>(self: Classy<T, U>, Instance: Instance)
	local AppliedObject = self:GetApplied(Instance)
	if not AppliedObject then
		return
	end

	local Registry = InstanceRegistry[Instance]
	if Registry then
		Registry[self.Tag] = nil
		if not next(Registry) then
			InstanceRegistry[Instance] = nil
		end
	end

	if self.Logging then
		print(`[Classy] Revoked instance: {Instance:GetFullName()}`)
	end

	AppliedObject:Destroy()
	self.Applied[Instance] = nil

	if self.RemoveTagOnCleanup then
		Instance:RemoveTag(self.Tag)
	end

	self.InstanceRevoked:Fire(Instance)
end

--[=[
	Runs a callback for all applied objects and hooks into the `InstanceAdded` signal

    ```lua
    local Connection = ClassyObject:ObserveApplied(function(Instance, Applied)
        Applied:GetData():DoSomething()
    end)

    Connection:Disconnect()
    ```

    @param Callback (Instance: Instance, Applied: Applied<T, U>)
    @return Connection Connection
]=]
function Classy.ObserveApplied<T, U>(
	self: Classy<T, U>,
	Callback: (Instance: Instance, Applied: Applied<T, U>) -> ()
): Connection
	for Inst, AppliedObject in self:GetAll() do
		task.spawn(function()
			Callback(Inst, AppliedObject :: Applied<T, U>)
		end)
	end

	return self.InstanceAdded:Connect(Callback)
end

--[=[
	Destroys all tracked objects, cleans the Janitor and destroys signals, rendering
    this object unusable.

	:::warning Metatable Removal
	Running this will make any further attempts to call a method of Classy
	error.
	:::

	```lua
	ClassyObject:Destroy()
	```
]=]
function Classy.Destroy<T, U>(self: Classy<T, U>)
	for Instance in self.Applied do
		self:Revoke(Instance)
	end

	if self.Logging then
		print(`[Classy] Cleaned classy for: {self.Tag}`)
	end

	self.Janitor:Destroy()

	table.clear(self :: any)
	setmetatable(self :: any, nil)
end

return {
	version = "1.7.7",

	new = function<T, U>(Tag: string, Constructable: Constructable<T>, Config: ClassyConfig<U>?): Classy<T, U>
		return Classy.new(Tag, Constructable, Config)
	end,

	create = function<T, U>(Tag: string, Constructable: Constructable<T>, Config: ClassyConfig<U>?): Classy<T, U>
		local ClassyObject = Classy.new(Tag, Constructable, Config)
		ClassyObject:Init()

		return ClassyObject
	end,

	registerGlobal = function(Tag: string, ClassyInstance: any)
		GlobalRegistry[Tag] = ClassyInstance
	end,

	getGloballyRegistered = function(Tag: string): Classy<any, any>?
		return GlobalRegistry[Tag]
	end,

	getComponent = function(Inst: Instance, Tag: string): Applied<any, any>?
		return InstanceRegistry[Inst] and InstanceRegistry[Inst][Tag]
	end,

	getComponents = function(Inst: Instance): { [string]: Applied<any, any> }?
		return InstanceRegistry[Inst]
	end,

	callOnAllComponents = function(Inst: Instance, MethodName: string, ...: any): ()
		local Registry = InstanceRegistry[Inst]
		if not Registry then
			return
		end

		for _, AppliedValue in Registry do
			local Data = (AppliedValue :: any):GetData()
			local Method = Data and Data[MethodName]

			if typeof(Method) == "function" then
				Method(Data, ...)
			end
		end
	end,

	applyComponents = function(Inst: Instance, Components: { [string]: { [string]: any } })
		for Tag, Metadata in Components do
			local ClassyInstance = resolveClassyForTag(Tag, Metadata)
			if not ClassyInstance then
				continue
			end

			Inst:AddTag(Tag)
			ClassyInstance:Apply(Inst, Metadata)
		end
	end,

	emit = emitInternal,
}
