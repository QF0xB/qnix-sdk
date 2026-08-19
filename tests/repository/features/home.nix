{
  environments = [ "nixos" ];

  options =
    { lib, ... }:
    {
      value = lib.mkOption {
        type = lib.types.int;
        default = 0;
      };
    };

  nixos = { ... }: { };
}
