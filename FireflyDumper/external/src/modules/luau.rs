use ilhook::x64::Registers;
use std::{ffi::CStr, fs, ptr::self, path::Path, borrow::Cow, os::raw::{c_int, c_char}};
use std::ffi::CString;
use windows::{
    Win32::System::{
        Memory::{
            VirtualAlloc, VirtualProtect, MEM_COMMIT, MEM_RESERVE, PAGE_EXECUTE_READWRITE,
            PAGE_PROTECTION_FLAGS, PAGE_READWRITE,
        },
    },
};
use windows::core::s;
use windows::Win32::System::LibraryLoader::{GetModuleHandleA, GetProcAddress};
use common::config::Config;

use crate::modules::{MhyContext, MhyModule, ModuleType};
use crate::xluau;
use crate::xluau::{LUA_PCALL_ADDR, XLUAL_LOADBUFFER_ADDR};

pub struct XLuaU;

impl MhyModule for MhyContext<XLuaU> {
    unsafe fn init(&mut self) -> anyhow::Result<()> {
        self.interceptor.replace(self.assembly_base, luau_load_replacement)
    }

    unsafe fn de_init(&mut self) -> anyhow::Result<()> {
        Ok(())
    }

    fn get_module_type(&self) -> ModuleType {
        ModuleType::LuaU
    }
}

unsafe extern "win64" fn luau_load_replacement(
    reg: *mut Registers,
    luau_load_addr: usize,
    _: usize,
) -> usize {
    // luau_load function
    let luau_load = std::mem::transmute::<usize, xluau::LuaULoad>(luau_load_addr);

    // Retrieve original data
    let lua_state_ptr = (*reg).rcx as *mut xluau::lua_State;
    let chunkname_ptr = (*reg).rdx as *const c_char;
    let data_ptr = (*reg).r8 as *const c_char;
    let size = (*reg).r9 as usize;
    let chunkname = CStr::from_ptr(chunkname_ptr).to_str().unwrap();

    if chunkname == "@BakedLua/Ui/GameStartup/GameStartupMainPageBinder.bytes" {
        // xluau.dll module
        let module = GetModuleHandleA(s!("xluau.dll")).unwrap();

        // xluaL_loadbuffer function
        XLUAL_LOADBUFFER_ADDR = GetProcAddress(module, s!("xluaL_loadbuffer"))
            .unwrap() as usize;
        println!("Function xluaL_loadbuffer: 0x{:X}", XLUAL_LOADBUFFER_ADDR - module.0 as usize);

        // lua_pcall function
        LUA_PCALL_ADDR = GetProcAddress(module, s!("lua_pcall")).unwrap() as usize;
        println!("Function lua_pcall: 0x{:X}\n", LUA_PCALL_ADDR - module.0 as usize);
    }

    // Inject the script
    if chunkname == "@BakedLua/Ui/GameStartup/LoginAgeHintBinder.bytes" {
        for lua_file in &Config::inst().lua_files {
            let inject_path = Path::new(lua_file);

            let lua_name = lua_file.split("\\")
                .last()
                .unwrap()
                .split("/")
                .last()
                .unwrap();

            // Check file format & compile
            let valid_extensions = ["lua", "luac", "luauc"];
            let extension = inject_path.extension().and_then(|s| s.to_str());
            let replacement: Cow<[u8]> = if valid_extensions.contains(&extension.unwrap_or("")) {
                let Ok(bytecode) = fs::read(&inject_path) else {
                    println!("Script {lua_name} not found.");
                    continue
                };
                Cow::Owned(bytecode)
            } else {
                println!("{lua_name} is not valid Lua format.");
                continue
            };

            // Copy Lua bytecode as pointer
            let length = replacement.len();
            let ptr = VirtualAlloc(
                Some(ptr::null_mut()),
                length,
                MEM_COMMIT | MEM_RESERVE,
                PAGE_READWRITE,
            ) as *mut u8;

            if ptr.is_null() {
                panic!("Failed to allocate memory.");
            }
            ptr.copy_from_nonoverlapping(replacement.as_ptr(), length);

            let mut old_protect = PAGE_PROTECTION_FLAGS(0);
            VirtualProtect(
                ptr as *mut _,
                length,
                PAGE_EXECUTE_READWRITE,
                &mut old_protect,
            ).unwrap();

            let result = std::slice::from_raw_parts(ptr, length);
            println!("Loading Lua script {lua_name}");

            // Assign Lua script name
            let new_chunkname = CString::new("Lethe").unwrap();
            let new_chunkname_ptr = new_chunkname.as_c_str().as_ptr();

            // Call xluaL_loadbuffer
            let mut ret = xluau::xluaL_loadbuffer(
                lua_state_ptr,
                result.as_ptr() as *const i8,
                result.len(),
                new_chunkname_ptr,
            );
            if (ret as usize) != 0 {
                println!("Failed to load Lua script {lua_name}");
            }

            // Call lua_pcall
            ret = xluau::lua_pcall(
                lua_state_ptr,
                0 as *const c_int,
                0 as *const c_int,
                0 as *const c_int,
            );
            if (ret as usize) != 0 {
                println!("Failed to load Lua script {lua_name}");
            }

            // Post load logging
            println!("Lua script {lua_name} has been loaded\n");
        }
    };

    luau_load(lua_state_ptr, chunkname_ptr, data_ptr, size, 0) as usize
}
