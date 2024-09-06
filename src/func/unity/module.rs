use std::{ffi::c_void, marker::PhantomData, ops::Deref};

pub struct MethodPtr<T> {
    pub ptr: *mut c_void,
    pd: PhantomData<T>,
}

impl<T> Deref for MethodPtr<T> {
    type Target = T;

    fn deref(&self) -> &T {
        unsafe { &*(&self.ptr as *const *mut _ as *const T) }
    }
}

impl<T> Clone for MethodPtr<T> {
    fn clone(&self) -> Self {
        MethodPtr { ..*self }
    }
}

pub fn get_method_ptr<T>(offset: usize) -> Option<MethodPtr<T>> {
    unsafe {
        let ptr = *(offset as *mut usize);

        if ptr == 0 {
            return None;
        }

        Some(MethodPtr {
            ptr: ptr as *mut c_void,
            pd: PhantomData,
        })
    }
}
