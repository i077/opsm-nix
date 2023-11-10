{
  description = "System secret management with 1Password";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }: {
    nixosModules.default = import ./modules/opsm-nixos.nix;
  };
}
