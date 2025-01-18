use std::sync::Arc;
use std::sync::Mutex;

use std::fs::File;
use std::io::{BufReader, BufWriter};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, Serialize)]
pub struct Config {
    pub lua_files: Vec<String>,
}

static CONFIG_FILE: &str = "Config.json";

#[allow(dead_code)]
impl Config {
    pub unsafe fn inst() -> &'static mut Config {
        &mut *Config::ptr()
    }

    pub unsafe fn ptr() -> *mut Config {
        &mut *Config::initial().lock().unwrap()
    }

    unsafe fn initial() -> Arc<Mutex<Config>> {
        static mut INSTANCE: Option<Arc<Mutex<Config>>> = None;
        INSTANCE.get_or_insert_with(||{Arc::new(Mutex::new(Config {
            lua_files: vec![],
        }))}).clone()
    }

    pub unsafe fn init(&mut self) {
        match File::open(CONFIG_FILE) {
            Ok(file) => {
                let reader = BufReader::new(file);
                match serde_json::from_reader(reader) {
                    Ok(tmp) => {
                        *self = tmp;
                        self.write();
                    },
                    Err(_) => {
                        self.write();
                    }
                }
            },
            Err(_) => {
                self.write();
            }
        };
    }

    #[allow(static_mut_refs)]
    pub unsafe fn write(&mut self) {
        let file = File::create(CONFIG_FILE).unwrap();
        let writer = BufWriter::new(file);
        serde_json::to_writer_pretty(writer, &self).unwrap();
    }
}
