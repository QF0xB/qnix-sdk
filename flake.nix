{
  description = "QNix feature and profile SDK";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      sdk = import ./lib;
    in
    {
      lib = sdk;
      nixosModules.context = sdk.contextModule;
      homeManagerModules.context = sdk.contextModule;
      checks.x86_64-linux.default =
        let
          pkgs = import nixpkgs { system = "x86_64-linux"; };
          testResult = import ./tests/default.nix { lib = pkgs.lib; };
        in
        pkgs.writeText "qnix-sdk-tests.json" (builtins.toJSON testResult);
    };
}
