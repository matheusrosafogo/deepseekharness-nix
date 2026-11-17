{
  description = "DeepSeek Harness para Nix/NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      deepseek-harness = pkgs.callPackage ./package.nix { };
    in
    {
      packages.${system} = {
        default = deepseek-harness;
        deepseek-harness = deepseek-harness;
      };

      nixosModules.deepseek-harness =
        { pkgs, lib, ... }:
        {
          environment.systemPackages = lib.optional (
            pkgs.stdenv.hostPlatform.system == system
          ) self.packages.${system}.default;
        };

      nixosModules.default = self.nixosModules.deepseek-harness;

      overlays.default =
        final: prev:
        if final.system == system then
          {
            deepseek-harness = self.packages.${system}.default;
          }
        else
          { };
    };
}
