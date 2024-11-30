-- a25 was here

local LOG_FILE_PATH                       = "File.log"
local OUT_FILE_PATH                       = "dump.cs"
local CONSTANT_DUMP_ASSEMBLIES            = {
	["RPG.Network.Proto"] = true,
	["Assembly-CSharp"] = true,
	["Google.Protobuf"] = true,
	["MiHoYo.SDK.Protobuf"] = true,
	["RPG.GameCore.Config"] = true
}

-- Constants
local FLAGS = CS.System.Reflection.BindingFlags.Instance |
		      CS.System.Reflection.BindingFlags.Static |
			  CS.System.Reflection.BindingFlags.Public |
		      CS.System.Reflection.BindingFlags.NonPublic

local FIELD_ATTRIBUTE_FIELD_ACCESS_MASK   = 0x0007
local FIELD_ATTRIBUTE_PRIVATE             = 0x0001
local FIELD_ATTRIBUTE_FAM_AND_ASSEM       = 0x0002
local FIELD_ATTRIBUTE_ASSEMBLY            = 0x0003
local FIELD_ATTRIBUTE_FAMILY              = 0x0004
local FIELD_ATTRIBUTE_FAM_OR_ASSEM        = 0x0005
local FIELD_ATTRIBUTE_PUBLIC              = 0x0006
local FIELD_ATTRIBUTE_STATIC              = 0x0010
local FIELD_ATTRIBUTE_INIT_ONLY           = 0x0020
local FIELD_ATTRIBUTE_LITERAL             = 0x0040
local METHOD_ATTRIBUTE_MEMBER_ACCESS_MASK = 0x0007
local METHOD_ATTRIBUTE_PRIVATE            = 0x0001
local METHOD_ATTRIBUTE_FAM_AND_ASSEM      = 0x0002
local METHOD_ATTRIBUTE_ASSEM              = 0x0003
local METHOD_ATTRIBUTE_FAMILY             = 0x0004
local METHOD_ATTRIBUTE_FAM_OR_ASSEM       = 0x0005
local METHOD_ATTRIBUTE_PUBLIC             = 0x0006
local METHOD_ATTRIBUTE_STATIC             = 0x0010
local METHOD_ATTRIBUTE_FINAL              = 0x0020
local METHOD_ATTRIBUTE_VIRTUAL            = 0x0040
local METHOD_ATTRIBUTE_VTABLE_LAYOUT_MASK = 0x0100
local METHOD_ATTRIBUTE_REUSE_SLOT         = 0x0000
local METHOD_ATTRIBUTE_NEW_SLOT           = 0x0100
local METHOD_ATTRIBUTE_ABSTRACT           = 0x0400
local METHOD_ATTRIBUTE_PINVOKE_IMPL       = 0x2000
local TYPE_ATTRIBUTE_VISIBILITY_MASK      = 0x00000007
local TYPE_ATTRIBUTE_NOT_PUBLIC           = 0x00000000
local TYPE_ATTRIBUTE_PUBLIC               = 0x00000001
local TYPE_ATTRIBUTE_NESTED_PUBLIC        = 0x00000002
local TYPE_ATTRIBUTE_NESTED_PRIVATE       = 0x00000003
local TYPE_ATTRIBUTE_NESTED_FAMILY        = 0x00000004
local TYPE_ATTRIBUTE_NESTED_ASSEMBLY      = 0x00000005
local TYPE_ATTRIBUTE_NESTED_FAM_AND_ASSEM = 0x00000006
local TYPE_ATTRIBUTE_NESTED_FAM_OR_ASSEM  = 0x00000007
local TYPE_ATTRIBUTE_INTERFACE            = 0x00000020
local TYPE_ATTRIBUTE_ABSTRACT             = 0x00000080
local TYPE_ATTRIBUTE_SEALED               = 0x00000100

local SYSTEM_NAMES = {
	["System.Int32"] = "int",
	["Int32"] = "int",
	["System.UInt32"] = "uint",
	["UInt32"] = "uint",
	["System.Int16"] = "short",
	["Int16"] = "short",
	["System.UInt16"] = "ushort",
	["UInt16"] = "ushort",
	["System.Int64"] = "long",
	["Int64"] = "long",
	["System.UInt64"] = "ulong",
	["UInt64"] = "ulong",
	["System.Byte"] = "byte",
	["Byte"] = "byte",
	["System.SByte"] = "sbyte",
	["SByte"] = "sbyte",
	["System.Boolean"] = "bool",
	["Boolean"] = "bool",
	["System.Single"] = "float",
	["Single"] = "float",
	["System.Double"] = "double",
	["Double"] = "double",
	["System.String"] = "string",
	["String"] = "string",
	["System.Char"] = "char",
	["Char"] = "char",
	["System.Object"] = "object",
	["Object"] = "object",
	["System.Void"] = "void",
	["Void"] = "void",
}

-- Logger Section
local LOG_FILE = CS.System.IO.StreamWriter(LOG_FILE_PATH)
local function WriteError(content)
	LOG_FILE:Write(content)
end

-- Output Section
local OUT_FILE = CS.System.IO.StreamWriter(OUT_FILE_PATH)
local function WriteOutput(content, indent, with_newline)
	if content == nil then
		content = ""
	end
	if indent == nil then
		indent = ""
	end
	if with_newline == true or with_newline == nil then
		OUT_FILE:Write(indent .. content .. "\n")
	else
		OUT_FILE:Write(indent .. content)
	end
end

-- Included with newline and tab by deault
local function GetCustomAttributes(Instance, WithTab)
	if WithTab == nil then
		WithTab = true
	end
	local Attributes = Instance:GetCustomAttributes(true)
	local ret = ""
	for i = 0, Attributes.Length - 1 do
		local Type = Attributes[i]:GetType()
		local inner = ""
		if Attributes[i].Name ~= nil then
			inner = string.format("(Name = \"%s\")", Attributes[i].Name)
		end
		local tab = ""
		if WithTab then
			tab = "\t"
		end
		ret = ret .. string.format("%s[%s%s]\n", tab, Type.Name, inner)
	end
	return ret
end

local function GetReflectedType(Type)
	local name = Type.Name
	if Type.ReflectedType ~= nil and not Type.ReflectedType.IsGenericType then
		name = GetReflectedType(Type.ReflectedType) .. "." .. name
	end
	if SYSTEM_NAMES[name] ~= nil then
		return SYSTEM_NAMES[name]
	end
	return name
end

local function GetTypeName(Type, alias)
	if Type.IsArray then
		local out = GetTypeName(Type:GetElementType(), alias)
		out = out .. "["
		for i = 2, Type:GetArrayRank() do
			out = out .. ","
		end
		out = out .. "]"
		return out
	elseif Type.IsPointer then
		return GetTypeName(Type:GetElementType(), alias) .. "*"
	elseif Type.IsByRef then
		return GetTypeName(Type:GetElementType(), alias) .. "&"
	elseif Type.IsGenericType then
		local name = Type:GetGenericTypeDefinition().Name
		local pos = name:find("`")
		if pos ~= nil then
			name = name:sub(1, pos - 1)
		end
		local generic_args = Type:GetGenericArguments()
		name = name .. "<"
		for i = 0, generic_args.Length - 1 do
			if i ~= 0 then
				name = name .. ", "
			end
			name = name .. GetTypeName(generic_args[i], alias)
		end
		name = name .. ">"
		return name
	else
		if alias and Type.Namespace == "System" then
			local name = SYSTEM_NAMES[Type.FullName]
			if name ~= nil then
				return name
			end
		end
		return GetReflectedType(Type)
	end
end

local function GetClassModifier(Type)
	local IsEnum = Type.IsEnum
	local IsValueType = Type.IsValueType
	local IsInterface = Type.IsInterface
	local Flags = Type.Attributes.value__
	local Visibility = Flags & TYPE_ATTRIBUTE_VISIBILITY_MASK
	local ret = ""

	if Visibility == TYPE_ATTRIBUTE_PUBLIC or Visibility == TYPE_ATTRIBUTE_NESTED_PUBLIC then
		ret = ret .. "public "
	elseif Visibility == TYPE_ATTRIBUTE_NOT_PUBLIC or Visibility == TYPE_ATTRIBUTE_NESTED_FAM_AND_ASSEM or Visibility == TYPE_ATTRIBUTE_NESTED_ASSEMBLY then
		ret = ret .. "internal "
	elseif Visibility == TYPE_ATTRIBUTE_NESTED_PRIVATE then
		ret = ret .. "private "
	elseif Visibility == TYPE_ATTRIBUTE_NESTED_FAMILY then
		ret = ret .. "protected"
	elseif Visibility == TYPE_ATTRIBUTE_NESTED_FAM_OR_ASSEM then
		ret = ret .. "protected internal"
	end

	if ((Flags & TYPE_ATTRIBUTE_ABSTRACT) ~= 0) and ((Flags & TYPE_ATTRIBUTE_SEALED) ~= 0) then
		ret = ret .. "static "
	elseif not ((Flags & TYPE_ATTRIBUTE_INTERFACE) ~= 0) and ((Flags & TYPE_ATTRIBUTE_ABSTRACT) ~= 0) then
		ret = ret .. "abstract "
	elseif not IsEnum and ((Flags & TYPE_ATTRIBUTE_SEALED) ~= 0) then
		ret = ret .. "sealed "
	end

	if IsInterface then
		ret = ret .. "interface "
	elseif IsEnum then
		ret = ret .. "enum "
	elseif IsValueType then
		ret = ret .. "struct "
	else
		ret = ret .. "class "
	end

	return ret
end

local function GetMethodModifier(MethodInfo)
	local output = ""
	local Flags = MethodInfo.Attributes.value__
	local access = (Flags & METHOD_ATTRIBUTE_MEMBER_ACCESS_MASK)

	if access == METHOD_ATTRIBUTE_PRIVATE then
		output = output .. "private "
	elseif access == METHOD_ATTRIBUTE_PUBLIC then
		output = output .. "public "
	elseif access == METHOD_ATTRIBUTE_FAMILY then
		output = output .. "protected "
	elseif access == METHOD_ATTRIBUTE_ASSEM or access == METHOD_ATTRIBUTE_FAM_AND_ASSEM then
		output = output .. "internal "
	elseif access == METHOD_ATTRIBUTE_FAM_OR_ASSEM then
		output = output .. "protected internal "
	end

	if (Flags & METHOD_ATTRIBUTE_STATIC) ~= 0 then
		output = output .. "static "
	end

	if (Flags & METHOD_ATTRIBUTE_ABSTRACT) ~= 0 then
		output = output .. "abstract "
		if (Flags & METHOD_ATTRIBUTE_VTABLE_LAYOUT_MASK) == METHOD_ATTRIBUTE_REUSE_SLOT then
			output = output .. "override "
		end
	elseif (Flags & METHOD_ATTRIBUTE_FINAL) ~= 0 then
		if (Flags & METHOD_ATTRIBUTE_VTABLE_LAYOUT_MASK) == METHOD_ATTRIBUTE_REUSE_SLOT then
			output = output .. "sealed override "
		end
	elseif (Flags & METHOD_ATTRIBUTE_VIRTUAL) ~= 0 then
		if (Flags & METHOD_ATTRIBUTE_VTABLE_LAYOUT_MASK) == METHOD_ATTRIBUTE_NEW_SLOT then
			output = output .. "virtual "
		else
			output = output .. "override "
		end
	end

	if (Flags & METHOD_ATTRIBUTE_PINVOKE_IMPL) ~= 0 then
		output = output .. "extern "
	end

	return output
end

local function GetMethodArguments(MethodInfo)
	local Arguments = MethodInfo:GetParameters()
	local ret = ""
	for i = 0, Arguments.Length - 1 do
		local Argument = Arguments[i]
		local Name = Argument.Name
		local TypeName = GetTypeName(Argument.ParameterType)

		ret = ret .. string.format("%s %s", TypeName, Name)

		if i ~= Arguments.Length - 1 then
			ret = ret .. ", "
		end
	end
	return ret
end

local function GetMethodRVA(Assembly, Type, MethodInfo, ConstructorInfo)
	local AssemblyName = Assembly:GetName().Name .. ".dll";
	local TypeName = tostring(Type.Name)
	local MethodName = MethodInfo.Name
	if ConstructorInfo ~= nil then
		MethodName = ConstructorInfo.Name
	end
	local str = string.format("%s|%s|%s", AssemblyName, TypeName, MethodName)
	return CS.MiHoYo.SDK.SDKUtil.RSAEncrypt("get_rva", str)
end

local function GetFieldModifier(FieldInfo)
	local attrs = FieldInfo.Attributes.value__
	local output = ""

	local access = (attrs & FIELD_ATTRIBUTE_FIELD_ACCESS_MASK)
	if access == FIELD_ATTRIBUTE_PRIVATE then
		output = output .. "private "
	elseif access == FIELD_ATTRIBUTE_PUBLIC then
		output = output .. "public "
	elseif access == FIELD_ATTRIBUTE_FAMILY then
		output = output .. "protected "
	elseif access == FIELD_ATTRIBUTE_ASSEMBLY or access == FIELD_ATTRIBUTE_FAM_AND_ASSEM then
		output = output .. "internal "
	elseif access == FIELD_ATTRIBUTE_FAM_OR_ASSEM then
		output = output .. "protected internal "
	end

	if (attrs & FIELD_ATTRIBUTE_LITERAL) ~= 0 then
		output = output .. "const "
	else
		if (attrs & FIELD_ATTRIBUTE_STATIC) ~= 0 then
			output = output .. "static "
		end
		if (attrs & FIELD_ATTRIBUTE_INIT_ONLY) ~= 0 then
			output = output .. "readonly "
		end
	end

	return output
end

local function GetFieldOffset(Type, FieldInfo)
	local AssemblyName = Type.Assembly:GetName().Name .. ".dll";
	local TypeName = tostring(Type.Name)
	local FieldName = FieldInfo.Name
	local str = string.format("%s|%s|%s", AssemblyName, TypeName, FieldName)
	return CS.MiHoYo.SDK.SDKUtil.RSAEncrypt("get_offset", str)
end

-- Without Comment Syntax
local function GetFieldToken(FieldInfo)
	local ret = ""
	local Token = FieldInfo.MetadataToken
	if Token ~= nil and Token ~= 0 then
		ret = string.format("0x%X", Token)
	end
	return ret
end

local function DumpField(Type, FieldInfo)
	local Modifier = GetFieldModifier(FieldInfo)
	local TypeName = GetTypeName(FieldInfo.FieldType)
	local FieldOffset = GetFieldOffset(Type, FieldInfo)
	local FieldToken = GetFieldToken(FieldInfo)
	local CustomAttrs = GetCustomAttributes(FieldInfo)

	WriteOutput(CustomAttrs, "", false)
	WriteOutput(string.format("%s%s %s", Modifier, TypeName, FieldInfo.Name), "\t", false)

	-- TODO: Figure out why crashing, for now only get literal value on RPG.Network.Proto.dll module
	local get_literal_val = false -- Type.IsEnum
	if CONSTANT_DUMP_ASSEMBLIES[Type.Assembly:GetName().Name] ~= nil then
		get_literal_val = Type.IsEnum or string.match(TypeName, "int")
	end

	if FieldInfo.IsLiteral and get_literal_val then
		WriteOutput(string.format(" = %s", string.match(tostring(FieldInfo:GetValue()), "%d+") or ""), "", false)
	end

	WriteOutput(string.format("; // Offset: %s", FieldOffset), "", false)
	if FieldToken:len() > 0 then
		WriteOutput(string.format(", Token: %s", FieldToken), "", false)
	end
	WriteOutput("")
end

local function DumpConstructor(Type, ConstructorInfo)
	local MethodInfo = ConstructorInfo.MethodHandle
	local Modifier = GetMethodModifier(ConstructorInfo)
	local TypeName = "void"
	local RVA = GetMethodRVA(Type.Assembly, Type, MethodInfo, ConstructorInfo)
	local Args = GetMethodArguments(ConstructorInfo)
	WriteOutput(string.format("%s%s %s(%s) // RVA: %s", Modifier, TypeName, ConstructorInfo.Name, Args, RVA), "\t", false)
	WriteOutput("")
end

local function DumpProperty(PropertyInfo)
	local GetMethod = PropertyInfo:GetGetMethod(true)
	local SetMethod = PropertyInfo:GetSetMethod(true)
	local TypeName = GetTypeName(PropertyInfo.PropertyType)
	local Modifier = ""
	local Inner = ""
	local CustomAttrs = GetCustomAttributes(PropertyInfo)

	if GetMethod ~= nil then
		Modifier = GetMethodModifier(GetMethod)
	elseif SetMethod ~= nil then
		Modifier = GetMethodModifier(SetMethod)
	end

	if GetMethod ~= nil then
		Inner = Inner .. " get; "
	end
	if SetMethod ~= nil then
		Inner = Inner .. "set; "
	end

	WriteOutput(CustomAttrs, "", false)
	WriteOutput(
		string.format("%s%s %s {%s}", Modifier, TypeName, PropertyInfo.Name, Inner),
		"\t",
		false
	)

	WriteOutput("")
end

local function DumpMethod(Type, MethodInfo)
	local Modifier = GetMethodModifier(MethodInfo)
	local ReturnType = GetTypeName(MethodInfo.ReturnType)
	local Args = GetMethodArguments(MethodInfo)
	local RVA = GetMethodRVA(Type.Assembly, Type, MethodInfo)
	local Attributes = GetCustomAttributes(MethodInfo)
	WriteOutput(Attributes, "", false)
	WriteOutput(string.format("%s%s %s(%s) // RVA: %s", Modifier, ReturnType, MethodInfo.Name, Args, RVA), "\t", false)
	WriteOutput("")
end

local function DumpType(Type, AssemblyIndex, TypeIndexInAssembly, TypeDefIndex)
	local Module = Type.Assembly:GetName().Name
	local Namespace = tostring(Type.Namespace)
	local FullName = tostring(Type.FullName)
	local Methods = Type:GetMethods(FLAGS) -- CS.System.Reflection.BindingFlags.Static | CS.System.Reflection.BindingFlags.Public | CS.System.Reflection.BindingFlags.NonPublic
	local Fields = Type:GetFields(FLAGS)
	local Properties = Type:GetProperties(FLAGS)
	local Constructors = Type:GetConstructors(FLAGS)
	local Interfaces = Type:GetInterfaces(FLAGS)
	local CustomAttrs = GetCustomAttributes(Type, false)

	-- Info
	WriteOutput(string.format("// Assembly Index: %i TypeIndexInAssembly: %i", AssemblyIndex, TypeIndexInAssembly))
	WriteOutput(string.format("// TypeDefIndex: %i", TypeDefIndex))
	WriteOutput(string.format("// Module: %s.dll", Module))
	WriteOutput(string.format("// Namespace: %s", Namespace))
	WriteOutput(string.format("// FullName: %s", FullName))

	WriteOutput(CustomAttrs, "", false)
	WriteOutput(string.format("%s%s", GetClassModifier(Type), GetTypeName(Type, true)), "", false)

	if Interfaces.Length > 0 then
		WriteOutput(" : ", "", false)
		for i = 0, Interfaces.Length - 1 do
			WriteOutput(GetTypeName(Interfaces[i], true), "", false)

			if i ~= Interfaces.Length - 1 then
				WriteOutput(", ", "", false)
			end
		end
	end

	WriteOutput("\n{\n")

	if Fields.Length > 0 then
		WriteOutput("\t// Fields")
		for i = 0, Fields.Length - 1 do
			DumpField(Type, Fields[i])
		end
		WriteOutput("")
	end

	if not Type.IsEnum then
		if Properties.Length > 0 then
			WriteOutput("\t// Properties")
			for i = 0, Properties.Length - 1 do
				DumpProperty(Properties[i])
			end
			WriteOutput("")
		end

		if Constructors.Length > 0 then
			WriteOutput("\t// Constructors")
			for i = 0, Constructors.Length - 1 do
				DumpConstructor(Type, Constructors[i])
			end
			WriteOutput("")
		end

		if Methods.Length > 0 then
			WriteOutput("\t// Methods")
			for i = 0, Methods.Length - 1 do
				DumpMethod(Type, Methods[i])
			end
		end
	end

	WriteOutput("\n}")

	WriteOutput("\n")
end

local function main()
	local Assemblies = CS.System.AppDomain.CurrentDomain:GetAssemblies()

	for i = 0, Assemblies.Length - 1 do
		local Assembly = Assemblies[i]
		local FullName = Assembly.FullName
		WriteOutput(string.format("// Assembly %i: %s", i, FullName))
	end
	WriteOutput("")

	local TypeDefIndex = 1
	for i = 0, Assemblies.Length - 1 do
		local Assembly = Assemblies[i]
		local FullName = Assembly.FullName
		WriteOutput(string.format("// Dumping Types In Assembly %i: %s \n", i, FullName))

		local Types = Assembly:GetTypes(FLAGS)
		for j = 0, Types.Length - 1 do
			DumpType(Types[j], i, j, TypeDefIndex)
			TypeDefIndex = TypeDefIndex + 1
		end
	end
end

xpcall(main, WriteError)

OUT_FILE:Close()
LOG_FILE:Close()
