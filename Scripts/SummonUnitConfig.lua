local OUT_ROOT = "./DumpTest"
local OUT_PATH = OUT_ROOT .. "/"
local LOG_FILE = OUT_ROOT .. "/LogDumpSummonUnitConfig.log"

local resetFields = {
    ["DynamicValues"] = 1,
}

local flags = CS.System.Reflection.BindingFlags.Instance
            | CS.System.Reflection.BindingFlags.Static
            | CS.System.Reflection.BindingFlags.Public
            | CS.System.Reflection.BindingFlags.NonPublic

local serializer = CS.Newtonsoft.Json.JsonSerializer.CreateDefault()
    serializer.DefaultValueHandling = CS.Newtonsoft.Json.DefaultValueHandling.Ignore
    serializer.ReferenceLoopHandling = CS.Newtonsoft.Json.ReferenceLoopHandling.Ignore
    serializer.TypeNameHandling = CS.Newtonsoft.Json.TypeNameHandling.Auto
    serializer.Formatting = CS.Newtonsoft.Json.Formatting.Indented
    serializer.MetadataPropertyHandling = CS.Newtonsoft.Json.MetadataPropertyHandling.Ignore
    serializer.Converters:Add(CS.Newtonsoft.Json.Converters.StringEnumConverter())
    serializer.NullValueHandling =  CS.Newtonsoft.Json.NullValueHandling.Ignore

local log_writer = CS.System.IO.StreamWriter(LOG_FILE)

local function write_log(text)
    log_writer:WriteLine(text)
end

local on_error = function(error)
    local js = CS.Newtonsoft.Json.JsonConvert.SerializeObject(error)
    CS.RPG.Client.ConfirmDialogUtil.ShowCustomOkCancelHint("error: " .. js .. "\n")
end

local string_split = function(str, pat)
    local t = {}
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(t, cap)
        end
        last_end = e + 1
        s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end
    return t
end

local function reset_user_data(cfg)
    local tstr = type(cfg)
    if tstr == "nil" or tstr == "boolean" or tstr == "number"
    or not cfg.GetType
    then
        return
    end
    local type = cfg:GetType()
    if type.IsArray then
        for i = 0, cfg.Length - 1 do
            reset_user_data(cfg[i])
        end
    elseif not type.IsGenericType then
        local fields = type:GetFields(flags)
        if fields and fields.Length then
            for i = 0, fields.Length - 1 do
                local field = fields[i]
                if resetFields[field.Name] then
                    field:SetValue(cfg, nil)
                else
                    reset_user_data(cfg[field.Name])
                end
            end
        end
    end
end

local function write_json(path, data)
    local sw = CS.System.IO.StreamWriter(path)
    local jw = CS.Newtonsoft.Json.JsonTextWriter(sw)
    serializer:Serialize(jw, data)
    sw:Close()
    jw:Close()
end

local function get_enumerator_value(obj)
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

local function get_assembly(name)
    local assemblies = CS.System.AppDomain.CurrentDomain:GetAssemblies()
    local assembly = nil

    for i = 0, assemblies.Length - 1 do
        local cur_asm = assemblies[i]:GetName().Name
        if cur_asm == name then
            assembly = assemblies[i]
            break
        end
    end

    return assembly
end

local function contains(str, sub)
    return str:find(sub, 1, true) ~= nil
end

local function get_enumerator(assembly, row_name)
    local types = assembly:GetTypes()
    for i = 0, types.Length - 1 do
        local type = types[i] -- Type
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

                if generics.Length > 0 and contains(generic.Name, row_name) then
                    for k = 0, methods.Length -1 do
                        local method = methods[k]
                        if contains(method.ReturnType.FullName, "Enumerator") then
                            return method:Invoke(type)
                        end
                    end
                end
            end
        end
    end
end

local main_function = function()
    local assembly = get_assembly("RPG.GameCore.Config")
    if assembly == nil then
        return
    end

    local enumerator = get_enumerator(assembly, "SummonUnitDataRow")

    while enumerator:MoveNext() do
        local excel = get_enumerator_value(enumerator)
        if excel.ID == 13121 then
            write_log("Skipped summon unit with ID: 13121")
        -- TODO: skip misha's summon unit, crashed the dumper
        else
            local path_value = excel.JsonPath
            local values = string_split(path_value, "/")
            local out_file = OUT_PATH .. path_value
            local out_folder = string.gsub(out_file, values[#values], "")
            if not CS.System.IO.Directory.Exists(out_folder) then
                CS.System.IO.Directory.CreateDirectory(out_folder);
            end

            xpcall(function()
                local cfg = CS.RPG.GameCore.GameCoreConfigLoader.LoadSummonUnitConfig(path_value)
                reset_user_data(cfg)
                write_json(out_file, cfg)
            end,function(errmsg)
                write_log("Error At: " .. path_value .. " With Error : " .. tostring(errmsg))
            end)
        end

    end

    log_writer:Close()
end


xpcall(main_function, on_error)
