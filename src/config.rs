use std::collections::HashMap;
use std::fs::File;
use std::io::Write;

use anyhow::Result;
use serde::{Deserialize, Deserializer};

use crate::util::get_game_version;

const DEFAULT_CONFIG: &'static str = include_str!("./config.json");

#[derive(Deserialize, Default, Debug)]
pub struct Config {
    #[serde(default)]
    version: String,
    pub enable_luauc_inject: bool,
    pub luauc_inject_path: String,
    pub enable_luauc_dump: bool,
    pub luauc_dump_path: String,
    pub enable_redirect: bool,
    pub redirect_url: String,
    pub disable_censorship: bool,
    pub offsets: HashMap<String, OffsetConfig>,
    #[serde(default)]
    pub dll_sideloads: Vec<String>,
    pub hook_il2cpp: bool,
}

#[derive(Deserialize, Default, Debug)]
pub struct OffsetConfig {
    #[serde(deserialize_with = "hex_to_usize")]
    pub web_request_utils_make_initial_url: usize,
    #[serde(deserialize_with = "hex_to_usize")]
    pub to_string_ansi: usize,
    #[serde(deserialize_with = "hex_to_usize")]
    pub set_elevation_dither_alpha_value: usize,
    #[serde(deserialize_with = "hex_to_usize")]
    pub set_distance_dither_alpha_value: usize,
    #[serde(deserialize_with = "hex_to_usize")]
    pub set_dither_alpha_value: usize,
    #[serde(deserialize_with = "hex_to_usize")]
    pub set_dither_alpha_value_with_animation: usize,
    #[serde(deserialize_with = "hex_to_usize")]
    #[serde(default)]
    pub mhy_sdk_sdkutil_rsaencrypt: usize,
}

impl Config {
    pub fn new() -> Result<Self> {
        println!("[ConfigManager] Initializing config");
        let version = get_game_version()?;
        println!("[ConfigManager] Detected game version {version}");

        if !std::path::Path::new("config.json").exists() {
            Self::create_default_config_file()?;
        }

        let file = std::fs::read_to_string("config.json")?;
        let mut config = serde_json::from_str::<Self>(&file)?;
        config.version = version.clone();

        if !config.offsets.contains_key(&version) {
            println!("[ConfigManager] Version {version} is not supported. Disabled proxy & censorship patch.");
            config.enable_redirect = false;
            config.disable_censorship = false;
        };

        Ok(config)
    }

    fn create_default_config_file() -> Result<()> {
        let mut file = File::create("config.json")?;
        file.write_all(DEFAULT_CONFIG.as_bytes())?;
        println!("[ConfigManager] Created default config.json");
        Ok(())
    }

    pub fn get_offset(&self) -> &OffsetConfig {
        return self.offsets.get(&self.version).unwrap();
    }
}

fn hex_to_usize<'de, D>(deserializer: D) -> Result<usize, D::Error>
where
    D: Deserializer<'de>,
{
    let s = String::deserialize(deserializer)?;

    if let Some(hex_str) = s.strip_prefix("0x") {
        usize::from_str_radix(hex_str, 16).map_err(serde::de::Error::custom)
    } else {
        Err(serde::de::Error::custom("Invalid hexadecimal format"))
    }
}
