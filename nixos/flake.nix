{
  description = "NixOS configuration for the homelab Mac Mini";

  inputs = {
    nixos-apple-silicon.url = "github:nix-community/nixos-apple-silicon/release-2026-07-30";
    nixpkgs.follows = "nixos-apple-silicon/nixpkgs";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixos-apple-silicon,
      disko,
      ...
    }:
    {
      nixosConfigurations.macmini = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          nixos-apple-silicon.nixosModules.apple-silicon-support
          disko.nixosModules.disko
          ./hosts/macmini
        ];
      };
    };
}
