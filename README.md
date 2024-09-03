# hkrpg-patch

## Features

- Redirect Http Requests
- Disable Censorship
- Dll Sideload
- Luau Injector (Tested on > 2.4.0)
- Luau Dump
- Il2Cpp Hook

## Handbook

### Step 1: Dll Install

- Replace ```mhypbase.dll``` to the .dll file in StarRail's folder.
- This project will generate ```config.json``` automatically when the game is launched for the first time.

### Step 2: Configure ```config.json```

```js
{
    "enable_redirect": true,                             // Enable http request redirect
    "redirect_url": "http://127.0.0.1:619",              // Your http-server url
    "disable_censorship": true,                          // Disable censorship (R18 SUPPORT)
    "enable_luauc_inject": false,                        // Inject .lua/.luauc script
    "luauc_inject_path": "",                             // Your script path
    "hook_il2cpp": false,                                // Hook il2cpp (For dump.cs)
    "enable_luauc_dump": false,                          // Dump runtime .luauc to file
    "only_chunk": false,                                 // Only dump chunk.luauc (Suspect be the compiled script)
    "luauc_dump_path": "./luauc",                        // Your dump path
    "dll_sideloads": [],                                 // Sideload dlls
    "offsets": {                                         // Offsets for hook functions
        "{VERSION}": {                                   // Your StarRail game version
            "web_request_utils_make_initial_url": "",    // For http request redirect
            "to_string_ansi": "",
            "set_elevation_dither_alpha_value": "",
            "set_distance_dither_alpha_value": "",
            "set_dither_alpha_value": "",
            "set_dither_alpha_value_with_animation": "",
                                                         // For dump.cs
            "mhy_sdk_sdkutil_rsaencrypt": "",
            "il2cpp_domain_get": "",
            "il2cpp_domain_get_assemblies": "",
            "il2cpp_assembly_get_image": "",
            "il2cpp_image_get_class_count": "",
            "il2cpp_image_get_class": "",
            "il2cpp_class_get_methods": "",
            "il2cpp_class_get_name": "",
            "il2cpp_method_get_name": "",
            "il2cpp_image_get_name": "",
            "il2cpp_field_get_name": "",
            "il2cpp_field_get_offset": "",
            "il2cpp_class_get_fields": ""
        }
    }
}
```

## References

- [JaneDoe-Patch](https://git.xeondev.com/NewEriduPubSec/JaneDoe-Patch)
- [zzz-patch-loader](https://github.com/oureveryday/zzz-patch-loader)
- [0.64-client-patch](https://git.xeondev.com/xeon/0.64-client-patch)
