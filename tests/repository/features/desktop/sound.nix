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

  persistence.root.directories = [ "/var/lib/sound" ];

  enableOption.description = "sound support";

  options =
    {
      isGraphical,
      lib,
      ...
    }:
    {
      volumeStep = lib.mkOption {
        type = lib.types.int;
        default = 5;
      };

      graphical = lib.mkOption {
        type = lib.types.bool;
        default = isGraphical;
      };
    };

  nixos =
    { cfg, context, ... }:
    {
      test.nixosVolume = cfg.volumeStep;
      test.isLaptop = context.laptop;
      test.isGraphical = cfg.graphical;
    };

  home = { cfg, ... }: {
    test.homeVolume = cfg.volumeStep;
  };
}
