# Example NixOS Configuration for Zenbook Duo Daemon
# 
# This file shows various configuration examples.
# Copy the relevant sections to your configuration.nix or a separate module.

{ config, pkgs, ... }:

{
  # Basic setup with defaults
  services.zenbook-duo-daemon.enable = true;

  # Or with custom configuration:
  services.zenbook-duo-daemon = {
    enable = true;
    
    # Optional: Specify a different package (e.g., from a local build)
    # package = pkgs.zenbook-duo-daemon;
    
    # USB device configuration
    # "auto" will auto-detect based on your laptop model
    usbProductId = "auto";  # or "1bf2" for 2025, "1b2c" for 2024
    
    # Idle timeout: time before keyboard backlight turns off (seconds)
    # Set to 0 to disable idle detection
    idleTimeoutSeconds = 300;  # 5 minutes
    
    # Key mappings examples:
    keyMappings = {
      # Example 1: Keep default keyboard backlight toggle
      keyboardBacklight = {
        type = "KeyboardBacklight";
      };
      
      # Example 2: Map a key to a custom command
      # This example would make the MyASUS key take a screenshot
      myasus = {
        type = "Command";
        command = "scrot -s /home/user/screenshots/screenshot-$(date +%Y%m%d-%H%M%S).png";
      };
      
      # Example 3: Remap a key to different keybinds
      # This makes brightness up send Super+Up instead
      brightnessUp = {
        type = "KeyBind";
        keys = [ "KEY_LEFTMETA" "KEY_UP" ];
      };
      
      # Example 4: Disable a key
      swapUpDownDisplay = {
        type = "NoOp";
      };
      
      # Example 5: Multi-key combination
      # Emoji picker to open rofi emoji selector
      emojiPicker = {
        type = "Command";
        command = "rofi -show emoji";
      };
      
      # Example 6: Keep default behavior
      microphoneMute = {
        type = "KeyBind";
        keys = [ "KEY_MICMUTE" ];
      };
      
      brightnessDown = {
        type = "KeyBind";
        keys = [ "KEY_BRIGHTNESSDOWN" ];
      };
      
      toggleSecondaryDisplay = {
        type = "ToggleSecondaryDisplay";
      };
    };
    
    # Custom paths (usually not needed unless your system is different)
    # secondaryDisplayStatusPath = "/sys/class/drm/card1-eDP-2/status";
    # primaryBacklightPath = "/sys/class/backlight/intel_backlight/brightness";
    # secondaryBacklightPath = "/sys/class/backlight/card1-eDP-2-backlight/brightness";
    # pipePath = "/tmp/zenbook-duo-daemon.pipe";
  };
}
