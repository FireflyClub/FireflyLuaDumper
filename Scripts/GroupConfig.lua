local OUTPUT_FOLDER = "./DumpTest/"

local LOG_OUTPUT_FILE = "./LogDumpGroupConfig.log"

local resetFields = {
    ["TagContainer"] = 1,
}

local flags = CS.System.Reflection.BindingFlags.Instance
            | CS.System.Reflection.BindingFlags.Static
            | CS.System.Reflection.BindingFlags.Public
            | CS.System.Reflection.BindingFlags.NonPublic

local List = CS.System.Collections.Generic.List(CS.System.Object)

local serializer = CS.Newtonsoft.Json.JsonSerializer()
    serializer.DefaultValueHandling = CS.Newtonsoft.Json.DefaultValueHandling.Ignore
    serializer.ReferenceLoopHandling = CS.Newtonsoft.Json.ReferenceLoopHandling.Ignore
    serializer.TypeNameHandling = CS.Newtonsoft.Json.TypeNameHandling.Auto
    serializer.Formatting = CS.Newtonsoft.Json.Formatting.Indented
    serializer.MetadataPropertyHandling = CS.Newtonsoft.Json.MetadataPropertyHandling.Ignore
    serializer.Converters:Add(CS.Newtonsoft.Json.Converters.StringEnumConverter())
    serializer.NullValueHandling =  CS.Newtonsoft.Json.NullValueHandling.Ignore

local log_writer = CS.System.IO.StreamWriter(LOG_OUTPUT_FILE)

local function write_log(text)
    log_writer:WriteLine(text)
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

local on_error = function(text)
    CS.RPG.Client.ConfirmDialogUtil.ShowCustomOkCancelHint(tostring(text))
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

local dump = function()
    local paths = List()
    local enumerator = CS.RPG.GameCore.MazePlaneExcelTable:GetEnumerator();
    while enumerator:MoveNext() do
        local maze_plane = get_enumerator_value(enumerator)
        for i = 0, maze_plane.FloorIDList.Length - 1 do
            local floor_id = maze_plane.FloorIDList[i]
            local name = "P" .. maze_plane.PlaneID .. "_" .. "F" .. floor_id
            local floor_config = CS.RPG.GameCore.GameCoreConfigLoader.LoadRtLevelFloorInfo("Config/LevelOutput/RuntimeFloor/" .. name .. ".json")
            if floor_config.GroupInstanceList ~= nil then
                for j = 0, floor_config.GroupInstanceList.Length - 1 do
                    local group_path = floor_config.GroupInstanceList[j].GroupPath
                    paths:Add(group_path)
                end
            end
        end
    end

    for i = 0, paths.Count - 1 do
        xpcall(function()
            local pathValue = paths[i]
            local values = string_split(pathValue, "/")
            local out_file = OUTPUT_FOLDER .. pathValue
            local out_folder = string.gsub(out_file, values[#values], "")
            local dataObject = CS.RPG.GameCore.GameCoreConfigLoader.LoadRtLevelGroupInfo(pathValue)

            if dataObject ~= nil then
                if not CS.System.IO.Directory.Exists(out_folder) then
                    CS.System.IO.Directory.CreateDirectory(out_folder);
                end
                local swriter = CS.System.IO.StreamWriter(out_file)
                local jwriter = CS.Newtonsoft.Json.JsonTextWriter(swriter)
                reset_user_data(dataObject)
                serializer:Serialize(jwriter, dataObject)
                jwriter:Close()
                swriter:Close()
            end
        end, function(err)
            write_log(tostring(err))
        end)
    end

    log_writer:Close()
end

xpcall(dump, on_error)
