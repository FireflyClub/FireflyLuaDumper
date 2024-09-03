use std::os::raw::c_void;

pub mod api;
mod functions;
mod il2cpp_api_bridge;
mod module;
pub mod rva_dumper;

pub use il2cpp_api_bridge::Il2CppApiBridge;

#[repr(C)]
pub(super) struct MethodInfo {
    pub invoker_method: *const c_void,
    pub method_pointer: *const c_void,
}
