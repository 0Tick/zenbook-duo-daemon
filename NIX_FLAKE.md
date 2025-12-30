# Nix Flake Usage

This repository includes a Nix flake that provides easy installation and configuration of the Zenbook Duo daemon on NixOS systems.

## Quick Start

### Using the Flake in Your NixOS Configuration

Add the flake to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zenbook-duo-daemon = {
      url = "github:PegasisForever/zenbook-duo-daemon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, zenbook-duo-daemon, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        zenbook-duo-daemon.nixosModules.default
        {
          services.zenbook-duo-daemon.enable = true;
        }
      ];
    };
  };
}
```

### Building the Package

To build the daemon package:

```bash
nix build github:PegasisForever/zenbook-duo-daemon
```

### Development Shell

To enter a development environment with all dependencies:

```bash
nix develop github:PegasisForever/zenbook-duo-daemon
```

## Configuration

The NixOS module provides extensive configuration options. Here's a complete example:

```nix
{
  services.zenbook-duo-daemon = {
    enable = true;
    
    # USB device identification
    usbVendorId = "0b05";  # ASUS vendor ID
    usbProductId = "auto"; # Auto-detect based on board name
    # Or specify manually: "1bf2" for 2025 model, "1b2c" for 2024 model
    
    # Paths (usually don't need to change these)
    secondaryDisplayStatusPath = "/sys/class/drm/card1-eDP-2/status";
    primaryBacklightPath = "/sys/class/backlight/intel_backlight/brightness";
    secondaryBacklightPath = "/sys/class/backlight/card1-eDP-2-backlight/brightness";
    pipePath = "/tmp/zenbook-duo-daemon.pipe";
    
    # Idle timeout (in seconds, 0 to disable)
    idleTimeoutSeconds = 300;
    
    # Key mappings
    keyMappings = {
      # Keyboard backlight toggle
      keyboardBacklight = {
        type = "KeyboardBacklight";
      };
      
      # Brightness controls
      brightnessDown = {
        type = "KeyBind";
        keys = [ "KEY_BRIGHTNESSDOWN" ];
      };
      
      brightnessUp = {
        type = "KeyBind";
        keys = [ "KEY_BRIGHTNESSUP" ];
      };
      
      # Swap up/down display (disabled by default)
      swapUpDownDisplay = {
        type = "NoOp";
      };
      
      # Microphone mute
      microphoneMute = {
        type = "KeyBind";
        keys = [ "KEY_MICMUTE" ];
      };
      
      # Emoji picker (Ctrl+. for GTK apps in GNOME)
      emojiPicker = {
        type = "KeyBind";
        keys = [ "KEY_LEFTCTRL" "KEY_DOT" ];
      };
      
      # MyASUS key (disabled by default)
      myasus = {
        type = "NoOp";
      };
      
      # Toggle secondary display
      toggleSecondaryDisplay = {
        type = "ToggleSecondaryDisplay";
      };
    };
  };
}
```

## Key Mapping Types

Each key can be configured with one of the following types:

### KeyBind
Maps the physical key to one or more keyboard keys:
```nix
{
  type = "KeyBind";
  keys = [ "KEY_LEFTCTRL" "KEY_F10" ];  # Press Ctrl+F10
}
```

Available key names can be found in the [evdev-rs documentation](https://docs.rs/evdev-rs/0.6.3/evdev_rs/enums/enum.EV_KEY.html).

### Command
Executes a shell command (runs as root):
```nix
{
  type = "Command";
  command = "echo 'Hello, world!' > /tmp/test.txt";
}
```

### KeyboardBacklight
Toggles the keyboard backlight:
```nix
{
  type = "KeyboardBacklight";
}
```

### ToggleSecondaryDisplay
Toggles the secondary display:
```nix
{
  type = "ToggleSecondaryDisplay";
}
```

### NoOp
Does nothing (disables the key):
```nix
{
  type = "NoOp";
}
```

## Control Pipe

The daemon creates a control pipe (default: `/tmp/zenbook-duo-daemon.pipe`) for receiving commands. You can send commands to control the daemon:

```bash
echo mic_mute_led_toggle > /tmp/zenbook-duo-daemon.pipe
```

Available commands:
- `mic_mute_led_toggle` - Toggle microphone mute LED
- `mic_mute_led_on` - Turn on microphone mute LED
- `mic_mute_led_off` - Turn off microphone mute LED
- `backlight_toggle` - Cycle keyboard backlight
- `backlight_off` - Turn off keyboard backlight
- `backlight_low` - Set keyboard backlight to low
- `backlight_medium` - Set keyboard backlight to medium
- `backlight_high` - Set keyboard backlight to high
- `secondary_display_toggle` - Toggle secondary display
- `secondary_display_on` - Turn on secondary display
- `secondary_display_off` - Turn off secondary display

## Checking Logs

View daemon logs:
```bash
journalctl -u zenbook-duo-daemon -f
```

Check service status:
```bash
systemctl status zenbook-duo-daemon
```

## Updating

When using the flake in your NixOS configuration, update with:

```bash
nix flake update
sudo nixos-rebuild switch
```

## License

This flake follows the same license as the main project (MIT).
