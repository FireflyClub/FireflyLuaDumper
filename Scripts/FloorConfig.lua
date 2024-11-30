-- Output folder
local DUMP_FOLDER = "./DumpTest"
local OUTPUT_FOLDER = DUMP_FOLDER .."/"
local LOG_OUTPUT_FILE = DUMP_FOLDER .. "/LogDumpFloorConfig.log"

local serializer = CS.Newtonsoft.Json.JsonSerializer.CreateDefault()
serializer.DefaultValueHandling = CS.Newtonsoft.Json.DefaultValueHandling.Ignore
serializer.ReferenceLoopHandling = CS.Newtonsoft.Json.ReferenceLoopHandling.Ignore
serializer.TypeNameHandling = CS.Newtonsoft.Json.TypeNameHandling.Auto
serializer.Formatting = CS.Newtonsoft.Json.Formatting.Indented
serializer.MetadataPropertyHandling = CS.Newtonsoft.Json.MetadataPropertyHandling.Ignore
serializer.Converters:Add(CS.Newtonsoft.Json.Converters.StringEnumConverter())
serializer.NullValueHandling =  CS.Newtonsoft.Json.NullValueHandling.Ignore

local flags = CS.System.Reflection.BindingFlags.Instance
    | CS.System.Reflection.BindingFlags.Static
    | CS.System.Reflection.BindingFlags.Public
    | CS.System.Reflection.BindingFlags.NonPublic

local resetFields = {
    ["TagContainer"] = "nil"
}

local log_writer = CS.System.IO.StreamWriter(LOG_OUTPUT_FILE)

local function write_log(text)
    log_writer:WriteLine(text)
end

local function on_error(error)
    local js = CS.Newtonsoft.Json.JsonConvert.SerializeObject(error)
    CS.RPG.Client.ConfirmDialogUtil.ShowCustomOkCancelHint("error: " .. js .. "\n")
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
                local value = resetFields[field.Name]
                if value then
                    if value == "{}" then
                        field:SetValue(cfg, {})
                    else
                        field:SetValue(cfg, nil)
                    end
                else
                    reset_user_data(cfg[field.Name])
                end
            end
        end
    end
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

local function dump()
    local floor_paths = {}

    local enumerator = CS.RPG.GameCore.MazePlaneExcelTable:GetEnumerator();
    while enumerator:MoveNext() do
        local maze_plane = get_enumerator_value(enumerator)
        for i = 0, maze_plane.FloorIDList.Length - 1 do
            local floor_id = maze_plane.FloorIDList[i]
            local name = "P" .. maze_plane.PlaneID .. "_" .. "F" .. floor_id
            if floor_paths[name] == nil then
                table.insert(floor_paths, "Config/LevelOutput/RuntimeFloor/" .. name .. ".json")
            end
        end
    end

    for i, pv in ipairs(floor_paths) do
        xpcall(function()
            local pathValue = string.gsub(pv, "\r", "")
            local values = string_split(pathValue, "/")
            local out_file = OUTPUT_FOLDER .. pathValue
            local out_folder = string.gsub(out_file, values[#values], "")
            local dataObject = CS.RPG.GameCore.GameCoreConfigLoader.LoadRtLevelFloorInfo(pathValue)

            if dataObject ~= nil then
                if not CS.System.IO.Directory.Exists(out_folder) then
                    CS.System.IO.Directory.CreateDirectory(out_folder);
                end
                local swriter = CS.System.IO.StreamWriter(out_file)
                local jwriter = CS.Newtonsoft.Json.JsonTextWriter(swriter)
                xpcall(function()
                    reset_user_data(dataObject)
                    serializer:Serialize(jwriter, dataObject)
                end, function(err) write_log("Err (inner) at " .. pathValue .. " With err " .. tostring(err))  end)
                jwriter:Close()
                swriter:Close()
            end
        end, function(err) write_log("Err (outer) at " .. pv .. " With err " .. tostring(err))  end)
    end

    -- write output log
    log_writer:Close()
end

xpcall(dump, on_error)
