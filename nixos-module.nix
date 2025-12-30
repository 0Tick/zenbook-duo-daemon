{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.zenbook-duo-daemon;

  # Helper function to convert key function configuration to TOML format
  keyFunctionToToml = keyFunc:
    if keyFunc.type == "KeyBind" then
      "KeyBind = [${concatMapStringsSep ", " (k: ''"${k}"'') keyFunc.keys}]"
    else if keyFunc.type == "Command" then
      ''Command = "${keyFunc.command}"''
    else if keyFunc.type == "KeyboardBacklight" then
      "KeyboardBacklight = true"
    else if keyFunc.type == "ToggleSecondaryDisplay" then
      "ToggleSecondaryDisplay = true"
    else if keyFunc.type == "NoOp" then
      "NoOp = true"
    else
      throw "Unknown key function type: ${keyFunc.type}";

  # Generate config file content
  configFile = pkgs.writeText "zenbook-duo-daemon-config.toml" ''
    usb_vendor_id = "${cfg.usbVendorId}"
    usb_product_id = "${cfg.usbProductId}"
    secondary_display_status_path = "${cfg.secondaryDisplayStatusPath}"
    primary_backlight_path = "${cfg.primaryBacklightPath}"
    secondary_backlight_path = "${cfg.secondaryBacklightPath}"
    pipe_path = "${cfg.pipePath}"
    idle_timeout_seconds = ${toString cfg.idleTimeoutSeconds}

    [keyboard_backlight_key]
    ${keyFunctionToToml cfg.keyMappings.keyboardBacklight}

    [brightness_down_key]
    ${keyFunctionToToml cfg.keyMappings.brightnessDown}

    [brightness_up_key]
    ${keyFunctionToToml cfg.keyMappings.brightnessUp}

    [swap_up_down_display_key]
    ${keyFunctionToToml cfg.keyMappings.swapUpDownDisplay}

    [microphone_mute_key]
    ${keyFunctionToToml cfg.keyMappings.microphoneMute}

    [emoji_picker_key]
    ${keyFunctionToToml cfg.keyMappings.emojiPicker}

    [myasus_key]
    ${keyFunctionToToml cfg.keyMappings.myasus}

    [toggle_secondary_display_key]
    ${keyFunctionToToml cfg.keyMappings.toggleSecondaryDisplay}
  '';

  keyFunctionOption = mkOption {
    type = types.submodule {
      options = {
        type = mkOption {
          type = types.enum [ "KeyBind" "Command" "KeyboardBacklight" "ToggleSecondaryDisplay" "NoOp" ];
          description = "Type of key function";
        };
        keys = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "List of keys for KeyBind type (e.g., [\"KEY_LEFTCTRL\" \"KEY_F10\"])";
        };
        command = mkOption {
          type = types.str;
          default = "";
          description = "Command to execute for Command type";
        };
      };
    };
  };

in
{
  options.services.zenbook-duo-daemon = {
    enable = mkEnableOption "Zenbook Duo Daemon for ASUS Zenbook Duo laptops";

    package = mkOption {
      type = types.package;
      default = pkgs.zenbook-duo-daemon or (import ./. { inherit pkgs; }).packages.${pkgs.system}.default;
      defaultText = literalExpression "pkgs.zenbook-duo-daemon";
      description = "The zenbook-duo-daemon package to use";
    };

    usbVendorId = mkOption {
      type = types.str;
      default = "0b05";
      description = "USB vendor ID of the keyboard (hex string)";
    };

    usbProductId = mkOption {
      type = types.str;
      default = "auto";
      description = ''
        USB product ID of the keyboard (hex string).
        Set to "auto" to auto-detect based on board name.
        Use "1bf2" for Zenbook Duo 2025 (UX8406CA) or "1b2c" for Zenbook Duo 2024 (UX8406MA).
      '';
    };

    secondaryDisplayStatusPath = mkOption {
      type = types.str;
      default = "/sys/class/drm/card1-eDP-2/status";
      description = "Path to secondary display status file";
    };

    primaryBacklightPath = mkOption {
      type = types.str;
      default = "/sys/class/backlight/intel_backlight/brightness";
      description = "Path to primary display backlight control";
    };

    secondaryBacklightPath = mkOption {
      type = types.str;
      default = "/sys/class/backlight/card1-eDP-2-backlight/brightness";
      description = "Path to secondary display backlight control";
    };

    pipePath = mkOption {
      type = types.str;
      default = "/tmp/zenbook-duo-daemon.pipe";
      description = "Path to the control pipe for sending commands to the daemon";
    };

    idleTimeoutSeconds = mkOption {
      type = types.int;
      default = 300;
      description = "Idle timeout in seconds before disabling keyboard backlight (0 to disable)";
    };

    keyMappings = {
      keyboardBacklight = mkOption {
        type = keyFunctionOption;
        default = { type = "KeyboardBacklight"; };
        description = "Keyboard backlight key mapping";
      };

      brightnessDown = mkOption {
        type = keyFunctionOption;
        default = { type = "KeyBind"; keys = [ "KEY_BRIGHTNESSDOWN" ]; };
        description = "Brightness down key mapping";
      };

      brightnessUp = mkOption {
        type = keyFunctionOption;
        default = { type = "KeyBind"; keys = [ "KEY_BRIGHTNESSUP" ]; };
        description = "Brightness up key mapping";
      };

      swapUpDownDisplay = mkOption {
        type = keyFunctionOption;
        default = { type = "NoOp"; };
        description = "Swap up/down display key mapping";
      };

      microphoneMute = mkOption {
        type = keyFunctionOption;
        default = { type = "KeyBind"; keys = [ "KEY_MICMUTE" ]; };
        description = "Microphone mute key mapping";
      };

      emojiPicker = mkOption {
        type = keyFunctionOption;
        default = { type = "KeyBind"; keys = [ "KEY_LEFTCTRL" "KEY_DOT" ]; };
        description = "Emoji picker key mapping";
      };

      myasus = mkOption {
        type = keyFunctionOption;
        default = { type = "NoOp"; };
        description = "MyASUS key mapping";
      };

      toggleSecondaryDisplay = mkOption {
        type = keyFunctionOption;
        default = { type = "ToggleSecondaryDisplay"; };
        description = "Toggle secondary display key mapping";
      };
    };
  };

  config = mkIf cfg.enable {
    # Install the package
    environment.systemPackages = [ cfg.package ];

    # Determine the actual product ID
    # When set to "auto", the daemon will detect it at runtime
    # But we need to provide a valid hex value for the config file
    services.zenbook-duo-daemon.usbProductId = mkIf (cfg.usbProductId == "auto") (
      mkDefault "1b2c"  # Default to 2024 model, daemon will auto-detect anyway
    );

    # Create the config directory and file
    environment.etc."zenbook-duo-daemon/config.toml".source = configFile;

    # Main daemon service
    systemd.services.zenbook-duo-daemon = {
      description = "Zenbook Duo Daemon";
      after = [ "sysinit.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Environment = "RUST_LOG=info";
        ExecStart = "${cfg.package}/bin/zenbook-duo-daemon run --config-path /etc/zenbook-duo-daemon/config.toml";
        Restart = "on-failure";
        RestartSec = 1;
        StandardOutput = "journal";
        StandardError = "journal";
      };

      # Rate limiting for restarts
      startLimitIntervalSec = 300;
      startLimitBurst = 5;
    };

    # Pre-sleep service
    systemd.services.zenbook-duo-daemon-pre-sleep = {
      description = "Notify Zenbook Duo daemon before sleep";
      before = [ "sleep.target" ];
      wantedBy = [ "sleep.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/timeout 1 ${pkgs.bash}/bin/bash -c 'echo suspend_start > ${cfg.pipePath} && sleep 0.5'";
      };
    };

    # Post-sleep service
    systemd.services.zenbook-duo-daemon-post-sleep = {
      description = "Notify Zenbook Duo daemon after sleep";
      after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
      wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/timeout 1 ${pkgs.bash}/bin/bash -c 'echo suspend_end > ${cfg.pipePath}'";
      };
    };
  };
}
