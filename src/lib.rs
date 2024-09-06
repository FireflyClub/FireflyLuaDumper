#![feature(str_from_utf16_endian, let_chains)]

use win_dbg_logger::output_debug_string;
use winapi::um::processthreadsapi::{GetCurrentThread, TerminateThread};
use windows::Win32::Foundation::HINSTANCE;
use windows::Win32::System::Console;
use windows::Win32::System::SystemServices::DLL_PROCESS_ATTACH;
use lazy_static::lazy_static;
use std::{sync::RwLock, thread, time::Duration};

use config::Config;
use manager::{MhyContext, ModuleManager};
use util::try_get_base_address;
use func::{DisableCensorship, Http, DllSideload, Il2CppApiBridge};
use func::luau::Luau;
use func::unity::api::init_il2cpp_api_wrapper;
use func::unity::rva_dumper::dump_offset_and_rva;

mod config;
mod interceptor;
mod marshal;
mod func;
mod util;
mod manager;

#[no_mangle]
#[allow(non_snake_case, unused_variables)]
extern "cdecl" fn Initialize() -> bool {
    output_debug_string("[Init] Initialize");
    thread::sleep(Duration::from_secs(2));
    output_debug_string("[Init] TerminateThread");
    let thread = unsafe { GetCurrentThread() };
    unsafe { TerminateThread(thread, 0) };
    output_debug_string("[Init] TerminateThread failed");
    false
}

unsafe fn thread_func() {
    let base = loop {
        if let Some(base) = try_get_base_address("GameAssembly.dll") {
            break base;
        }
        thread::sleep(Duration::from_millis(500));
    };

    util::disable_memprotect_guard();
    Console::AllocConsole().unwrap();

    println!(r#"
        _           _      _                 __  _          _    _         
       /_\   _ __  (_) ___(_) _ _   __ _    / / | |    ___ | |_ | |_   ___ 
      / _ \ | '  \ | ||_ /| || ' \ / _` |  / /  | |__ / -_)|  _|| ' \ / -_)
     /_/ \_\|_|_|_||_|/__||_||_||_|\__, | /_/   |____|\___| \__||_||_|\___|
                                   |___/                                   
    "#);
    println!("[GameAssembly] GameAssembly: {:X}", base.0);

    let mut module_manager = MODULE_MANAGER.write().unwrap();

    module_manager.enable(MhyContext::<DllSideload>::new(base.0));

    if GLOBAL_CONFIG.hook_il2cpp {
        init_il2cpp_api_wrapper().unwrap();
        dump_offset_and_rva().unwrap();
        module_manager.enable(MhyContext::<Il2CppApiBridge>::new(base.0))
    }

    if GLOBAL_CONFIG.enable_redirect {
        module_manager.enable(MhyContext::<Http>::new(base.0));
    }

    if GLOBAL_CONFIG.disable_censorship {
        module_manager.enable(MhyContext::<DisableCensorship>::new(base.0));
    }

    if GLOBAL_CONFIG.enable_luauc_inject || GLOBAL_CONFIG.enable_luauc_dump {
        module_manager.enable(MhyContext::<Luau>::new(base.0));
    }

    println!("[Init] Successfully initialized!");
}

lazy_static! {
    static ref MODULE_MANAGER: RwLock<ModuleManager> = RwLock::new(ModuleManager::default());
    static ref GLOBAL_CONFIG: Config = load_config();
}

fn load_config() -> Config {
    match Config::new() {
        Ok(config) => config,
        Err(_) => {
            match serde_json::from_str(config::DEFAULT_CONFIG) {
                Ok(default_config) => {
                    default_config
                }
                Err(_) => {
                    Config::default()
                }
            }
        }
    }
}

#[no_mangle]
unsafe extern "system" fn DllMain(_: HINSTANCE, call_reason: u32, _: *mut ()) -> bool {
    if call_reason == DLL_PROCESS_ATTACH {
        thread::spawn(|| thread_func());
    }
    true
}
