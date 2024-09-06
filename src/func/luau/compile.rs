use std::fs;
use std::path::Path;
use windows::{core::PCWSTR, Win32::System::LibraryLoader::GetModuleHandleW};

use crate::util::wide_str;
use crate::GLOBAL_CONFIG;

const LUAU_COMPILE: usize = 0x000A3A60;

type LuauCompile = unsafe extern "fastcall" fn(
    source: *const std::ffi::c_char,
    size: usize,
    options: *const std::ffi::c_void,
    outsize: *mut usize,
) -> *const std::ffi::c_char;

pub unsafe fn compile(script: String, file_name: &str) -> Vec<u8> {
    let luau_compile = std::mem::transmute::<usize, LuauCompile>(xluau_base() + LUAU_COMPILE);
    let mut bytecode_size = 0;
    let bytecode = luau_compile(
        script.as_bytes().as_ptr() as *const i8,
        script.len(),
        std::ptr::null(),
        &mut bytecode_size,
    );
    let bytecode_vec = Vec::from_raw_parts(bytecode as *mut u8, bytecode_size, bytecode_size);

    // Save luauc script
    if GLOBAL_CONFIG.enable_luauc_dump && GLOBAL_CONFIG.only_chunk {
        let dump_path = &GLOBAL_CONFIG.luauc_dump_path;
        let compiled_file_name = format!("{}.luauc", file_name);
        let full_path = Path::new(dump_path).join(compiled_file_name);

        if let Some(parent_dir) = full_path.parent() {
            let _ = fs::create_dir_all(parent_dir);
        }

        if let Err(e) = fs::write(&full_path, &bytecode_vec) {
            println!("[Luau] Failed to save bytecode to {}: {}", full_path.display(), e);
        } else {
            println!("[Luau] Bytecode saved to {}", full_path.display());
        }
    }
    bytecode_vec
}

unsafe fn xluau_base() -> usize {
    GetModuleHandleW(PCWSTR::from_raw(wide_str("xluau.dll").as_ptr()))
        .unwrap()
        .0 as usize
}
