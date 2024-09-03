use winapi::um::libloaderapi::LoadLibraryW;
use anyhow::Result;
use std::ptr;

use crate::GLOBAL_CONFIG;
use super::{MhyContext, MhyModule, ModuleType};

pub struct DllSideload;

impl MhyModule for MhyContext<DllSideload> {
    unsafe fn init(&mut self) -> Result<()> {
        println!("[DLLSideload] DllSideload module enabled.");
        load_dlls()?;
        Ok(())
    }

    unsafe fn de_init(&mut self) -> Result<()> {
        Ok(())
    }

    fn get_module_type(&self) -> super::ModuleType {
        ModuleType::DllSideload
    }
}

pub unsafe fn load_dlls() -> Result<()> {
    for dll_path in &GLOBAL_CONFIG.dll_sideloads {
        let lib_name_utf16: Vec<u16> = format!("{}\0", dll_path).encode_utf16().collect();
        if LoadLibraryW(lib_name_utf16.as_ptr()) == ptr::null_mut() {
            println!("[DLLSideload] Failed to inject custom DLL: {}", dll_path);
        } else {
            println!("[DLLSideload] Successfully injected custom DLL: {}", dll_path);
        }
    }
    Ok(())
}