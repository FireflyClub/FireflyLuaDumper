use std::{collections::HashMap, os::raw::c_void, ptr::null};

use super::api::init_il2cpp_api_wrapper;

static mut METHOD_RVA_CACHE: Option<HashMap<String, usize>> = None;
static mut FIELD_OFFSET_CACHE: Option<HashMap<String, usize>> = None;

pub(super) unsafe fn init_dumper_map() {
    if METHOD_RVA_CACHE.is_some() || FIELD_OFFSET_CACHE.is_some() {
        return;
    }

    METHOD_RVA_CACHE = Some(HashMap::new());
    FIELD_OFFSET_CACHE = Some(HashMap::new());

    println!("[RVADumper] Cache inited")
}

fn verify_pointer(game_assembly_base: usize, game_assembly_size: usize, pointer: usize) -> bool {
    (pointer > game_assembly_base) && (pointer < game_assembly_base + game_assembly_size)
}

pub unsafe fn get_rva(key: &str) -> usize {
    if let Some(ref mut map) = METHOD_RVA_CACHE {
        if let Some(rva) = map.get(key) {
            return *rva;
        }
    }

    0x0
}

pub unsafe fn get_offset(key: &str) -> usize {
    if let Some(ref mut map) = FIELD_OFFSET_CACHE {
        if let Some(rva) = map.get(key) {
            return *rva;
        }
    }

    0x0
}

pub unsafe fn dump_offset_and_rva() -> anyhow::Result<()> {
    let api = init_il2cpp_api_wrapper().unwrap();
    let domain = api.domain_get()?;

    let assembly_count: usize = 0;
    let assemblies = api.domain_get_assemblies(domain, &assembly_count)?;
    for i in 0..assembly_count {
        let assembly = unsafe { *assemblies.add(i) };

        if assembly.is_null() {
            continue;
        }

        let image = api.assembly_get_image(assembly)?;
        let image_name = api.image_get_name(image)?;

        let class_count = api.image_get_class_count(image)?;

        for j in 0..class_count {
            let class = api.image_get_class(image, j)?;

            if class.is_null() {
                continue;
            }

            let class_name = api.class_get_name(class)?;

            let iter: *const c_void = null();
            while let Some(method_info) = api.class_get_methods(class, &iter)? {
                let method_name = api.method_get_name(method_info)?;

                let key = format!("{}|{}|{}", image_name, class_name, method_name);
                if let Some(ref mut map) = METHOD_RVA_CACHE
                    && verify_pointer(
                        api.game_assembly.0,
                        api.game_assembly.1,
                        (*method_info).method_pointer as usize,
                    )
                {
                    map.insert(
                        key,
                        (*method_info).method_pointer as usize - api.game_assembly.0 as usize,
                    );
                }
            }

            let iter: *const c_void = null();
            while let Some(field_info) = api.class_get_fields(class, &iter)? {
                let field_name = api.field_get_name(field_info)?;
                let offset = api.field_get_offset(field_info)?;

                let key = format!("{}|{}|{}", image_name, class_name, field_name);
                if let Some(ref mut map) = FIELD_OFFSET_CACHE {
                    map.insert(key, offset as usize);
                }
            }
        }
    }

    let method_cnt = METHOD_RVA_CACHE.as_ref().map_or(0, |map| map.len());
    let offset_cnt = FIELD_OFFSET_CACHE.as_ref().map_or(0, |map| map.len());

    println!(
        "[RVADumper] rva and offset saved into memory! MethodCount: {}, FieldCount: {}",
        method_cnt, offset_cnt
    );
    Ok(())
}
