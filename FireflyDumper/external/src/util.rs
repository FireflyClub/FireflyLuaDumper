use core::iter::once;
use std::ffi::{c_void, CStr, OsStr};

use std::os::windows::ffi::OsStrExt;
use windows::Win32::System::LibraryLoader::{GetProcAddress, GetModuleHandleW, GetModuleFileNameW};
use windows::Win32::System::Memory::{PAGE_EXECUTE_READWRITE, PAGE_PROTECTION_FLAGS, VirtualProtect};
use windows::core::{PCSTR, PCWSTR};

#[allow(dead_code)]
type MarshalPtrToStringAnsi = unsafe extern "fastcall" fn(*const u8) -> *const u8;

pub fn wide_str(value: &str) -> Vec<u16> {
    OsStr::new(value).encode_wide().chain(once(0)).collect()
}

pub unsafe fn try_get_base_address(module_name: &str) -> Option<usize> {
    let w_module_name = wide_str(module_name);
    match GetModuleHandleW(PCWSTR::from_raw(w_module_name.as_ptr())) {
        Ok(module) => Some(module.0 as usize),
        Err(_) => None
    }
}

pub unsafe fn get_module_file_name(module_name: &str) -> String {
    let w_module_name = wide_str(module_name);
    match GetModuleHandleW(PCWSTR::from_raw(w_module_name.as_ptr())) {
        Ok(hmodule) => {
            const LEN: usize = 128;
            let mut buf: [u16; LEN] = [0; LEN];
            GetModuleFileNameW(hmodule, &mut buf);
            let mut vec = buf.to_vec();
            vec.retain(|&x| x > 0);
            let filename = String::from_utf16(&vec).unwrap();
            return filename;
        },
        Err(_) => String::from("")
    }
}

pub unsafe fn detect_version() {
    let file = get_module_file_name("UnityPlayer.dll");
    let vec = std::fs::read(&file).unwrap();
    let content = String::from_utf8_lossy(&vec);
    let mut version: String = String::from("");
    if content.contains("OSBETAWin") || content.contains("CNBETAWin") {
        let index = content.find("BETAWin").unwrap();
        version = content[index-2..index+13].to_string();
    } else if content.contains(&*"CNPRODWin") || content.contains(&*"OSPRODWin") {
        let index = content.find("RELWin").unwrap();
        version = content[index-2..index+12].to_string();
    }
    println!("Detected version: {}", version);
}

// VMProtect hooks NtProtectVirtualMemory to prevent changing protection of executable segments
// We use this trick to remove hook
pub unsafe fn disable_memprotect_guard() {
    let ntdll = wide_str("ntdll.dll");
    let ntdll = GetModuleHandleW(PCWSTR::from_raw(ntdll.as_ptr())).unwrap();
    let proc_addr = GetProcAddress(
        ntdll,
        PCSTR::from_raw(c"NtProtectVirtualMemory".to_bytes_with_nul().as_ptr()),
    )
    .unwrap();
    let nt_query = GetProcAddress(ntdll, PCSTR::from_raw(c"NtQuerySection".to_bytes_with_nul().as_ptr())).unwrap();

    let mut old_prot = PAGE_PROTECTION_FLAGS(0);
    VirtualProtect(
        proc_addr as *const usize as *mut c_void,
        1,
        PAGE_EXECUTE_READWRITE,
        &mut old_prot,
    ).unwrap();

    let routine = nt_query as *mut u32;
    let routine_val = *(routine as *const usize);

    let lower_bits_mask = !(0xFFu64 << 32);
    let lower_bits = routine_val & lower_bits_mask as usize;

    let offset_val = *((routine as usize + 4) as *const u32);
    let upper_bits = ((offset_val as usize).wrapping_sub(1)) << 32;

    let result = lower_bits | upper_bits;

    *(proc_addr as *mut usize) = result;

    VirtualProtect(
        proc_addr as *const usize as *mut c_void,
        1,
        old_prot,
        &mut old_prot,
    ).unwrap();
}

#[allow(dead_code)]
pub unsafe fn ptr_to_string_ansi(base: usize, content: &CStr) -> *const u8 {
    let func = std::mem::transmute::<usize, MarshalPtrToStringAnsi>(
        base + 0x002E0AB0
    );
    func(content.to_bytes_with_nul().as_ptr())
}
