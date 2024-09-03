use super::{
    module::{get_method_ptr, MethodPtr},
    MethodInfo,
};
use std::ffi::{c_char, c_void};
use crate::GLOBAL_CONFIG;

macro_rules! define_il2cpp_function {
    ($name:ident, $sig:ty) => {
        pub type $name = Option<MethodPtr<$sig>>;
    };
}

define_il2cpp_function!(Il2CppDomainGet, fn() -> *const c_void);
define_il2cpp_function!(Il2CppDomainGetAssemblies, fn(*const c_void, *const usize) -> *const *const c_void);
define_il2cpp_function!(Il2CppAssemblyGetImage, fn(*const c_void) -> *const c_void);
define_il2cpp_function!(Il2CppImageGetClassCount, fn(*const c_void) -> usize);
define_il2cpp_function!(Il2CppImageGetClass, fn(*const c_void, usize) -> *const c_void);
define_il2cpp_function!(Il2CppClassGetMethods, fn(*const c_void, *const *const c_void) -> *const MethodInfo);
define_il2cpp_function!(Il2CppClassGetName, fn(*const c_void) -> *const c_char);
define_il2cpp_function!(Il2CppMethodGetName, fn(*const MethodInfo) -> *const c_char);
define_il2cpp_function!(Il2CppImageGetName, fn(image: *const c_void) -> *const c_char);
define_il2cpp_function!(Il2CppFieldGetName, fn(*const c_void) -> *const c_char);
define_il2cpp_function!(Il2CppFieldGetOffset, fn(*const c_void) -> usize);
define_il2cpp_function!(Il2CppClassGetFields, fn(klass: *const c_void, iter: *const *const c_void) -> *const c_void);

#[derive(Clone)]
pub struct Il2CppFunctions {
    pub il2cpp_domain_get: Il2CppDomainGet,
    pub il2cpp_domain_get_assemblies: Il2CppDomainGetAssemblies,
    pub il2cpp_assembly_get_image: Il2CppAssemblyGetImage,
    pub il2cpp_image_get_class_count: Il2CppImageGetClassCount,
    pub il2cpp_image_get_class: Il2CppImageGetClass,
    pub il2cpp_class_get_methods: Il2CppClassGetMethods,
    pub il2cpp_class_get_name: Il2CppClassGetName,
    pub il2cpp_method_get_name: Il2CppMethodGetName,
    pub il2cpp_image_get_name: Il2CppImageGetName,
    pub il2cpp_field_get_name: Il2CppFieldGetName,
    pub il2cpp_field_get_offset: Il2CppFieldGetOffset,
    pub il2cpp_class_get_fields: Il2CppClassGetFields,
}

impl Il2CppFunctions {
    pub fn new(base: usize) -> Self {
        let offsets = GLOBAL_CONFIG.get_offset();
        Self {
            il2cpp_domain_get: get_method_ptr(base + offsets.il2cpp_domain_get),
            il2cpp_domain_get_assemblies: get_method_ptr(base + offsets.il2cpp_domain_get_assemblies),
            il2cpp_assembly_get_image: get_method_ptr(base + offsets.il2cpp_assembly_get_image),
            il2cpp_image_get_class_count: get_method_ptr(base + offsets.il2cpp_image_get_class_count),
            il2cpp_image_get_class: get_method_ptr(base + offsets.il2cpp_image_get_class),
            il2cpp_class_get_methods: get_method_ptr(base + offsets.il2cpp_class_get_methods),
            il2cpp_class_get_name: get_method_ptr(base + offsets.il2cpp_class_get_name),
            il2cpp_method_get_name: get_method_ptr(base + offsets.il2cpp_method_get_name),
            il2cpp_image_get_name: get_method_ptr(base + offsets.il2cpp_image_get_name),
            il2cpp_field_get_name: get_method_ptr(base + offsets.il2cpp_field_get_name),
            il2cpp_field_get_offset: get_method_ptr(base + offsets.il2cpp_field_get_offset),
            il2cpp_class_get_fields: get_method_ptr(base + offsets.il2cpp_class_get_fields),
        }
    }
}