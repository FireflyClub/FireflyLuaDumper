use std::os::raw::{c_char, c_int};

#[allow(non_camel_case_types)]
#[repr(C)]
#[derive(Debug, Copy, Clone)]
pub struct lua_State {
    _unused: [u8; 0],
}

pub type LuaULoad = unsafe extern "fastcall" fn (
    *mut lua_State,
    *const c_char,
    *const c_char,
    usize,
    c_int,
) -> c_int;

pub type XluaLLoadbuffer = unsafe extern "fastcall" fn (
    *mut lua_State,
    *const i8,
    usize,
    *const c_char,
) -> c_int;

pub type LuaLPcall = unsafe extern "fastcall" fn (
    *mut lua_State,
    *const c_int,
    *const c_int,
    *const c_int,
) -> c_int;

pub static mut XLUAL_LOADBUFFER_ADDR: usize = 0;
pub static mut LUA_PCALL_ADDR: usize = 0;

pub unsafe fn xluaL_loadbuffer(
    L: *mut lua_State,
    buff: *const i8,
    size: usize,
    name: *const c_char
) -> c_int {
    let xluaL_loadbuffer = std::mem::transmute::<usize, XluaLLoadbuffer>(
        XLUAL_LOADBUFFER_ADDR
    );
    xluaL_loadbuffer(L, buff, size, name)
}

pub unsafe fn lua_pcall(
    L: *mut lua_State,
    nargs: *const c_int,
    nresults: *const c_int,
    errfunc: *const c_int
) -> c_int {
    let lua_pcall = std::mem::transmute::<usize, LuaLPcall>(LUA_PCALL_ADDR);
    lua_pcall(L, nargs, nresults, errfunc)
}
