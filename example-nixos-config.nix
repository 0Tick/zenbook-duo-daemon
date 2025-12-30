# Example NixOS Configuration for Zenbook Duo Daemon
# 
# This file shows various configuration examples.
# Copy the relevant sections to your configuration.nix or a separate module.
# 
# Note: This assumes you're importing the flake in your system configuration.
# Add to your flake.nix inputs:
#   inputs.zenbook-duo-daemon.url = "github:PegasisForever/zenbook-duo-daemon";

{ config, pkgs, inputs, ... }:

{
  # === OPTION 1: Basic setup with defaults ===
  # Uncomment this block for minimal configuration:
  
  # services.zenbook-duo-daemon = {
  #   enable = true;
  #   package = inputs.zenbook-duo-daemon.packages.${pkgs.system}.default;
  # };

  # === OPTION 2: Full custom configuration ===
  # This example shows all available configuration options.
  # Remove the options you don't need to customize.
  
  services.zenbook-duo-daemon = {
    enable = true;
    
    # Required: Specify the package from the flake input
    package = inputs.zenbook-duo-daemon.packages.${pkgs.system}.default;
    
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
