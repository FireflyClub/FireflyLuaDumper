local OutputPath = "StarRail.proto"
local LogPath = "./LogProto.log"
local CmdId = true
local AutoNT = true

local logs = ""
local file = "syntax = \"proto3\";\n"

local flags = CS.System.Reflection.BindingFlags.Instance |
    CS.System.Reflection.BindingFlags.Static |
    CS.System.Reflection.BindingFlags.Public |
    CS.System.Reflection.BindingFlags.NonPublic

local Dictionary = CS.System.Collections.Generic.Dictionary(CS.System.String, CS.System.Object);

local systemTypeMap = {
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

local fieldTypeMap = {
    ["MapField<"] = "map<",
    ["ByteString"] = "bytes",
    ["RepeatedField<"] = "repeated "
}

local function onError(error)
    logs = logs .. error .. "\n"
end

local function contains(str, sub)
    return str:find(sub, 1, true) ~= nil
end

local function countOccurrences(str, sub)
    local _, occurrences = str:gsub(sub, "")
    return occurrences
end

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
            local name = systemTypeMap[type.FullName]
            if name ~= nil then
                return name
            end
        end
        return getReflectedType(type)
    end
end

local function getRawType(fieldtype)
    local ret =  fieldtype:gsub("MapField<", ""):gsub("RepeatedField<", ""):gsub(">", "")
    if contains(ret, ",") then
        ret = string.sub(ret, string.find(ret, ",") + 1, string.len(ret))
    end
    return ret
end

local message_fields_counter = Dictionary();
local message_ref_counter = Dictionary();

local function dumpProtoFromType(type, nt_table, cmdid_table)
    local out = ""
    local runtimeTypeName = getRuntimeTypeName(type, false)
    local cmdName = nil

    -- Find OneOf then skip
    local skipTypes = {}
    if string.find(runtimeTypeName, "%.") then return "" end

    if string.find(runtimeTypeName, "<") == nil then
        local fields = type:GetFields(flags)
        local inner = ""
        local isEnumType = nil
        local fieldIds = {}
        local idx = 0

        -- Build enum format
        if fields.Length > 0 then
            for j = 0, fields.Length - 1 do
                local field = fields[j]

                -- Enums
                if field.DeclaringType == type then
                    local enumKey = nil
                    local attributes = field:GetCustomAttributes(true)
                    for i = 0, attributes.Length - 1 do
                        local text = getRuntimeTypeName(attributes[i]:GetType())
                        enumKey = attributes[i].Name
                        if text == "OriginalNameAttribute" then
                            isEnumType = true
                            if cmdName == nil then
                                -- Handle CMD_RECOMMEND_TYPE_NONE
                                if enumKey:find("^CMD") then
                                    cmdName = string.match(enumKey, "^CMD(.-)_NONE$")
                                    if cmdName then
                                        cmdName = "Cmd" ..
                                        cmdName:lower():gsub("_(%l)", function(c) return c:upper() end)
                                    end
                                end
                                if enumKey:find("^Cmd") then
                                    cmdName = string.match(enumKey, "^Cmd(.-)None$")
                                    if cmdName then
                                        cmdName = "Cmd" .. cmdName
                                    end
                                end
                            end
                        end
                    end

                    -- Enums
                    if field.IsLiteral then
                        local value = field:GetRawConstantValue()
                        fieldIds[idx] = value
                        idx = idx + 1
                        if enumKey then
                            inner = inner .. "\t"
                            inner = inner .. enumKey
                            inner = inner .. string.format(" = %s;", value)
                            inner = inner .. "\n"

                            if cmdName ~= nil then
                                cmdid_table[value] = enumKey
                            end
                        end
                    elseif contains(tostring(field.FieldType.FullName), tostring(field.DeclaringType.Name) .. "+") then
                        local innerFields = field.FieldType:GetFields(flags)

                        -- Oneof
                        if countOccurrences(tostring(field.FieldType.FullName), "+") == 1 then
                            inner = inner .. "\toneof " .. field.Name .. " {\n"
                            for k = 0, innerFields.Length - 1 do
                                local oneOfField = innerFields[k]
                                if oneOfField.IsLiteral then
                                    local value = oneOfField:GetRawConstantValue()
                                    if value ~= 0 then
                                        inner = inner .. "\t\t"
                                        inner = inner .. "int32 " -- Temp
                                        inner = inner .. oneOfField.Name
                                        inner = inner .. string.format(" = %s;", value)
                                        inner = inner .. "\n"
                                    end
                                    skipTypes[oneOfField.Name] = true -- Store the oneof into table
                                end
                            end
                            inner = inner .. "\t}\n"

                            -- Nested
                        elseif countOccurrences(tostring(field.FieldType.FullName), "+") == 2 then
                            inner = inner .. "\tenum " .. field.FieldType.Name .. " {\n"
                            for k = 0, innerFields.Length - 1 do
                                local nenumKey = nil
                                local nestedField = innerFields[k]
                                local nattributes = nestedField:GetCustomAttributes(true)
                                for l = 0, nattributes.Length - 1 do
                                    local text = getRuntimeTypeName(nattributes[l]:GetType())
                                    if text == "OriginalNameAttribute" then
                                        nenumKey = nattributes[l].Name
                                        if nestedField.IsLiteral then
                                            local value = nestedField:GetRawConstantValue()
                                            inner = inner .. "\t\t"
                                            inner = inner .. nenumKey
                                            inner = inner .. string.format(" = %s;", value)
                                            inner = inner .. "\n"
                                            skipTypes[nestedField.Name] = true
                                        end
                                    end
                                end
                            end
                            inner = inner .. "\t}\n"
                        end
                    end
                end
            end
        end

        -- Build struct format
        out = out .. "\n"
        if cmdName ~= nil then
            out = out .. "// " .. runtimeTypeName .. "\n"
            out = out .. "enum " .. cmdName
        elseif isEnumType then
            out = out .. "enum " .. runtimeTypeName
        else
            if nt_table[runtimeTypeName] ~= nil then
                local nted_name = cmdid_table[nt_table[runtimeTypeName]]:gsub("Cmd", "")
                out = out .. "// " .. runtimeTypeName .. " (" .. nt_table[runtimeTypeName] .. ")\n"
                out = out .. "message " .. nted_name

                -- add message counter
                message_ref_counter:Add(nted_name, 0)
            else
                out = out .. "message " .. runtimeTypeName
                message_ref_counter:Add(runtimeTypeName, 0)
            end

        end
        out = out .. " {\n" .. inner

        -- Build message format
        local properties = type:GetProperties(flags)
        if properties.Length > 2 then
            for j = 2, properties.Length - 1 do
                local property = properties[j]
                if property.DeclaringType == type then
                    if fieldIds[j - 2] ~= nil then
                        local typename = getRuntimeTypeName(property.PropertyType, true) -- Is alias
                        local rawtypename = getRawType(typename)
                        -- Nested types/oneofs
                        if typename:find("%.") then
                            typename = string.match(typename, "%.([^%.]+)$")
                        end
                        
                        -- add field counter
                        if message_fields_counter:ContainsKey(rawtypename) then
                            message_fields_counter:set_Item(rawtypename,  message_fields_counter:get_Item(rawtypename) + 1)             
                        else
                            message_fields_counter:Add(rawtypename, 1)
                        end

                        if cmdid_table[nt_table[rawtypename]] ~= nil  then
                            if message_ref_counter:ContainsKey(cmdid_table[nt_table[rawtypename]]:gsub("Cmd", "")) then
                                message_ref_counter:set_Item(cmdid_table[nt_table[rawtypename]]:gsub("Cmd", ""),  message_ref_counter:get_Item(cmdid_table[nt_table[rawtypename]]:gsub("Cmd", "")) + 1)
                            end
                        elseif message_ref_counter:ContainsKey(rawtypename) then
                            message_ref_counter:set_Item(rawtypename,  message_ref_counter:get_Item(rawtypename) + 1)
                        end

                        -- rename map and repeated
                        for pattern, replacement in pairs(fieldTypeMap) do
                            typename = typename:gsub(pattern, replacement)
                        end
                        -- add closing symbol
                        if typename:find("repeated") then
                            typename = typename:gsub(">", "")
                        end

                        if skipTypes[property.Name] then
                            out = out:gsub("int32 " .. property.Name, typename .. " " .. property.Name) -- Rename OneOf Type
                        else
                            out = out .. "\t"
                            out = out .. typename .. " "
                            out = out .. property.Name .. " = "
                            out = out .. fieldIds[j - 2] .. ";\n"
                        end
                    end
                end
            end
        end
        out = out .. "}\n"
    end
    return out
end

local function main()
    -- Init infos
    local assemblies = CS.System.AppDomain.CurrentDomain:GetAssemblies()
    local rpg_network_proto_asm = nil
    local nt_class = nil
    local nt_table = {} -- Key = Message, Value = CmdId
    local req_nt = {} -- Key = Message, Value = CmdId
    local cmdid_table = {} -- Key = CmdIdNumber, Value = CmdIdName

    for i = 0, assemblies.Length - 1 do
        local cur_asm_name = assemblies[i]:GetName().Name
        if cur_asm_name == "RPG.Network.Proto" then
            rpg_network_proto_asm = assemblies[i]
        elseif cur_asm_name == "Assembly-CSharp" then
            local types = assemblies[i]:GetTypes(flags)
            for j = 0, types.Length - 1 do
                local type_name = types[j].Name
                if type_name == "NotifyType" then
                    nt_class = types[j + 2]
                    break
                end
            end
        end
    end

    if rpg_network_proto_asm == nil then
        onError("Cannot find RPG.Network.Proto assembly")
        return
    end

    -- ScRsp / ScNotify NT
    if nt_class ~= nil and AutoNT then
        local fields = typeof(nt_class):GetFields(flags)
        local nts = nil
        for i = 0, fields.Length - 1 do
            local typename = getRuntimeTypeName(fields[i].FieldType, true)
            if typename == "Dictionary<Type, ushort>" then
                nts = fields[i]:GetValue()
                break
            end
        end

        if nts ~= nil then
            for key, value in pairs(nts) do
                nt_table[key.Name] = value
            end
        end
    end

    -- Dump Proto
    local proto_classes = rpg_network_proto_asm:GetTypes(flags)
    for j = 0, proto_classes.Length - 1 do
        local type = proto_classes[j]
        if type.IsGenericType ~= true then
            file = file .. dumpProtoFromType(type, nt_table, cmdid_table)
        end
    end

    -- CsReq NT
    -- TODO: Will lost multi req except the last one
    if AutoNT then
        local message_ref_counter_keys = {}
        local mrc_keys = message_ref_counter.Keys
        local mrck_enumerator = mrc_keys:GetEnumerator()
        local _i = 0
        while mrck_enumerator:MoveNext() do
            local key = mrck_enumerator.Current
            message_ref_counter_keys[_i] = key
            _i = _i + 1
        end

        for i, key in pairs(message_ref_counter_keys) do
            if contains(key, "ScRsp") then
                local j = i
                while j > 0 do
                    j = j - 1
                    local predicted_key = message_ref_counter_keys[j]
                    if message_ref_counter:get_Item(predicted_key) == 0
                        and not contains(predicted_key, "Notify")
                        and not contains(predicted_key, "ScRsp")
                        and not message_fields_counter:ContainsKey(predicted_key)
                    then
                        if req_nt[predicted_key] == nil then
                            req_nt[predicted_key] = string.gsub(key, "ScRsp", "CsReq")
                        end
                    end
            end
            end
        end

        local cmd_id_table_reversed = {}
        for cmdidnum, namestring in pairs(cmdid_table) do
            cmd_id_table_reversed[namestring] = cmdidnum
        end

        for obf, deobf in pairs(req_nt) do
            local replacer =  "// " .. obf
            if cmd_id_table_reversed["Cmd"..deobf] ~= nil then
                replacer = replacer .. " (" .. cmd_id_table_reversed["Cmd"..deobf]  .. ")\n"
            else
                replacer = replacer .. " (Unknown)\n"
            end
            replacer = replacer .."message " .. deobf
            file = file:gsub("message " .. obf, replacer, 1)
        end
    end

    -- CmdId Generate
    if CmdId then
        local result =
            "namespace FireflyDH.Proto;;\n\n" ..
            "public class CmdIds\n{\n" ..
            "\tpublic const int None = 0;\n"
        for cmdid, name in pairs(cmdid_table) do
            result = result .. "\tpublic const int ".. name:gsub("Cmd", "") .." = ".. cmdid ..";\n"
        end
        result = result .. "\n}"
        local swriter = CS.System.IO.StreamWriter("CmdId.cs")
        swriter:Write(result)
        swriter:Close()

        local dict = Dictionary()
        for cmdid, name in pairs(cmdid_table) do
            dict:Add(cmdid, name:gsub("Cmd", ""))
        end
        local serializer = CS.Newtonsoft.Json.JsonSerializer.CreateDefault()
        serializer.Formatting = CS.Newtonsoft.Json.Formatting.Indented
        local sw = CS.System.IO.StreamWriter("packetIds.json")
        local jw = CS.Newtonsoft.Json.JsonTextWriter(sw)
        serializer:Serialize(jw, dict)
        sw:Close()
        jw:Close()
    end
end

xpcall(main, onError)

-- Write to files
if logs ~= "" then
    local logwriter = CS.System.IO.StreamWriter(LogPath)
    logwriter:Write(logs)
    logwriter:Close()
    CS.RPG.Client.ConfirmDialogUtil.ShowCustomOkCancelHint("You got some errors, pls check the log file!")
end
local swriter = CS.System.IO.StreamWriter(OutputPath)
swriter:Write(file)
swriter:Close()
