#![feature(str_from_utf16_endian)]
#![feature(let_chains)]
#![allow(non_snake_case)]

mod util;
mod interceptor;
mod modules;
mod xluau;

use std::sync::RwLock;
use std::thread;
use std::time::Duration;
use lazy_static::lazy_static;
use windows::core::s;
use windows::Win32::Foundation::HINSTANCE;
use windows::Win32::System::Console;
use windows::Win32::System::LibraryLoader::{GetModuleHandleA, GetProcAddress};
use windows::Win32::System::SystemServices::DLL_PROCESS_ATTACH;
use winapi::um::processthreadsapi::{GetCurrentThread, TerminateThread};
use common::config::Config;
use crate::modules::{MhyContext, ModuleManager, XLuaU};

#[no_mangle]
#[allow(non_snake_case, unused_variables)]
extern "cdecl" fn Initialize() -> bool {
    thread::sleep(Duration::from_secs(2));
    let thread = unsafe { GetCurrentThread() };
    unsafe { TerminateThread(thread, 0) };
    false
}

unsafe fn thread_func() {
    Config::inst().init();

    // Get base address
    let base = loop {
        if let Some(base) = util::try_get_base_address("GameAssembly.dll") {
            break base;
        }
        thread::sleep(Duration::from_millis(500));
    };

    Console::AllocConsole().unwrap_or(());

    println!("Module base: {base}");
    util::detect_version();

    // Init module manager
    let mut module_manager = MODULE_MANAGER.write().unwrap();

    // Disable VMProtect
    println!("Disabling VMP...");
    util::disable_memprotect_guard();
    println!("VMP has been disabled\n");

    // Wait until xluau.dll being loaded
    let luau_load = loop {
        match GetModuleHandleA(s!("xluau.dll")) {
            Ok(module) => {
                break GetProcAddress(module, s!("luau_load")).unwrap() as usize;
            },
            Err(_) => thread::sleep(Duration::from_millis(500)),
        }
    };
    println!("Hooking into XLuaU Load...");
    module_manager.enable(MhyContext::<XLuaU>::new(luau_load));
    println!("XLuaU Load function has been hooked\n");

    println!("Successfully initialized");
}

lazy_static! {
    static ref MODULE_MANAGER: RwLock<ModuleManager> = RwLock::new(ModuleManager::default());
}

#[no_mangle]
unsafe extern "system" fn DllMain(_: HINSTANCE, call_reason: u32, _: *mut ()) -> bool {
    if call_reason == DLL_PROCESS_ATTACH {
        thread::spawn(|| thread_func());
    }

    true
}
