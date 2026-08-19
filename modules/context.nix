{ namespace }:
{ lib, ... }:
{
  imports = builtins.map (
    property:
    lib.mkAliasOptionModule
      (namespace ++ [ property ])
      (namespace ++ [ "context" property ])
  ) [
    "headless"
    "iso"
    "vm"
    "laptop"
  ];

  options = lib.setAttrByPath (namespace ++ [ "context" ]) {
    headless = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the environment has no graphical session.";
    };

    iso = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the environment is running from an installation ISO.";
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
