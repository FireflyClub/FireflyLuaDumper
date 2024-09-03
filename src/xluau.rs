use windows::{core::PCWSTR, Win32::System::LibraryLoader::GetModuleHandleW};

use crate::util::wide_str;

const LUAU_COMPILE: usize = 0x000A3A60;

type LuauCompile = unsafe extern "fastcall" fn(
    source: *const std::ffi::c_char,
    size: usize,
    options: *const std::ffi::c_void,
    outsize: *mut usize,
) -> *const std::ffi::c_char;

pub unsafe fn luau_compile(script: String) -> &'static [u8] {
    let luau_compile = std::mem::transmute::<usize, LuauCompile>(xluau_base() + LUAU_COMPILE);
    let mut bytecode_size = 0;
    let bytecode = luau_compile(
        script.as_bytes().as_ptr() as *const i8,
        script.len(),
        std::ptr::null(),
        &mut bytecode_size,
    );
    std::slice::from_raw_parts(bytecode as *const u8, bytecode_size)
}

unsafe fn xluau_base() -> usize {
    GetModuleHandleW(PCWSTR::from_raw(wide_str("xluau.dll").as_ptr()))
        .unwrap()
        .0 as usize
}
