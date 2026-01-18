use log::{info, warn};
use std::os::unix::fs::PermissionsExt as _;
use std::path::PathBuf;
use tokio::fs;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::broadcast;

use crate::config::Config;
use crate::idle_detection::ActivityNotifier;
use crate::state::{KeyboardBacklightState, KeyboardStateManager};

#[derive(Clone)]
pub struct UnixSocketNotifier {
    sender: broadcast::Sender<String>,
}

impl UnixSocketNotifier {
    pub fn notify_key(&self, key_id: &str) {
        let _ = self.sender.send(key_id.to_string());
    }
}

pub fn start_receive_commands_task(
    config: &Config,
    state_manager: KeyboardStateManager,
    activity_notifier: ActivityNotifier,
) -> UnixSocketNotifier {
    let path = PathBuf::from(&config.pipe_path);
    let (event_sender, _) = broadcast::channel::<String>(64);
    let event_sender_task = event_sender.clone();
    tokio::spawn(async move {
        if fs::try_exists(&path).await.unwrap_or(false) {
            if let Err(err) = fs::remove_file(&path).await {
                warn!("Failed to remove existing socket file: {}", err);
            } else {
                info!("Removed existing socket file");
            }
        }

        let listener = match UnixListener::bind(&path) {
            Ok(listener) => listener,
            Err(err) => {
                warn!("Failed to bind unix socket {}: {}", path.display(), err);
                return;
            }
        };

        if let Err(err) = set_socket_permissions(&path).await {
            warn!("Failed to set socket permissions: {}", err);
        }

        info!("Unix socket listening at {}", path.display());
        loop {
            match listener.accept().await {
                Ok((stream, _)) => {
                    let state_manager = state_manager.clone();
                    let activity_notifier = activity_notifier.clone();
                    let event_sender = event_sender_task.clone();
                    tokio::spawn(async move {
                        handle_client(stream, state_manager, activity_notifier, event_sender).await;
                    });
                }
                Err(err) => {
                    warn!("Unix socket accept failed: {}", err);
                }
            }
        }
    });
    UnixSocketNotifier {
        sender: event_sender,
    }
}

pub async fn send_command(socket_path: &PathBuf, command: &str) -> Result<(), String> {
    let mut stream = UnixStream::connect(socket_path)
        .await
        .map_err(|err| format!("Failed to connect to socket {}: {}", socket_path.display(), err))?;
    stream
        .write_all(format!("{}\n", command).as_bytes())
        .await
        .map_err(|err| format!("Failed to send command: {}", err))?;
    Ok(())
}

async fn set_socket_permissions(path: &PathBuf) -> Result<(), std::io::Error> {
    let metadata = fs::metadata(path).await?;
    let mut permissions = metadata.permissions();
    permissions.set_mode(0o666);
    fs::set_permissions(path, permissions).await
}

async fn handle_client(
    stream: UnixStream,
    state_manager: KeyboardStateManager,
    activity_notifier: ActivityNotifier,
    event_sender: broadcast::Sender<String>,
) {
    let (reader, mut writer) = stream.into_split();
    let mut reader = BufReader::new(reader);
    let mut event_receiver = event_sender.subscribe();

    loop {
        let mut line = String::new();
        tokio::select! {
            result = reader.read_line(&mut line) => {
                match result {
                    Ok(0) => break,
                    Ok(_) => {
                        let line = line.trim_end();
                        if !line.is_empty() {
                            info!("Received command: {}", line);
                            handle_command(line, &state_manager, &activity_notifier);
                        }
                    }
                    Err(err) => {
                        warn!("Failed to read from unix socket: {}", err);
                        break;
                    }
                }
            }
            result = event_receiver.recv() => {
                match result {
                    Ok(message) => {
                        if let Err(err) = writer.write_all(message.as_bytes()).await {
                            warn!("Failed to write socket message: {}", err);
                            break;
                        }
                        if let Err(err) = writer.write_all(b"\n").await {
                            warn!("Failed to write socket newline: {}", err);
                            break;
                        }
                    }
                    Err(broadcast::error::RecvError::Lagged(_)) => {
                        continue;
                    }
                    Err(broadcast::error::RecvError::Closed) => {
                        break;
                    }
                }
            }
        }
    }
}

fn handle_command(
    line: &str,
    state_manager: &KeyboardStateManager,
    activity_notifier: &ActivityNotifier,
) {
    match line {
        "suspend_start" => {
            state_manager.suspend_start();
        }
        "suspend_end" => {
            state_manager.suspend_end();
            activity_notifier.notify();
        }
        "mic_mute_led_toggle" => {
            state_manager.toggle_mic_mute_led();
        }
        "mic_mute_led_on" => {
            state_manager.set_mic_mute_led(true);
        }
        "mic_mute_led_off" => {
            state_manager.set_mic_mute_led(false);
        }
        "backlight_toggle" => {
            state_manager.toggle_keyboard_backlight();
        }
        "backlight_off" => {
            state_manager.set_keyboard_backlight(KeyboardBacklightState::Off);
        }
        "backlight_low" => {
            state_manager.set_keyboard_backlight(KeyboardBacklightState::Low);
        }
        "backlight_medium" => {
            state_manager.set_keyboard_backlight(KeyboardBacklightState::Medium);
        }
        "backlight_high" => {
            state_manager.set_keyboard_backlight(KeyboardBacklightState::High);
        }
        "secondary_display_toggle" => {
            state_manager.toggle_secondary_display();
        }
        "secondary_display_on" => {
            state_manager.set_secondary_display(true);
        }
        "secondary_display_off" => {
            state_manager.set_secondary_display(false);
        }
        _ => {
            warn!("Unknown socket command: {}", line);
        }
    }
}
