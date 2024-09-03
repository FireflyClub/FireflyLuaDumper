use std::ffi::CString;
use anyhow::Result;
use ilhook::x64::Registers;

use crate::manager::{MhyContext, MhyModule, ModuleType};
use crate::{marshal, util::read_csharp_string, GLOBAL_CONFIG};

pub struct Http;

impl MhyModule for MhyContext<Http> {
    unsafe fn init(&mut self) -> Result<()> {
        println!("[HTTP] HTTP module enabled.");
        self.interceptor.attach(
            self.assembly_base
                + GLOBAL_CONFIG
                    .get_offset()
                    .web_request_utils_make_initial_url,
            on_webrequtils_make_initial_url,
        )
    }

    unsafe fn de_init(&mut self) -> Result<()> {
        Ok(())
    }

    fn get_module_type(&self) -> ModuleType {
        ModuleType::Http
    }
}

unsafe extern "win64" fn on_webrequtils_make_initial_url(reg: *mut Registers, _: usize) {
    let url = read_csharp_string((*reg).rcx);

    let mut new_url = String::from(&GLOBAL_CONFIG.redirect_url);
    url.split('/').skip(3).for_each(|s| {
        new_url.push_str("/");
        new_url.push_str(s);
    });

    println!("[HTTP] MakeInitialUrl(\"{url}\"), replacing with {new_url}");
    (*reg).rcx =
        marshal::ptr_to_string_ansi(CString::new(new_url.as_str()).unwrap().as_c_str()) as u64;
}
