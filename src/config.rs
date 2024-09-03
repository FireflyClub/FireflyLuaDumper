use std::collections::HashMap;
use std::fs::File;
use std::io::Write;
use anyhow::{Result, Context};
use serde::{Deserialize, Deserializer};

use crate::util::get_game_version;

pub const CONFIG_PATH: &'static str = "./config.json";
pub const DEFAULT_CONFIG: &'static str = include_str!("./config.json");
const ENABLE_CONFIG_GEN: bool = true;

#[derive(Deserialize, Default, Debug)]
pub struct Config {
    #[serde(default)]
    version: String,
    #[serde(default)]
    pub enable_redirect: bool,
    #[serde(default)]
    pub redirect_url: String,
    #[serde(default)]
    pub disable_censorship: bool,
    #[serde(default)]
    pub enable_luauc_inject: bool,
    #[serde(default)]
    pub luauc_inject_path: String,
    #[serde(default)]
    pub hook_il2cpp: bool,
    #[serde(default)]
    pub enable_luauc_dump: bool,
    #[serde(default)]
    pub luauc_dump_path: String,
    #[serde(default)]
    pub dll_sideloads: Vec<String>,
    #[serde(default)]
    pub offsets: HashMap<String, OffsetConfig>,
}

#[derive(Deserialize, Default, Debug)]
pub struct OffsetConfig {
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub web_request_utils_make_initial_url: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub to_string_ansi: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub set_elevation_dither_alpha_value: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub set_distance_dither_alpha_value: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub set_dither_alpha_value: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub set_dither_alpha_value_with_animation: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub mhy_sdk_sdkutil_rsaencrypt: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub il2cpp_domain_get: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub il2cpp_domain_get_assemblies: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub il2cpp_assembly_get_image: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub il2cpp_image_get_class_count: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub il2cpp_image_get_class: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub il2cpp_class_get_methods: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub il2cpp_class_get_name: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub il2cpp_method_get_name: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub il2cpp_image_get_name: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub il2cpp_field_get_name: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub il2cpp_field_get_offset: usize,
    #[serde(deserialize_with = "hex_to_usize", default)]
    pub il2cpp_class_get_fields: usize,
}

impl Config {
    pub fn new() -> Result<Self> {
        println!("[ConfigManager] Initializing config");
        let version = get_game_version()?;
        println!("[ConfigManager] Detected game version {version}");

        let config = if ENABLE_CONFIG_GEN {
            if std::path::Path::new(CONFIG_PATH).exists() {
                let file = std::fs::read_to_string(CONFIG_PATH)?;
                serde_json::from_str(&file).context("[ConfigManager] Parse config failed.")?
            } else {
                println!("[ConfigManager] Config file not found, creating default config.");
                Self::create_default_config_file()?;
                serde_json::from_str(DEFAULT_CONFIG)?
            }
        } else {
            println!("[ConfigManager] Using default config.");
            serde_json::from_str(DEFAULT_CONFIG)?
        };

        Ok(Self::validate_config(config, version))
    }

    fn validate_config(mut config: Self, version: String) -> Self {
        config.version = version.clone();

        if !config.offsets.contains_key(&version) {
            println!("[ConfigManager] Version {version} is not supported. Disabled offsets.");
            config.enable_redirect = false;
            config.disable_censorship = false;
            config.hook_il2cpp = false;
        }

        config
    }

    fn create_default_config_file() -> Result<()> {
        let mut file = File::create(CONFIG_PATH)?;
        file.write_all(DEFAULT_CONFIG.as_bytes())?;
        println!("[ConfigManager] Default config created.");
        Ok(())
    }

    pub fn get_offset(&self) -> &OffsetConfig {
        self.offsets.get(&self.version).expect("[ConfigManager] Offset config not found for current version.")
    }
}

fn hex_to_usize<'de, D>(deserializer: D) -> Result<usize, D::Error>
where
    D: Deserializer<'de>,
{
    let s = String::deserialize(deserializer)?;

    let s = s.trim();
    
    if s.is_empty() {
        return Ok(0);
    }

    if let Some(hex_str) = s.strip_prefix("0x") {
        usize::from_str_radix(hex_str, 16).map_err(serde::de::Error::custom)
    } else {
        s.parse::<usize>().map_err(|_| serde::de::Error::custom("[ConfigManager] Invalid number format."))
    }
}
