local OBF_ENUMERATOR_NAME = ""
local OBF_DICTIONARY_PROPERTY =  ""
local DUMP_PATH = "./DumpTest/ExcelOutput/"
local LOG_OUTPUT_FILE = "./DumpTest/LogDumpExcelOutput.log"

local serializer = CS.Newtonsoft.Json.JsonSerializer()
    serializer.DefaultValueHandling = CS.Newtonsoft.Json.DefaultValueHandling.Ignore
    serializer.ReferenceLoopHandling = CS.Newtonsoft.Json.ReferenceLoopHandling.Ignore
    serializer.TypeNameHandling = CS.Newtonsoft.Json.TypeNameHandling.Auto
    serializer.Formatting = CS.Newtonsoft.Json.Formatting.Indented
    serializer.MetadataPropertyHandling = CS.Newtonsoft.Json.MetadataPropertyHandling.Ignore
    serializer.Converters:Add(CS.Newtonsoft.Json.Converters.StringEnumConverter())
    serializer.NullValueHandling =  CS.Newtonsoft.Json.NullValueHandling.Ignore

local flags = CS.System.Reflection.BindingFlags.Instance |
    CS.System.Reflection.BindingFlags.Static |
    CS.System.Reflection.BindingFlags.Public |
    CS.System.Reflection.BindingFlags.NonPublic

local List = CS.System.Collections.Generic.List(CS.System.Object)

local system_type_table = {
    ["System.Int32"] = "int32",
    ["System.UInt32"] = "uint32",
    ["System.Int16"] = "short",
    ["System.UInt16"] = "ushort",
    ["System.Int64"] = "int64",
    ["System.UInt64"] = "uint64",
    ["System.Byte"] = "byte",
    ["System.SByte"] = "sbyte",
    ["System.Boolean"] = "bool",
    ["System.Single"] = "float",
    ["System.Double"] = "double",
    ["System.String"] = "string",
    ["System.Char"] = "char",
    ["System.Object"] = "object",
    ["System.Void"] = "void"
}

local function getReflectedType(type)
    local name = type.Name
    if type.ReflectedType ~= nil --
        and not type.ReflectedType.IsGenericType then
        name = getReflectedType(type.ReflectedType) .. "." .. name
    end
    return name
end

local function getRuntimeTypeName(type, alias)
    if type.IsArray then
        local out = getRuntimeTypeName(type:GetElementType(), alias)
        out = out .. "["
        for i = 2, type:GetArrayRank() do
            out = out .. ","
        end
        out = out .. "]"
        return out
    elseif type.IsPointer then
        return getRuntimeTypeName(type:GetElementType(), alias) .. "*"
    elseif type.IsByRef then
        return getRuntimeTypeName(type:GetElementType(), alias) .. "&"
    elseif type.IsGenericType then
        local name = type:GetGenericTypeDefinition().Name
        local pos = name:find("`")
        if pos ~= nil then
            name = name:sub(1, pos - 1)
        end
        local generic_args = type:GetGenericArguments()
        name = name .. "<"
        for i = 0, generic_args.Length - 1 do
            if i ~= 0 then
                name = name .. ", "
            end
            name = name .. getRuntimeTypeName(generic_args[i], alias)
        end
        name = name .. ">"
        return name
    else
        if alias and type.Namespace == "System" then
            local name = system_type_table[type.FullName]
            if name ~= nil then
                return name
            end
        end
        return getReflectedType(type)
    end
end

local function on_error(error)
    local js = CS.Newtonsoft.Json.JsonConvert.SerializeObject(error)
    CS.RPG.Client.ConfirmDialogUtil.ShowCustomOkCancelHint("error: " .. js .. "\n")
end

local function getEnumeratorValue(obj)
    local objType = obj:GetType()
    local properties = objType:GetProperties(CS.System.Reflection.BindingFlags.NonPublic |
        CS.System.Reflection.BindingFlags.Instance)

    for i = 0, properties.Length - 1 do
        local property = properties[i]
        if property.Name == "System.Collections.IEnumerator.Current" then
            return property:GetValue(obj, nil)
        end
    end

    return nil
end

local function write_json(enumerator, path, errList)
    local swriter= CS.System.IO.StreamWriter(path)
    local jwriter = CS.Newtonsoft.Json.JsonTextWriter(swriter)

    jwriter:WriteStartArray()

    local i = 0

    while enumerator:MoveNext() do
        local value = getEnumeratorValue(enumerator)
        i = i + 1
        xpcall(function() serializer:Serialize(jwriter, value) end, function(error) 
            errList:Add("failed to serializing json")
        end)
    end

    if i > 0 then
        jwriter:WriteRaw("\n")
    end

    jwriter:WriteEndArray()
    jwriter:Close()
    swriter:Close()
end

local function get_filename(path)
    return path:match("([^/]+)%.%w*$") or path:match("([^/]+)$")
end

local function contains(str, sub)
    return str:find(sub, 1, true) ~= nil
end

local function dump_excel(type, isObfuscated, errList)
    local enumeratorMethodString = "GetEnumerator"
    local name = type.Name
    if isObfuscated then
        local generics = type:GetProperty(OBF_DICTIONARY_PROPERTY).PropertyType:GetGenericArguments()
        local generic = nil
        if generics.Length > 1 then
            generic = generics[1]
        elseif generics.Length == 1 then
            generic = generics[0]
        end
        enumeratorMethodString = OBF_ENUMERATOR_NAME
        name = string.gsub(generic.Name, "Row", "")
    end
    local enumeratorMethod = type:GetMethod(enumeratorMethodString)
    if enumeratorMethod == nil then
        return
    end

    local fields = type:GetFields(flags)
    for j = 0, fields.Length -1 do
        if getRuntimeTypeName(fields[j].FieldType, true) == "string[]" and fields[j].IsStatic then
            local values = fields[j]:GetValue()

            for i = 0, values.Length - 1 do
                local name2 = get_filename(values[i])
                if name2 == nil then
                    name2 = "UNK"
                end
                local path = DUMP_PATH .. name2 .. ".json"
                write_json(enumeratorMethod:Invoke(type), path, errList)
            end

            return
        end
    end
    if name == nil then
        name = "UNK"
    end

    -- Fallback without s_PathList
    local enumerator = enumeratorMethod:Invoke(type)
    local path = DUMP_PATH .. name .. ".json"
    write_json(enumerator, path, errList)
end

local function main()
    local errList = List()
    local assemblies = CS.System.AppDomain.CurrentDomain:GetAssemblies()
    local assembly = nil

    for i = 0, assemblies.Length - 1 do
        local cur_asm = assemblies[i]:GetName().Name
        if cur_asm == "RPG.GameCore.Config" then
            assembly = assemblies[i]
            break
        end
    end

    if assembly == nil then
        return
    end

    local types = assembly:GetTypes()

    if not CS.System.IO.Directory.Exists(DUMP_PATH) then
        CS.System.IO.Directory.CreateDirectory(DUMP_PATH);
    end

    for i = 0, types.Length - 1 do
        local type = types[i] -- Type
        local hasObfProperty = false
        if string.match(type.Name, "^%u%u%u%u%u%u%u%u%u%u%u$") then
            local properties = type:GetProperties(flags)
            local methods = type:GetMethods(flags)
            for j = 0, properties.Length - 1 do
                local property = properties[j]
                local generics = property.PropertyType:GetGenericArguments()

                local generic = nil
                if generics.Length > 1 then
                    generic = generics[1]
                elseif generics.Length == 1 then
                    generic = generics[0]
                end

                if generics.Length > 0 and string.find(generic.Name, "Row") then
                    hasObfProperty = true
                    OBF_DICTIONARY_PROPERTY = property.Name
                    for k = 0, methods.Length -1 do 
                        local method = methods[k]
                        if contains(method.ReturnType.FullName, "Enumerator") then
                            OBF_ENUMERATOR_NAME = method.Name
                            break
                        end
                    end
                    break
                end
            end
        end

        xpcall(function() dump_excel(type, hasObfProperty, errList) end, function(error)
            errList:Add("Err at at " .. type.Name .. " with err " .. tostring(error))
        end)
    end

    -- write output log
    local swriter = CS.System.IO.StreamWriter(LOG_OUTPUT_FILE)
    local jwriter = CS.Newtonsoft.Json.JsonTextWriter(swriter)
    serializer:Serialize(jwriter, errList)
    jwriter:Close()
    swriter:Close()
end

xpcall(main, on_error)
