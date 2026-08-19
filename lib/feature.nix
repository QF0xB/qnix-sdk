{ namespace }:
let
  validEnvironments = [
    "nixos"
    "integrated-home"
    "standalone-home"
  ];

  validateFeature =
    feature:
    if !builtins.isString feature.name || feature.name == "" then
      throw "qnix-sdk: a feature requires a non-empty name"
    else if
      !builtins.isList feature.optionPath
      || feature.optionPath == [ ]
      || !builtins.all (part: builtins.isString part && part != "") feature.optionPath
    then
      throw "qnix-sdk: feature '${feature.name}' requires a non-empty string optionPath"
    else if
      !builtins.isList feature.supportedEnvironments
      || feature.supportedEnvironments == [ ]
      || !builtins.all builtins.isString feature.supportedEnvironments
    then
      throw "qnix-sdk: feature '${feature.name}' requires at least one supported environment"
    else if
      !builtins.all (
        environment: builtins.elem environment validEnvironments
      ) feature.supportedEnvironments
    then
      throw "qnix-sdk: feature '${feature.name}' contains an unsupported environment"
    else if feature.nixosModules != [ ] && !builtins.elem "nixos" feature.supportedEnvironments then
      throw "qnix-sdk: feature '${feature.name}' has NixOS modules but does not support 'nixos'"
    else if
      feature.homeModules != [ ]
      && !builtins.elem "integrated-home" feature.supportedEnvironments
      && !builtins.elem "standalone-home" feature.supportedEnvironments
    then
      throw "qnix-sdk: feature '${feature.name}' has Home Manager modules but supports no Home environment"
    else if
      builtins.elem "integrated-home" feature.supportedEnvironments && feature.homeModules == [ ]
    then
      throw "qnix-sdk: feature '${feature.name}' supports 'integrated-home' but has no Home Manager modules"
    else if
      builtins.elem "standalone-home" feature.supportedEnvironments && feature.homeModules == [ ]
    then
      throw "qnix-sdk: feature '${feature.name}' supports 'standalone-home' but has no Home Manager modules"
    else
      feature;
in
{
  mkFeature =
    {
      name,
      optionPath,
      description ? name,
      source ? null,
      requires ? { },
      optionModules ? [ ],
      nixosModules ? [ ],
      homeModules ? [ ],
      supportedEnvironments,
    }:
    let
      normalizedRequires =
        if !builtins.isAttrs requires then
          throw "qnix-sdk: feature '${name}' requires must be an attribute set"
        else if
          builtins.any (
            key:
            !builtins.elem key [
              "nixos"
              "home"
            ]
          ) (builtins.attrNames requires)
        then
          throw "qnix-sdk: feature '${name}' requires only supports 'nixos' and 'home'"
        else if !builtins.isList (requires.nixos or [ ]) || !builtins.isList (requires.home or [ ]) then
          throw "qnix-sdk: feature '${name}' requires.nixos and requires.home must be lists"
        else
          {
            nixos = requires.nixos or [ ];
            home = requires.home or [ ];
          };

      enableOptionModule =
        { lib, ... }:
        {
          options = lib.setAttrByPath (namespace ++ optionPath ++ [ "enable" ]) (
            lib.mkEnableOption description
            // {
              default = true;
            }
          );
        };
    in
    validateFeature {
      __qnixType = "feature";
      inherit
        name
        optionPath
        description
        source
        nixosModules
        homeModules
        supportedEnvironments
        ;
      requires = normalizedRequires;
      optionModules = [ enableOptionModule ] ++ optionModules;
    };
}
