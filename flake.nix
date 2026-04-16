{
  description = "Daemon for ASUS Zenbook Duo laptops to handle keyboard and secondary display";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      version = "1.2.0";
      
      # Shared package builder function
      mkPackage = { rustPlatform, pkg-config, libevdev, dbus, libpulseaudio, lib, src }:
        rustPlatform.buildRustPackage rec {
          pname = "zenbook-duo-daemon";
          inherit version;
          inherit src;

          cargoLock = {
            lockFile = src + "/Cargo.lock";
          };

          nativeBuildInputs = [ pkg-config ];
          buildInputs = [ libevdev dbus libpulseaudio ];

          # Tests require hardware access and root permissions, not available in sandbox
          doCheck = false;

          # Service files included for manual installation outside NixOS module
          postInstall = ''
            mkdir -p $out/lib/systemd/system
            cp ${src}/zenbook-duo-daemon.service $out/lib/systemd/system/
            cp ${src}/zenbook-duo-daemon-pre-sleep.service $out/lib/systemd/system/
            cp ${src}/zenbook-duo-daemon-post-sleep.service $out/lib/systemd/system/
          '';

          meta = with lib; {
            description = "Daemon for ASUS Zenbook Duo laptops to handle keyboard and secondary display";
            homepage = "https://github.com/PegasisForever/zenbook-duo-daemon";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.linux;
          };
        };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        packages = {
          default = pkgs.callPackage mkPackage { src = ./.; };
        };

        # Development shell with all dependencies
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustc
            cargo
            pkg-config
            libevdev
            dbus
            libpulseaudio
            rust-analyzer
            clippy
            rustfmt
          ];

          RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
        };
      }
    ) // {
      # NixOS module - available on all systems
      nixosModules.default = import ./nixos-module.nix;
      
      # Overlay to add the package to nixpkgs
      overlays.default = final: prev: {
        zenbook-duo-daemon = final.callPackage mkPackage { src = self; };
      };
    };
}
