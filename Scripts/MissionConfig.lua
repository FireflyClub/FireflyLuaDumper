local OUTPUT_FOLDER = "./DumpTest/"
local LOG_OUTPUT_FILE = OUTPUT_FOLDER.. "LogDumpMissionConfig.log"

local log_writer = CS.System.IO.StreamWriter(LOG_OUTPUT_FILE)

local function write_log(text)
	log_writer:WriteLine(text)
end

local serializer = CS.Newtonsoft.Json.JsonSerializer()
	serializer.DefaultValueHandling = CS.Newtonsoft.Json.DefaultValueHandling.Ignore
	serializer.ReferenceLoopHandling = CS.Newtonsoft.Json.ReferenceLoopHandling.Ignore
	serializer.TypeNameHandling = CS.Newtonsoft.Json.TypeNameHandling.Auto
	serializer.Formatting = CS.Newtonsoft.Json.Formatting.Indented
	serializer.MetadataPropertyHandling = CS.Newtonsoft.Json.MetadataPropertyHandling.Ignore
	serializer.Converters:Add(CS.Newtonsoft.Json.Converters.StringEnumConverter())
	serializer.NullValueHandling =  CS.Newtonsoft.Json.NullValueHandling.Ignore

local on_error = function(text)
	local obj = CS.Newtonsoft.Json.JsonConvert.SerializeObject(text)
    CS.RPG.Client.ConfirmDialogUtil.ShowCustomOkCancelHint(obj)
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

local function get_enumerator_value(enumerator)
    local objType = enumerator:GetType()
    local properties = objType:GetProperties(CS.System.Reflection.BindingFlags.NonPublic |
        CS.System.Reflection.BindingFlags.Instance)

    for i = 0, properties.Length - 1 do
        local property = properties[i]
        if property.Name == "System.Collections.IEnumerator.Current" then
            return property:GetValue(enumerator, nil)
        end
    end

    return nil
end

local function write_data_obj(pathValue, func)
	local data_object = nil

	xpcall(function ()
		data_object = func(pathValue)
		if data_object.SubMissionList ~= nil then
			for i = 0, data_object.SubMissionList.Length - 1 do
				local path = data_object.SubMissionList[i].MissionJsonPath
				if path ~= nil then
					write_data_obj(path, CS.RPG.GameCore.GameCoreConfigLoader.LoadLevelGraphConfig)
				end
			end
		end
	end, function (err) write_log("error at: ".. pathValue .. " with error: " .. tostring(err) .. "\n") end)

	if data_object ~= nil then
		local values = string_split(pathValue, "/")
		local out_file = OUTPUT_FOLDER .. pathValue
		local out_folder = string.gsub(out_file, values[#values], "")
		if not CS.System.IO.Directory.Exists(out_folder) then
			CS.System.IO.Directory.CreateDirectory(out_folder);
		end
		local swriter = CS.System.IO.StreamWriter(out_file)
		local jwriter = CS.Newtonsoft.Json.JsonTextWriter(swriter)
		serializer:Serialize(jwriter, data_object)
		jwriter:Close()
		swriter:Close()
	end
end

local function dump_from_performances(table_class)
	local enumerator = table_class:GetEnumerator()
	while enumerator:MoveNext() do
		local value = get_enumerator_value(enumerator)
		write_data_obj(value.PerformancePath, CS.RPG.GameCore.GameCoreConfigLoader.LoadLevelGraphConfig)
	end
end

local dump = function()
	local enumerator = CS.RPG.GameCore.MainMissionExcelTable:GetEnumerator()
	while enumerator:MoveNext() do
		local value = get_enumerator_value(enumerator)
		local id = value.MainMissionID
		local pathValue = "Config/Level/Mission/" .. id .. "/MissionInfo_" .. id .. ".json" --  value.PerformancePath --
		write_data_obj(pathValue, CS.RPG.GameCore.GameCoreConfigLoader.LoadMainMissionInfoConfig)
	end

	dump_from_performances(CS.RPG.GameCore.PerformanceAExcelTable)
	dump_from_performances(CS.RPG.GameCore.PerformanceCExcelTable)
	dump_from_performances(CS.RPG.GameCore.PerformanceDExcelTable)
	dump_from_performances(CS.RPG.GameCore.PerformanceVideoExcelTable)

	 -- TODO: FIX
	dump_from_performances(CS.RPG.GameCore.PerformanceEExcelTable)

	log_writer:Close()
end

xpcall(dump, on_error)
