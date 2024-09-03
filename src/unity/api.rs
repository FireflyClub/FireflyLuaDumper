use crate::util::try_get_base_address;

use super::{functions::Il2CppFunctions, rva_dumper::init_dumper_map, MethodInfo};
use anyhow::Result;
use std::{
    error::Error,
    ffi::{c_char, c_void, CStr},
};

pub struct Il2CppApiWrapper {
    pub game_assembly: (usize, usize),
    pub functions: Il2CppFunctions,
}

impl Il2CppApiWrapper {
    pub unsafe fn new() -> Result<Self> {
        let game_assembly = try_get_base_address("GameAssembly.dll").unwrap();
        let unity_player = try_get_base_address("UnityPlayer.dll").unwrap();
        let functions = Il2CppFunctions::new(unity_player.0);

        Ok(Il2CppApiWrapper {
            game_assembly,
            functions,
        })
    }

    fn to_string(native: *const c_char) -> String {
        let str = unsafe { CStr::from_ptr(native) };
        str.to_str().unwrap().to_string()
    }

    pub fn domain_get(&self) -> Result<*const c_void> {
        let function = &self
            .functions
            .clone()
            .il2cpp_domain_get
            .ok_or(anyhow::format_err!("il2cpp_domain_get"))?;

        Ok(function())
    }

    pub fn domain_get_assemblies(
        &self,
        domain: *const c_void,
        size: *const usize,
    ) -> Result<*const *const c_void> {
        let function = &self
            .functions
            .clone()
            .il2cpp_domain_get_assemblies
            .ok_or(anyhow::format_err!("il2cpp_domain_get_assemblies"))?;

        Ok(function(domain, size))
    }

    pub fn assembly_get_image(&self, assembly: *const c_void) -> Result<*const c_void> {
        let function = &self
            .functions
            .clone()
            .il2cpp_assembly_get_image
            .ok_or(anyhow::format_err!("il2cpp_assembly_get_image"))?;

        Ok(function(assembly))
    }

    pub fn image_get_class_count(&self, image: *const c_void) -> Result<usize> {
        let function = &self
            .functions
            .clone()
            .il2cpp_image_get_class_count
            .ok_or(anyhow::format_err!("il2cpp_image_get_class_count"))?;

        Ok(function(image))
    }

    pub fn image_get_class(&self, image: *const c_void, index: usize) -> Result<*const c_void> {
        let function = &self
            .functions
            .clone()
            .il2cpp_image_get_class
            .ok_or(anyhow::format_err!("il2cpp_image_get_class"))?;

        Ok(function(image, index))
    }

    pub fn class_get_methods(
        &self,
        class: *const c_void,
        iter: *const *const c_void,
    ) -> Result<Option<*const MethodInfo>> {
        let function = &self
            .functions
            .clone()
            .il2cpp_class_get_methods
            .ok_or(anyhow::format_err!("il2cpp_class_get_methods"))?;

        let result = function(class, iter);

        Ok(if !result.is_null() {
            Some(result)
        } else {
            None
        })
    }

    pub fn class_get_name(&self, class: *const c_void) -> Result<String> {
        let function = &self
            .functions
            .clone()
            .il2cpp_class_get_name
            .ok_or(anyhow::format_err!("il2cpp_class_get_name"))?;

        Ok(Self::to_string(function(class)))
    }

    pub fn class_get_namespace(&self, class: *const c_void) -> Result<String> {
        let function = &self
            .functions
            .clone()
            .il2cpp_class_get_namespace
            .ok_or(anyhow::format_err!("il2cpp_class_get_namespace"))?;

        Ok(Self::to_string(function(class)))
    }

    pub fn method_get_name(&self, method: *const MethodInfo) -> Result<String> {
        let function = &self
            .functions
            .clone()
            .il2cpp_method_get_name
            .ok_or(anyhow::format_err!("il2cpp_method_get_name"))?;

        Ok(Self::to_string(function(method)))
    }

    pub fn image_get_name(&self, image: *const c_void) -> Result<String> {
        let function = &self
            .functions
            .clone()
            .il2cpp_image_get_name
            .ok_or(anyhow::format_err!("image_get_name"))?;

        Ok(Self::to_string(function(image)))
    }
    pub fn field_get_name(&self, field: *const c_void) -> Result<String> {
        let function = &self
            .functions
            .clone()
            .il2cpp_field_get_name
            .ok_or(anyhow::format_err!("il2cpp_field_get_name"))?;

        Ok(Self::to_string(function(field)))
    }

    pub fn field_get_offset(&self, field: *const c_void) -> Result<usize> {
        let function = &self
            .functions
            .clone()
            .il2cpp_field_get_offset
            .ok_or(anyhow::format_err!("il2cpp_field_get_name"))?;

        Ok(function(field))
    }

    pub fn class_get_fields(
        &self,
        class: *const c_void,
        iter: *const *const c_void,
    ) -> Result<Option<*const c_void>> {
        let function = &self
            .functions
            .clone()
            .il2cpp_class_get_fields
            .ok_or(anyhow::format_err!("il2cpp_class_get_fields"))?;

        let result = function(class, iter);

        Ok(if !result.is_null() {
            Some(result)
        } else {
            None
        })
    }
}

static mut API: Option<Il2CppApiWrapper> = None;

pub fn init_il2cpp_api_wrapper() -> Result<&'static Il2CppApiWrapper, Box<dyn Error>> {
    unsafe {
        init_dumper_map();
        
        if API.is_none() {
            API = Some(Il2CppApiWrapper::new()?);
            println!("Il2Cpp Api Inited!");
        }

        Ok(API.as_ref().ok_or("Failed to get the il2cpp api")?)
    }
}
