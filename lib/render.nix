{
  resolveSelection,
}:
let
  concatFeatureModules =
    field: features:
    builtins.concatLists (builtins.map (feature: builtins.getAttr field feature) features);

  supports = environment: feature: builtins.elem environment feature.supportedEnvironments;

  commonOwnerModules =
    resolved:
    concatFeatureModules "optionModules" resolved.features
    ++ resolved.defaultModules;

  unsupportedStandalone =
    features: builtins.filter (feature: !supports "standalone-home" feature) features;

  unsupportedIntegrated =
    features: builtins.filter (feature: !supports "integrated-home" feature) features;

  unsupportedMessage =
    environment: features:
    "qnix-sdk: ${environment} does not support: ${builtins.concatStringsSep ", " (builtins.map (feature: feature.name) features)}";

  standaloneModules =
    selection:
    let
      resolved = resolveSelection "standalone-home" selection;
      unsupported = unsupportedStandalone resolved.features;
    in
    if unsupported != [ ] then
      throw (unsupportedMessage "standalone Home Manager" unsupported)
    else
      commonOwnerModules resolved ++ concatFeatureModules "homeModules" resolved.features;

  integratedModules =
    selection:
    let
      resolved = resolveSelection "integrated-home" selection;
      unsupported = unsupportedIntegrated resolved.features;
    in
    if unsupported != [ ] then
      throw (unsupportedMessage "integrated Home Manager" unsupported)
    else
      concatFeatureModules "homeModules" resolved.features;
in
{
  modulesFor = {
    nixos =
      selection:
      let
        resolved = resolveSelection "nixos" selection;
        supported = builtins.filter (supports "nixos") resolved.features;
      in
      commonOwnerModules resolved ++ concatFeatureModules "nixosModules" supported;

    integratedHome = integratedModules;

    standaloneHome = standaloneModules;
  };
}
