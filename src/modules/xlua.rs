use super::{MhyContext, MhyModule, ModuleType};
use super::luau_compile::compile;
use crate::{util::wide_str, GLOBAL_CONFIG};
use ilhook::x64::Registers;
use std::{
    ffi::CStr,
    fs,
    ptr::{self},
};
use windows::{
    core::{PCSTR, PCWSTR},
    Win32::System::{
        LibraryLoader::{GetModuleHandleW, GetProcAddress},
        Memory::{
            VirtualAlloc, VirtualProtect, MEM_COMMIT, MEM_RESERVE, PAGE_EXECUTE_READWRITE,
            PAGE_PROTECTION_FLAGS, PAGE_READWRITE,
        },
    },
};

#[allow(non_camel_case_types)]
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct lua_State {
    _unused: [u8; 0],
}

//
///  ```int luau_load(lua_State* L, const char* chunkname, const char* data, size_t size, int env)```
///
///
///  ```__int64 __fastcall luau_load(_QWORD *a1, __int64 a2, unsigned __int8 *a3, int a4, unsigned int a5)```
///
pub type LuaULoad = unsafe extern "fastcall" fn(
    *mut lua_State,
    *const ::std::os::raw::c_char,
    *const ::std::os::raw::c_char,
    usize,
    ::std::os::raw::c_int,
) -> ::std::os::raw::c_int;

pub struct XLuaU;

impl MhyModule for MhyContext<XLuaU> {
    unsafe fn init(&mut self) -> anyhow::Result<()> {
        println!("[XLuaU] XLuaU module enabled.");

        self.interceptor
            .replace(xluau_base(), luau_load_replacement)
    }

    unsafe fn de_init(&mut self) -> anyhow::Result<()> {
        Ok(())
    }

    fn get_module_type(&self) -> super::ModuleType {
        ModuleType::XLua
    }
}

unsafe extern "win64" fn luau_load_replacement(
    reg: *mut Registers,
    actual_func: usize,
    _: usize,
) -> usize {
    let luau_load = std::mem::transmute::<usize, LuaULoad>(actual_func);

    let lua_state_ptr = (*reg).rcx as *mut lua_State;
    let chunkname_ptr = (*reg).rdx as *const ::std::os::raw::c_char;
    let data_ptr = (*reg).r8 as *const ::std::os::raw::c_char;
    let size = (*reg).r9 as usize;
    let env = 0; // (*reg).r10 as usize; // always 0 for now

    let chunkname = CStr::from_ptr(chunkname_ptr);

    // dump the scripts
    if GLOBAL_CONFIG.enable_luauc_dump {
        println!(
            "lua_state_ptr: {:#?} | chunkname: {:#?} | data_ptr: {:#?} | size: {:#?} | env: {:#?}",
            lua_state_ptr, chunkname, data_ptr, size, env
        );

        let buffer: &[u8] = std::slice::from_raw_parts(data_ptr as *const u8, size);
        let full_path = format!(
            "{}\\{}",
            GLOBAL_CONFIG.luauc_dump_path,
            chunkname.to_str().unwrap()
        );
        let path = std::path::Path::new(&full_path);

        if let Some(parent_dir) = path.parent() {
            let _ = fs::create_dir_all(parent_dir.to_str().unwrap());
        }

        std::fs::write(
            format!(
                "{}.{}",
                path.to_str().unwrap(),
                crate::util::cur_timestamp_ms()
            ),
            buffer,
        )
        .unwrap();
    }

    if GLOBAL_CONFIG.enable_luauc_inject
        && chunkname.to_str().unwrap() == "@BakedLua/Ui/GameStartup/LoginAgeHintBinder.bytes"
    {
        let Ok(file) = fs::read_to_string(GLOBAL_CONFIG.luauc_inject_path.clone()) else {
            println!("[XLuaU] luauc is enabled but no lua script was found. skipping script injection.");
            return luau_load(lua_state_ptr, chunkname_ptr, data_ptr, size, env) as usize;
        };

        let replacement = compile(file);
        let length = replacement.len();

        let ptr = VirtualAlloc(
            Some(ptr::null_mut()),
            length,
            MEM_COMMIT | MEM_RESERVE,
            PAGE_READWRITE,
        ) as *mut u8;

        if ptr.is_null() {
            panic!("Failed to allocate memory");
        }

        ptr.copy_from_nonoverlapping(replacement.as_ptr(), length);

        let mut old_protect = PAGE_PROTECTION_FLAGS(0);
        VirtualProtect(
            ptr as *mut _,
            length,
            PAGE_EXECUTE_READWRITE,
            &mut old_protect,
        )
        .unwrap();

        let result = std::slice::from_raw_parts(ptr, length);
        println!("[XLuaU] Custom scripts injected");

        return luau_load(
            lua_state_ptr,
            chunkname_ptr,
            result.as_ptr() as *const i8,
            result.len(),
            0,
        ) as usize;
    };

    luau_load(lua_state_ptr, chunkname_ptr, data_ptr, size, env) as usize
}

unsafe fn xluau_base() -> usize {
    let dll = GetModuleHandleW(PCWSTR::from_raw(wide_str("xluau.dll").as_ptr())).unwrap();

    GetProcAddress(
        dll,
        PCSTR::from_raw(c"luau_load".to_bytes_with_nul().as_ptr()),
    )
    .unwrap() as usize
}
