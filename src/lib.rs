#![feature(str_from_utf16_endian)]

use config::Config;
use dll_sideload::load_dlls;
use lazy_static::lazy_static;
use modules::{DisableCensorship, Http, ModuleManager, XLuaU};
use std::{sync::RwLock, thread, time::Duration};

use util::try_get_base_address;
use win_dbg_logger::output_debug_string;
use winapi::um::processthreadsapi::{GetCurrentThread, TerminateThread};
use windows::Win32::Foundation::HINSTANCE;
use windows::Win32::System::Console;
use windows::Win32::System::SystemServices::DLL_PROCESS_ATTACH;

mod config;
mod dll_sideload;
// mod il2cpp_api;
mod interceptor;
mod marshal;
mod modules;
mod util;
mod xluau;

use crate::modules::MhyContext;

#[no_mangle]
#[allow(non_snake_case, unused_variables)]
unsafe extern "cdecl" fn Initialize() -> bool {
    unsafe {
        output_debug_string("[AntiCheatEMU] Initialize");
        thread::sleep(std::time::Duration::from_secs(2));
        output_debug_string("[AntiCheatEMU] TerminateThread");
        let thread = GetCurrentThread();
        TerminateThread(thread, 0);
        output_debug_string("[AntiCheatEMU] TerminateThread failed");
        false
    }
}

unsafe fn thread_func() {
    let base = loop {
        if let Some(base) = try_get_base_address("GameAssembly.dll") {
            break base;
        }

        std::thread::sleep(Duration::from_millis(500));
    };

    util::disable_memprotect_guard();
    Console::AllocConsole().unwrap();

    println!("HSR proxy, censorship patch, and luau dumper/hooker made by amizing25");
    println!("GameAssembly: {:X}", base);

    let mut module_manager = MODULE_MANAGER.write().unwrap();

    load_dlls();

    if GLOBAL_CONFIG.enable_redirect {
        module_manager.enable(MhyContext::<Http>::new(base));
    }

    if GLOBAL_CONFIG.disable_censorship {
        module_manager.enable(MhyContext::<DisableCensorship>::new(base));
    }

    if GLOBAL_CONFIG.enable_luauc_inject || GLOBAL_CONFIG.enable_luauc_dump {
        module_manager.enable(MhyContext::<XLuaU>::new(base));
    }

    // module_manager.enable(MhyContext::<Il2Cpp>::new(base));

    println!("Successfully initialized!");
}

lazy_static! {
    static ref MODULE_MANAGER: RwLock<ModuleManager> = RwLock::new(ModuleManager::default());
    static ref GLOBAL_CONFIG: Config = Config::new().unwrap();
}

#[no_mangle]
unsafe extern "system" fn DllMain(_: HINSTANCE, call_reason: u32, _: *mut ()) -> bool {
    if call_reason == DLL_PROCESS_ATTACH {
        std::thread::spawn(|| thread_func());
    }

    true
}
