{
  description = "Daemon for ASUS Zenbook Duo laptops to handle keyboard and secondary display";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Overlay to add the package to nixpkgs
      overlay = final: prev: {
        zenbook-duo-daemon = self.packages.${final.system}.default;
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
          default = pkgs.rustPlatform.buildRustPackage rec {
            pname = "zenbook-duo-daemon";
            version = "1.0.1";

            src = ./.;

            cargoLock = {
              lockFile = ./Cargo.lock;
            };

            nativeBuildInputs = with pkgs; [
              pkg-config
            ];

            buildInputs = with pkgs; [
              libevdev
              dbus
            ];

            # The daemon needs to run as root and access hardware devices
            # Installation and permissions are handled by the NixOS module
            postInstall = ''
              # Services will be installed by the NixOS module
              mkdir -p $out/lib/systemd/system
              cp ${./zenbook-duo-daemon.service} $out/lib/systemd/system/
              cp ${./zenbook-duo-daemon-pre-sleep.service} $out/lib/systemd/system/
              cp ${./zenbook-duo-daemon-post-sleep.service} $out/lib/systemd/system/
            '';

            meta = with pkgs.lib; {
              description = "Daemon for ASUS Zenbook Duo laptops to handle keyboard and secondary display";
              homepage = "https://github.com/PegasisForever/zenbook-duo-daemon";
              license = licenses.mit;
              maintainers = [ ];
              platforms = platforms.linux;
            };
          };
        };

        # Development shell with all dependencies
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustc
            cargo
            pkg-config
            libevdev
            dbus
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
      
      # Export the overlay
      overlays.default = overlay;
    };
}
