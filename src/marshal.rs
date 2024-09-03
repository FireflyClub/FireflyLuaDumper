use std::ffi::CStr;

use crate::{util, GLOBAL_CONFIG};

type MarshalPtrToStringAnsi = unsafe extern "fastcall" fn(*const u8) -> *const u8;

pub unsafe fn ptr_to_string_ansi(content: &CStr) -> *const u8 {
    let func = std::mem::transmute::<usize, MarshalPtrToStringAnsi>(
        base() + GLOBAL_CONFIG.get_offset().to_string_ansi,
    );
    func(content.to_bytes_with_nul().as_ptr())
}

unsafe fn base() -> usize {
    util::try_get_base_address("GameAssembly.dll").unwrap().0
}
