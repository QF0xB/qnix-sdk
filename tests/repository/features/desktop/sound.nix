{ integrations }:

{
  environments = [
    "nixos"
    "integrated-home"
    "standalone-home"
  ];

  requires = {
    nixos = [ "base.marker" ];
    home = [ "base.marker" ];
  };

  imports.nixos = [ integrations.testModule ];

  persistence.root.directories = [ "/var/lib/sound" ];

  enableOption.description = "sound support";

  options =
    { lib, ... }:
    {
      volumeStep = lib.mkOption {
        type = lib.types.int;
        default = 5;
      };
    };

  nixos =
    { cfg, context, ... }:
    {
      test.nixosVolume = cfg.volumeStep;
      test.isLaptop = context.laptop;
    };

  home = { cfg, ... }: {
    test.homeVolume = cfg.volumeStep;
  };
}
