# Nix Flake Testing Guide

This document describes how to test the Nix flake for the Zenbook Duo daemon.

## Prerequisites

You need a system with Nix installed and flakes enabled:

```bash
# Check Nix is installed
nix --version

# Enable flakes (if not already enabled)
# Add to ~/.config/nix/nix.conf or /etc/nix/nix.conf:
# experimental-features = nix-command flakes
```

## Testing Steps

### 1. Basic Flake Check

Validate the flake structure:

```bash
nix flake check
```

Expected output: No errors

### 2. Build the Package

Build the daemon binary:

```bash
nix build
```

Note: Tests are disabled during the Nix build because they require hardware access and root permissions that aren't available in the Nix build sandbox. The daemon will be fully tested when running on actual hardware.

This should create a `result` symlink containing:
- `bin/zenbook-duo-daemon` - The daemon binary
- `lib/systemd/system/zenbook-duo-daemon*.service` - Service files

Verify the binary:

```bash
./result/bin/zenbook-duo-daemon --version
./result/bin/zenbook-duo-daemon --help
```

### 3. Enter Development Shell

Test the development environment:

```bash
nix develop
cargo --version
rustc --version
cargo build
```

### 4. Test NixOS Module (on NixOS only)

On a NixOS system with Zenbook Duo hardware, add to your configuration:

```nix
{
  inputs.zenbook-duo-daemon.url = "github:PegasisForever/zenbook-duo-daemon";
  # or for local testing:
  # inputs.zenbook-duo-daemon.url = "path:/path/to/zenbook-duo-daemon";
  
  outputs = { self, nixpkgs, zenbook-duo-daemon, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        zenbook-duo-daemon.nixosModules.default
        {
          services.zenbook-duo-daemon = {
            enable = true;
            idleTimeoutSeconds = 300;
          };
        }
      ];
    };
  };
}
```

Rebuild and test:

```bash
sudo nixos-rebuild test --flake .#your-host
```

### 5. Verify Services

After enabling on NixOS, check services are running:

```bash
systemctl status zenbook-duo-daemon
systemctl status zenbook-duo-daemon-pre-sleep
systemctl status zenbook-duo-daemon-post-sleep
```

### 6. Verify Configuration

Check that the config file was generated correctly:

```bash
cat /etc/zenbook-duo-daemon/config.toml
```

### 7. Test Configuration Options

Try customizing key mappings in your NixOS config:

```nix
services.zenbook-duo-daemon = {
  enable = true;
  keyMappings.myasus = {
    type = "Command";
    command = "echo 'MyASUS key pressed' >> /tmp/zenbook-test.log";
  };
};
```

Rebuild, press the MyASUS key, and check `/tmp/zenbook-test.log`.

### 8. Test Control Pipe

Send commands to the daemon:

```bash
echo "backlight_toggle" > /run/zenbook-duo-daemon.pipe
echo "secondary_display_toggle" > /run/zenbook-duo-daemon.pipe
```

### 9. Check Logs

Monitor daemon logs:

```bash
journalctl -u zenbook-duo-daemon -f
```

## Validation Checklist

- [ ] Flake passes `nix flake check`
- [ ] Package builds with `nix build`
- [ ] Binary executes and shows help
- [ ] Development shell works
- [ ] NixOS module loads without errors
- [ ] Services start and run
- [ ] Config file is generated correctly
- [ ] Key mappings work as configured
- [ ] Control pipe accepts commands
- [ ] Sleep/wake services trigger correctly
- [ ] Logs show proper operation

## Troubleshooting

### Build Fails

If the build fails, check:
- Cargo.lock is present and up to date
- All dependencies are declared in flake.nix
- nixpkgs version is compatible

### Services Don't Start

Check:
- The binary has execute permissions
- Running as root (required for hardware access)
- Hardware devices exist at configured paths

### Config Not Applied

Verify:
- Config file exists at `/etc/zenbook-duo-daemon/config.toml`
- Syntax is valid TOML
- Service was restarted after config change

### Permission Issues

The daemon needs:
- Root access
- Access to `/dev/input/event*` devices
- Access to `/sys/class/drm/` and `/sys/class/backlight/` paths

## Manual Testing Without Hardware

For testing on non-Zenbook systems:

```bash
# Build the package
nix build

# Try running in dry-run mode (will fail at hardware access but validates config)
sudo ./result/bin/zenbook-duo-daemon run --config-path /tmp/test-config.toml

# Create a test config
cat > /tmp/test-config.toml << 'EOF'
usb_vendor_id = "0b05"
usb_product_id = "1b2c"
secondary_display_status_path = "/sys/class/drm/card1-eDP-2/status"
primary_backlight_path = "/sys/class/backlight/intel_backlight/brightness"
secondary_backlight_path = "/sys/class/backlight/card1-eDP-2-backlight/brightness"
pipe_path = "/run/zenbook-duo-daemon.pipe"
idle_timeout_seconds = 300
fn_lock = true

[keyboard_backlight_key]
KeyboardBacklight = true

[brightness_down_key]
KeyBind = ["KEY_BRIGHTNESSDOWN"]

[brightness_up_key]
KeyBind = ["KEY_BRIGHTNESSUP"]

[swap_up_down_display_key]
NoOp = true

[microphone_mute_key]
KeyBind = ["KEY_MICMUTE"]

[emoji_picker_key]
KeyBind = ["KEY_LEFTCTRL", "KEY_DOT"]

[myasus_key]
NoOp = true

[toggle_secondary_display_key]
ToggleSecondaryDisplay = true
EOF
```

The daemon should parse the config successfully even if it can't access the hardware.
