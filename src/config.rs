use std::collections::HashMap;

use anyhow::Result;
use serde::{Deserialize, Deserializer};

use crate::util::get_game_version;

#[derive(Deserialize, Default, Debug)]
pub struct Config {
    #[serde(default)]
    version: String,
    pub enable_luauc_dump: bool,
    pub luauc_dump_path: String,
    pub enable_luauc_inject: bool,
    pub enable_redirect: bool,
    pub disable_censorship: bool,
    pub redirect_url: String,
    pub offsets: HashMap<String, OffsetConfig>,
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
}

impl Config {
    pub fn new() -> Result<Self> {
        println!("[ConfigManager] Initializing config");
        let version = get_game_version()?;
        println!("[ConfigManager] Detected game version {version}");
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
