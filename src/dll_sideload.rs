use winapi::um::libloaderapi::LoadLibraryW;

use crate::GLOBAL_CONFIG;

pub unsafe fn load_dlls() {
    for dll_path in &GLOBAL_CONFIG.dll_sideloads {
        let lib_name_utf16: Vec<u16> = format!("{dll_path}\0").encode_utf16().collect();
        LoadLibraryW(lib_name_utf16.as_ptr());
        println!("[DLL Sideload] Injected custom DLL: {dll_path}");
    }
}