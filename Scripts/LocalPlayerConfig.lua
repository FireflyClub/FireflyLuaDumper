local OUT_ROOT = "./DumpTest"
local OUT_PATH = OUT_ROOT .. "/"
local LOG_FILE = OUT_ROOT .. "/LogDumpLocalPlayerConfig.log"

local Dictionary = CS.System.Collections.Generic.Dictionary(CS.System.String, CS.System.Object)

local resetFields = {
    ["DynamicValues"] = "nil",
    ["postfixExpr"] = "nil",
    ["AITagList"] = "nil",
}

local serializer = CS.Newtonsoft.Json.JsonSerializer.CreateDefault()
    serializer.DefaultValueHandling = CS.Newtonsoft.Json.DefaultValueHandling.Ignore
    serializer.ReferenceLoopHandling = CS.Newtonsoft.Json.ReferenceLoopHandling.Ignore
    serializer.Formatting = CS.Newtonsoft.Json.Formatting.Indented
    serializer.MetadataPropertyHandling = CS.Newtonsoft.Json.MetadataPropertyHandling.Ignore
    serializer.Converters:Add(CS.Newtonsoft.Json.Converters.StringEnumConverter())
    serializer.NullValueHandling =  CS.Newtonsoft.Json.NullValueHandling.Ignore

local List = CS.System.Collections.Generic.List(CS.System.Object)

local flags = CS.System.Reflection.BindingFlags.Instance
            | CS.System.Reflection.BindingFlags.Static
            | CS.System.Reflection.BindingFlags.Public
            | CS.System.Reflection.BindingFlags.NonPublic


local log_writer = CS.System.IO.StreamWriter(LOG_FILE)

local function write_log(text)
    log_writer:WriteLine(text)
end
            

local on_error = function(error)
    local js = CS.Newtonsoft.Json.JsonConvert.SerializeObject(error)
    CS.RPG.Client.ConfirmDialogUtil.ShowCustomOkCancelHint("error: " .. js .. "\n")
end

local function string_split(str, pat)
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

local function write_json(path, data)
    local sw = CS.System.IO.StreamWriter(path)
    local jw = CS.Newtonsoft.Json.JsonTextWriter(sw)
    serializer:Serialize(jw, data)
    sw:Close()
    jw:Close()
end

local function findPrivateIEnumeratorCurrent(obj)
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

-- old method
local function parse_task(list)
    local arr = List()

    if list ~= nil then
        for i = 0, list.Length - 1 do
            local Dictionary = CS.System.Collections.Generic.Dictionary(CS.System.String, CS.System.Object)
            local dict = Dictionary()
            local task = list[i]
            local type = task:GetType():ToString();
  
            dict:Add("$type", type)
    
            if task.ID ~= nil then
                dict:Add("ID", task.ID)
            end
            if task.SummonUnitID ~= nil then
                dict:Add("SummonUnitID", task.SummonUnitID)
            end
    
            if task.TriggerBattle ~= nil then
                dict:Add("TriggerBattle", task.TriggerBattle)
            end
            if task.LifeTime ~= nil then
                local dict2 = Dictionary()
                dict2:Add("IsDynamic", task.LifeTime.IsDynamic)
                dict2:Add("FixedValue", task.LifeTime.FixedValue)
                dict:Add("LifeTime", dict2)
            end
            if task.ModifierName ~= nil then
                dict:Add("ModifierName", task.ModifierName)
            end
    
            if task.SuccessTaskList ~= nil then
                dict:Add("SuccessTaskList", parse_task(task.SuccessTaskList))
            end
            if task.OnAttack ~= nil then
                dict:Add("OnAttack", parse_task(task.OnAttack))
            end
            if task.OnBattle ~= nil then
                dict:Add("OnBattle", parse_task(task.OnBattle))
            end
            if task.OnProjectileHit ~= nil then
                dict:Add("OnProjectileHit", parse_task(task.OnProjectileHit))
            end
            if task.OnProjectileLifetimeFinish ~= nil then
                dict:Add("OnProjectileLifetimeFinish", parse_task(task.OnProjectileLifetimeFinish))
            end
    
            arr:Add(dict)
        end
    end

    return arr
end


local function parse(json)
    local dict1 = Dictionary()
    if json.AbilityList ~= nil then
        local arr = List()
        for i = 0, json.AbilityList.Length - 1 do
            local dict = Dictionary()
            local ability = json.AbilityList[i]
            local name = ability.Name
            dict:Add("Name", name)
            if ability.OnStart ~= nil then
                dict:Add("OnStart", parse_task(ability.OnStart))
            end
            arr:Add(dict)
        end
        dict1:Add("AbilityList", arr)
    end
    return dict1
end
-- end

local main_function = function()

    local adventureAbilityConfigPaths = {}
    local adventureCharacterConfigPaths = {}

    local adventureAbilityConfigPathsMap = List()
    local adventureCharacterConfigPathsMap = List()
    --local characterConfigPaths = {}
    --local entityLodLoadingPaths = {}

    local adventure_player_enumerator = CS.RPG.GameCore.AdventurePlayerExcelTable:GetEnumerator();
    while adventure_player_enumerator:MoveNext() do
        local adventure_player_excel = findPrivateIEnumeratorCurrent(adventure_player_enumerator)
        local local_player_name = string.gsub(adventure_player_excel.PlayerJsonPath, "ConfigCharacter","ConfigAdventureAbility"):gsub("_Config.json", "_Ability.json")
        table.insert(adventureAbilityConfigPaths, local_player_name)
        table.insert(adventureCharacterConfigPaths, adventure_player_excel.PlayerJsonPath)

        adventureAbilityConfigPathsMap:Add(local_player_name)
        adventureCharacterConfigPathsMap:Add(adventure_player_excel.PlayerJsonPath)
    end

    --local avatar_enumerator = CS.RPG.GameCore.AvatarExcelTable:GetEnumerator();
    --while avatar_enumerator:MoveNext() do
    --    local excel = findPrivateIEnumeratorCurrent(avatar_enumerator)
    --    table.insert(characterConfigPaths, excel.JsonPath)
    --end
    --
    --local story_character_enumerator = CS.RPG.GameCore.StoryCharacterExcelTable:GetEnumerator();
    --while story_character_enumerator:MoveNext() do
    --    local excel = findPrivateIEnumeratorCurrent(story_character_enumerator)
    --    table.insert(entityLodLoadingPaths, excel.ConfigEntityPath)
    --end
    --

    local PATHS = {
        ["LoadAdventureAbilityConfigList"] = adventureAbilityConfigPaths,
        --["LoadCharacterConfig"] = adventureCharacterConfigPaths,
        --["LoadAdventureCharacterConfig"] = characterConfigPaths,
        --["LoadEntityLodLoadingData"] = entityLodLoadingPaths,
    }

    for method, paths in pairs(PATHS) do
        for _, pathValue in pairs(paths) do
            if pathValue == "Config/ConfigAdventureAbility/LocalPlayer/LocalPlayer_Feixiao_00_Ability.json" then
                serializer.TypeNameHandling = CS.Newtonsoft.Json.TypeNameHandling.None
                local cfg = CS.RPG.GameCore.GameCoreConfigLoader.LoadAdventureAbilityConfigList("Config/ConfigAdventureAbility/LocalPlayer/LocalPlayer_Feixiao_00_Ability.json")
                write_json(OUT_PATH .. "Config/ConfigAdventureAbility/LocalPlayer/LocalPlayer_Feixiao_00_Ability.json", parse(cfg))
            else
                serializer.TypeNameHandling = CS.Newtonsoft.Json.TypeNameHandling.Auto
                local values = string_split(pathValue, "/")
                local out_file = OUT_PATH .. pathValue
                local out_folder = string.gsub(out_file, values[#values], "")
                if not CS.System.IO.Directory.Exists(out_folder) then
                    CS.System.IO.Directory.CreateDirectory(out_folder);
                end

                local cfg = nil
                if method == "LoadAdventureAbilityConfigList" then
                    cfg = CS.RPG.GameCore.GameCoreConfigLoader.LoadAdventureAbilityConfigList(pathValue)
                elseif method == "LoadCharacterConfig" then
                    --cfg = CS.RPG.GameCore.GameCoreConfigLoader.LoadCharacterConfig(pathValue)
                elseif method == "LoadAdventureCharacterConfig" then
                    --cfg = CS.RPG.GameCore.GameCoreConfigLoader.LoadAdventureCharacterConfig(pathValue)
                elseif method == "LoadEntityLodLoadingData" then
                    --cfg = CS.RPG.GameCore.GameCoreConfigLoader.LoadEntityLodLoadingData(pathValue)
                else
                    on_error("unknown method: " .. method .. "\n")
                end

                if cfg ~= nil then
                    xpcall(function()
                        reset_user_data(cfg)
                        write_json(out_file, cfg)
                    end, function(errmsg)
                        write_log("Err at " .. pathValue .. " With err: ".. tostring(errmsg))
                    end)
                end
            end

        end
    end

    log_writer:Close()
end

xpcall(main_function, on_error)
