use std::os::raw::c_void;

pub mod api;
mod functions;
mod module;
pub mod rva_dumper;

#[repr(C)]
pub(super) struct MethodInfo {
    pub invoker_method: *const c_void,
    pub method_pointer: *const c_void,
}
