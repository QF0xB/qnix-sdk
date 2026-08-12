{
  description = "QNix SDK test flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    {
      checks.x86_64-linux.default =
        let
          pkgs = import nixpkgs { system = "x86_64-linux"; };
          testResult = import ./default.nix { lib = pkgs.lib; };
        in
        pkgs.writeText "qnix-sdk-tests.json" (builtins.toJSON testResult);
    };
}
