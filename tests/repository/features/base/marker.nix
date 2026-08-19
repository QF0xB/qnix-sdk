{
  environments = [
    "nixos"
    "integrated-home"
    "standalone-home"
  ];

  options =
    { lib, ... }:
    {
      label = lib.mkOption {
        type = lib.types.str;
        default = "dependency";
      };
    };

  nixos = { cfg, ... }: {
    test.dependencyLabel = cfg.label;
  };

  home = { cfg, ... }: {
    test.dependencyLabel = cfg.label;
  };
}
