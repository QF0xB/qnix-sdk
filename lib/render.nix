{
  contextModule,
  resolveSelection,
}:
let
  concatFeatureModules =
    field: features:
    builtins.concatLists (builtins.map (feature: builtins.getAttr field feature) features);

  supports = environment: feature: builtins.elem environment feature.supportedEnvironments;

  commonOwnerModules =
    resolved:
    [ contextModule ]
    ++ concatFeatureModules "optionModules" resolved.features
    ++ resolved.defaultModules;

  unsupportedStandalone =
    features: builtins.filter (feature: !supports "standalone-home" feature) features;

  standaloneModules =
    selection:
    let
      resolved = resolveSelection "standalone-home" selection;
      unsupported = unsupportedStandalone resolved.features;
      unsupportedNames = builtins.map (feature: feature.name) unsupported;
    in
    if unsupported != [ ] then
      throw "qnix-sdk: standalone Home Manager does not support: ${builtins.concatStringsSep ", " unsupportedNames}"
    else
      commonOwnerModules resolved ++ concatFeatureModules "homeModules" resolved.features;
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

    integratedHome =
      selection:
      let
        resolved = resolveSelection "integrated-home" selection;
        supported = builtins.filter (supports "integrated-home") resolved.features;
      in
      concatFeatureModules "homeModules" supported;

    standaloneHome = standaloneModules;
  };
}
