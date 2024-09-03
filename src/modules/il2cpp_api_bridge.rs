use std::ffi::CString;

use ilhook::x64::Registers;

use crate::{
    marshal::ptr_to_string_ansi,
    unity::rva_dumper::{get_offset, get_rva},
    util::read_csharp_string,
    GLOBAL_CONFIG,
};

use super::{MhyContext, MhyModule};

const CLIENT_PUB_KEY: &str = "<RSAKeyValue>\r\n  <Exponent>AQAB</Exponent>\r\n  <Modulus>hEegnKISgDas5VTuRBUlixB+bvmPvXKa3kVO22UEZjPGMUFLmIl3DhH+dsZo7qJn/GfJCUkP1FA0MJ5Bj8PX8IatLJKIJ9dMCNdnAlkXTlMg86QQAhHZN83vP4swj5ILcrGNKl3YAZ49fvzo7nheuTt0/40f0HkHdNa1dUHECBs=</Modulus>\r\n</RSAKeyValue>";

pub type MhySdkSdkUtilRSAEncrypt =
    unsafe extern "fastcall" fn(pubkey: *const u8, content: *const u8) -> *const u8;

pub struct Il2CppApiBridge;

impl MhyModule for MhyContext<Il2CppApiBridge> {
    unsafe fn init(&mut self) -> anyhow::Result<()> {
        let rva = GLOBAL_CONFIG.get_offset().mhy_sdk_sdkutil_rsaencrypt;
        if rva == 0 {
            println!("[Il2CppApiBridge] mhy_sdk_sdkutil_rsaencrypt is empty, skipping hook");
            return Ok(());
        }
        println!("[Il2CppApiBridge] Hooked MHY_SDK_SDKUTIL_RSAENCRYPT");

        self.interceptor.replace(
            self.assembly_base + rva,
            mhy_sdk_sdkutil_rsa_encrypt_replacement,
        )
    }

    unsafe fn de_init(&mut self) -> anyhow::Result<()> {
        Ok(())
    }

    fn get_module_type(&self) -> super::ModuleType {
        super::ModuleType::Il2CppApiBridge
    }
}

pub unsafe extern "win64" fn mhy_sdk_sdkutil_rsa_encrypt_replacement(
    reg: *mut Registers,
    actual_func: usize,
    _: usize,
) -> usize {
    let func = std::mem::transmute::<usize, MhySdkSdkUtilRSAEncrypt>(actual_func);
    let pubkey_ptr = (*reg).rcx;
    let content_ptr = (*reg).rdx;

    let pubkey = read_csharp_string(pubkey_ptr);
    let content = read_csharp_string(content_ptr);
    let content_splitted = content.split("|").collect::<Vec<_>>();

    if pubkey == "get_rva" && content_splitted.len() == 3 {
        let rva = get_rva(&content);
        let content = CString::new(format!("0x{:X}", rva).as_str()).unwrap();
        return ptr_to_string_ansi(content.as_c_str()) as usize;
    } else if pubkey == "get_offset" && content_splitted.len() == 3 {
        let offset = get_offset(&content);
        let content = CString::new(format!("0x{:X}", offset).as_str()).unwrap();
        return ptr_to_string_ansi(content.as_c_str()) as usize;
    }

    func(
        ptr_to_string_ansi(CString::new(CLIENT_PUB_KEY).unwrap().as_c_str()),
        content_ptr as *const u8,
    ) as usize
}
