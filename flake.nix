{
  description = "QNix feature and profile SDK";

  outputs =
    { self }:
    let
      sdk = import ./lib;
    in
    {
      lib = sdk;
      nixosModules.context = sdk.contextModule;
      homeManagerModules.context = sdk.contextModule;
    };
}
