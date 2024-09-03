use super::{
    module::{get_method_ptr, MethodPtr},
    MethodInfo,
};
use std::ffi::{c_char, c_void};

pub type Il2CppDomainGet = Option<MethodPtr<fn() -> *const c_void>>;

pub type Il2CppDomainGetAssemblies =
    Option<MethodPtr<fn(*const c_void, *const usize) -> *const *const c_void>>;

pub type Il2CppAssemblyGetImage = Option<MethodPtr<fn(*const c_void) -> *const c_void>>;

pub type Il2CppImageGetClassCount = Option<MethodPtr<fn(*const c_void) -> usize>>;

pub type Il2CppImageGetClass = Option<MethodPtr<fn(*const c_void, usize) -> *const c_void>>;

pub type Il2CppClassGetMethods =
    Option<MethodPtr<fn(*const c_void, *const *const c_void) -> *const MethodInfo>>;

pub type Il2CppClassGetName = Option<MethodPtr<fn(*const c_void) -> *const c_char>>;

pub type Il2CppClassGetNamespace = Option<MethodPtr<fn(*const c_void) -> *const c_char>>;

pub type Il2CppMethodGetName = Option<MethodPtr<fn(*const MethodInfo) -> *const c_char>>;

pub type Il2CppImageGetName = Option<MethodPtr<fn(image: *const c_void) -> *const c_char>>;

pub type Il2CppFieldGetName = Option<MethodPtr<fn(*const c_void) -> *const c_char>>;

pub type Il2CppFieldGetOffset = Option<MethodPtr<fn(*const c_void) -> usize>>;

pub type Il2CppClassGetFields =
    Option<MethodPtr<fn(klass: *const c_void, iter: *const *const c_void) -> *const c_void>>;

#[derive(Clone)]
pub struct Il2CppFunctions {
    pub il2cpp_domain_get: Il2CppDomainGet,
    pub il2cpp_domain_get_assemblies: Il2CppDomainGetAssemblies,
    pub il2cpp_assembly_get_image: Il2CppAssemblyGetImage,
    pub il2cpp_image_get_class_count: Il2CppImageGetClassCount,
    pub il2cpp_image_get_class: Il2CppImageGetClass,
    pub il2cpp_class_get_methods: Il2CppClassGetMethods,
    pub il2cpp_class_get_name: Il2CppClassGetName,
    pub il2cpp_class_get_namespace: Il2CppClassGetNamespace,
    pub il2cpp_method_get_name: Il2CppMethodGetName,
    pub il2cpp_image_get_name: Il2CppImageGetName,
    pub il2cpp_field_get_name: Il2CppFieldGetName,
    pub il2cpp_field_get_offset: Il2CppFieldGetOffset,
    pub il2cpp_class_get_fields: Il2CppClassGetFields,
}

impl Il2CppFunctions {
    pub fn new(base: usize) -> Self {
        Il2CppFunctions {
            il2cpp_domain_get: get_method_ptr(base + 0x1D7B610),
            il2cpp_domain_get_assemblies: get_method_ptr(base + 0x1D7B620),
            il2cpp_assembly_get_image: get_method_ptr(base + 0x1D7B4C8),
            il2cpp_image_get_class_count: get_method_ptr(base + 0x1D7B950),
            il2cpp_image_get_class: get_method_ptr(base + 0x1D7B958),
            il2cpp_class_get_methods: get_method_ptr(base + 0x1D7B530),
            il2cpp_class_get_name: get_method_ptr(base + 0x1D7B540),
            il2cpp_class_get_namespace: get_method_ptr(base + 0x1D7B550),
            il2cpp_method_get_name: get_method_ptr(base + 0x1D7B7B0),
            il2cpp_image_get_name: get_method_ptr(base + 0x1D7B948),
            il2cpp_field_get_name: get_method_ptr(base + 0x1D7B660),
            il2cpp_field_get_offset: get_method_ptr(base + 0x1D7B670),
            il2cpp_class_get_fields: get_method_ptr(base + 0x1D7B510),
        }
    }
}
