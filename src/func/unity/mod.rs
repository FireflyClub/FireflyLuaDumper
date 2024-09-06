use std::os::raw::c_void;

mod functions;
mod module;

pub mod api;
pub mod rva_dumper;

#[repr(C)]
pub(crate) struct MethodInfo {
    pub invoker_method: *const c_void,
    pub method_pointer: *const c_void,
}
