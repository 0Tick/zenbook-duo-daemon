use std::path::PathBuf;

use log::{info, warn};
use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::net::UnixStream;
use tokio::time::{Duration, sleep};

use crate::config::Config;
use crate::execute_command;

pub async fn run_user_daemon(config_path: PathBuf) {
    let config = Config::read(&config_path).await;
    let socket_path = PathBuf::from(&config.pipe_path);

    loop {
        match UnixStream::connect(&socket_path).await {
            Ok(stream) => {
                info!("Connected to daemon socket at {}", socket_path.display());
                let mut reader = BufReader::new(stream);
                loop {
                    let mut line = String::new();
                    match reader.read_line(&mut line).await {
                        Ok(0) => {
                            warn!("Daemon socket closed, reconnecting...");
                            break;
                        }
                        Ok(_) => {
                            let key_id = line.trim();
                            if key_id.is_empty() {
                                continue;
                            }
                            if let Some(key_function) = config.key_function_by_id(key_id) {
                                if let Some(command) = key_function.user_command() {
                                    info!("Executing user command for {}: {}", key_id, command);
                                    execute_command(command);
                                }
                            } else {
                                warn!("Unknown key function identifier: {}", key_id);
                            }
                        }
                        Err(err) => {
                            warn!("Failed to read daemon socket: {}", err);
                            break;
                        }
                    }
                }
            }
            Err(err) => {
                warn!(
                    "Failed to connect to daemon socket {}: {}",
                    socket_path.display(),
                    err
                );
            }
        }
        sleep(Duration::from_secs(1)).await;
    }
}
