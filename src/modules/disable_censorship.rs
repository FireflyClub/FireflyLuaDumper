use std::ptr;

use crate::GLOBAL_CONFIG;

use super::{MhyContext, MhyModule, ModuleType};
use anyhow::Result;
use windows::Win32::System::Memory::{
    VirtualProtect, PAGE_EXECUTE_READWRITE, PAGE_PROTECTION_FLAGS,
};

pub struct DisableCensorship;

impl MhyModule for MhyContext<DisableCensorship> {
    unsafe fn init(&mut self) -> Result<()> {
        let offset = GLOBAL_CONFIG.get_offset();

        let mut old_protect = PAGE_PROTECTION_FLAGS(0);
        VirtualProtect(
            (self.assembly_base + offset.set_elevation_dither_alpha_value) as *mut _,
            1,
            PAGE_EXECUTE_READWRITE,
            &mut old_protect,
        )
        .unwrap();
        ptr::write(
            (self.assembly_base + offset.set_elevation_dither_alpha_value) as *mut u8,
            0xC3,
        );

        let mut old_protect = PAGE_PROTECTION_FLAGS(0);
        VirtualProtect(
            (self.assembly_base + offset.set_distance_dither_alpha_value) as *mut _,
            1,
            PAGE_EXECUTE_READWRITE,
            &mut old_protect,
        )
        .unwrap();
        ptr::write(
            (self.assembly_base + offset.set_distance_dither_alpha_value) as *mut u8,
            0xC3,
        );

        let mut old_protect = PAGE_PROTECTION_FLAGS(0);
        VirtualProtect(
            (self.assembly_base + offset.set_dither_alpha_value) as *mut _,
            1,
            PAGE_EXECUTE_READWRITE,
            &mut old_protect,
        )
        .unwrap();
        ptr::write(
            (self.assembly_base + offset.set_dither_alpha_value) as *mut u8,
            0xC3,
        );

        let mut old_protect = PAGE_PROTECTION_FLAGS(0);
        VirtualProtect(
            (self.assembly_base + offset.set_dither_alpha_value_with_animation) as *mut _,
            1,
            PAGE_EXECUTE_READWRITE,
            &mut old_protect,
        )
        .unwrap();
        ptr::write(
            (self.assembly_base + offset.set_dither_alpha_value_with_animation) as *mut u8,
            0xC3,
        );

        println!("[DisableCensorship] Censorship disabled");

        Ok(())
    }

    unsafe fn de_init(&mut self) -> Result<()> {
        Ok(())
    }

    fn get_module_type(&self) -> super::ModuleType {
        ModuleType::DisableCensorship
    }
}
