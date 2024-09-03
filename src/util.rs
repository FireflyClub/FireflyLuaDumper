use core::iter::once;
use std::ffi::{c_void, OsStr};

use std::os::windows::ffi::OsStrExt;
use std::time::{SystemTime, UNIX_EPOCH};
use windows::core::{PCSTR, PCWSTR};
use windows::Win32::System::LibraryLoader::{GetModuleHandleW, GetProcAddress};
use windows::Win32::System::Memory::{
    VirtualProtect, PAGE_EXECUTE_READWRITE, PAGE_PROTECTION_FLAGS,
};
use windows::Win32::System::ProcessStatus::{GetModuleInformation, MODULEINFO};
use windows::Win32::System::Threading::GetCurrentProcess;

pub unsafe fn read_csharp_string(addr: u64) -> String {
    let str_length = *(addr.wrapping_add(16) as *const u32);
    let str_ptr = addr.wrapping_add(20) as *const u8;
    let slice = std::slice::from_raw_parts(str_ptr as *const u8, (str_length * 2) as usize);
    String::from_utf16le(slice).unwrap()
}

pub fn wide_str(value: &str) -> Vec<u16> {
    OsStr::new(value).encode_wide().chain(once(0)).collect()
}

/// returns (module_base_ptr, module_size)
pub unsafe fn try_get_base_address(module_name: &str) -> Option<(usize, usize)> {
    let w_module_name = wide_str(module_name);

    match GetModuleHandleW(PCWSTR::from_raw(w_module_name.as_ptr())) {
        Ok(module) => {
            let mut module_info = MODULEINFO {
                lpBaseOfDll: std::ptr::null_mut(),
                SizeOfImage: 0,
                EntryPoint: std::ptr::null_mut(),
            };

            GetModuleInformation(
                GetCurrentProcess(),
                module,
                &mut module_info,
                std::mem::size_of::<MODULEINFO>() as u32,
            )
            .unwrap();

            Some((module.0 as usize, module_info.SizeOfImage as usize))
        }
        Err(_) => None,
    }
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
    let nt_query = GetProcAddress(
        ntdll,
        PCSTR::from_raw(c"NtQuerySection".to_bytes_with_nul().as_ptr()),
    )
    .unwrap();

    let mut old_prot = PAGE_PROTECTION_FLAGS(0);
    VirtualProtect(
        proc_addr as *const usize as *mut c_void,
        1,
        PAGE_EXECUTE_READWRITE,
        &mut old_prot,
    )
    .unwrap();

    let routine = nt_query as *mut u32;
    let routine_val = *(routine as *const usize);

    let lower_bits_mask = !(0xFFu64 << 32);
    let lower_bits = routine_val & lower_bits_mask as usize;

    let offset_val = *((routine as usize + 4) as *const u32);
    let upper_bits = ((offset_val as usize).wrapping_sub(1) as usize) << 32;

    let result = lower_bits | upper_bits;

    *(proc_addr as *mut usize) = result;

    VirtualProtect(
        proc_addr as *const usize as *mut c_void,
        1,
        old_prot,
        &mut old_prot,
    )
    .unwrap();
}

#[allow(unused)]
pub fn cur_timestamp_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_millis() as u64
}

pub fn get_game_version() -> anyhow::Result<String> {
    let binary_config = std::fs::read("StarRail_Data/StreamingAssets/BinaryVersion.bytes")?;
    let (mut start, mut end) = (None, None);

    for (i, &byte) in binary_config.iter().enumerate().rev() {
        if byte == b'-' {
            if end.is_none() {
                end = Some(i);
            } else {
                start = Some(i + 1);
                break;
            }
        }
    }

    match (start, end) {
        (Some(start), Some(end)) if start < end => {
            let version_bytes = &binary_config[start..end];
            Ok(String::from_utf8(version_bytes.to_vec())?)
        }
        _ => Err(anyhow::anyhow!("Failed to extract game version")),
    }
}
