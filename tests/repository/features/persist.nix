{
  environments = [ "nixos" ];
  optionsOnly = true;

  options =
    { lib, ... }:
    {
      root.directories = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };

      users = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.directories = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
          }
        );
        default = { };
      };
    };
}
