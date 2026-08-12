{ namespace }:
{ lib, ... }:
{
  options = lib.setAttrByPath (namespace ++ [ "context" ]) {
    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the environment has no graphical session.";
    };

    vm = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the environment is a virtual machine.";
    };

    laptop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the environment is a laptop.";
    };
  };
}
