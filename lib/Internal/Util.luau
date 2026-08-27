--!strict
local HttpService = game:GetService("HttpService")

local Util = {}

function Util.Validate<T>(Inst: Instance, List: {T}, Fn: string): boolean
	if not next(List) then
		return true
	end

	for _, v in List do
		if (Inst :: any)[Fn](Inst, v) then
			return true
		end
	end

	return false
end

function Util.SafeCall<T>(Data: T, Fn: string, ...: any): ...any
	if typeof(Data) == "table" and typeof((Data :: any)[Fn]) == "function" then
		return (Data :: any)[Fn](...)
	end

	return
end

function Util.SafeDestroy<T>(Data: T)
	if typeof(Data) == "table" then
		table.clear(Data :: any)
		setmetatable(Data :: any, nil)
	end
end

function Util.WaitForMetadata(Inst: Instance, Tag: string, Timeout: number)
	local ATTRIBUTE = `__{string.lower(Tag)}.._metadata`

	if not Inst:GetAttribute(ATTRIBUTE) then
		local Changed = Inst:GetAttributeChangedSignal(ATTRIBUTE)
		local StartTime = os.clock()

		while os.clock() - StartTime < Timeout do
			Changed:Wait()
			if Inst:GetAttribute(ATTRIBUTE) then
				break
			end
		end
	end

	local Raw = Inst:GetAttribute(ATTRIBUTE)
	if Raw then
		return HttpService:JSONDecode(Raw :: any)
	end

	return nil
end

return Util