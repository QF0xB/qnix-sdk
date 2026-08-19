{
  description = "QNix feature and profile SDK";

  outputs =
    { self }:
    let
      sdk = import ./lib;
    in
    {
      lib = sdk;
    };
}
