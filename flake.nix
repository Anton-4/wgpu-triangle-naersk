{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=release-21.11";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = { url = "github:oxalica/rust-overlay"; inputs.nixpkgs.follows = "nixpkgs"; inputs.flake-utils.follows = "flake-utils"; }; # rust from nixpkgs has some libc problems, this is patched in the rust-overlay
    naersk = { url = "github:nix-community/naersk"; inputs.nixpkgs.follows = "nixpkgs"; };# to easily build rust crates with nix
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, naersk }:
    let
      supportedSystems = [ "x86_64-linux"];
    in
      flake-utils.lib.eachSystem supportedSystems (system:
        let
          overlays = [ rust-overlay.overlay ];
          pkgs = import nixpkgs { 
            inherit system overlays;
          };

          # get current working directory
          cwd = builtins.toString ./.;
          rust = pkgs.rust-bin.fromRustupToolchainFile "${cwd}/rust-toolchain.toml";

          # make naersk use our rust version
          naersk-lib = naersk.lib."${system}".override {
            cargo = rust;
            rustc = rust;
          };

          linuxInputs = with pkgs;
            [
              vulkan-loader
              vulkan-headers
              vulkan-tools
              vulkan-validation-layers
              libxkbcommon
              libGL
              xorg.libXcursor
              xorg.libXrandr
              xorg.libXi
              xorg.libX11
            ];

          lib_path = with pkgs;
              lib.makeLibraryPath
              linuxInputs;
        in rec {

          # nix build
          packages.wgpu-triangle = naersk-lib.buildPackage {
            pname = "wgpu-triangle";
            root = ./.;
            buildInputs = linuxInputs;

            RUST_BACKTRACE = "1";

            nativeBuildInputs = with pkgs; [
              pkg-config
              makeWrapper # to be able to use wrapProgram
            ];
            postInstall = ''
              wrapProgram $out/bin/wgpu-triangle --set LD_LIBRARY_PATH "${lib_path}"
             '';
          };

          defaultPackage = packages.wgpu-triangle;

      }
    );
}