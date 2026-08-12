let
  emptyProfileState = {
    byName = { };
    order = [ ];
  };

  emptyFeatureState = {
    byName = { };
    byOptionPath = { };
    order = [ ];
  };

  identityOf = value: if value.source == null then value.name else toString value.source;

  assertDescriptor =
    expected: value:
    if value ? __qnixType && value.__qnixType == expected then
      value
    else
      throw "qnix-sdk: expected a ${expected} descriptor";

  visitProfile =
    state: stack: rawProfile:
    let
      profile = assertDescriptor "profile" rawProfile;
      existing = state.byName.${profile.name} or null;
    in
    if builtins.elem profile.name stack then
      throw "qnix-sdk: profile dependency cycle: ${
        builtins.concatStringsSep " -> " (stack ++ [ profile.name ])
      }"
    else if existing != null then
      if identityOf existing == identityOf profile then
        state
      else
        throw "qnix-sdk: duplicate profile name '${profile.name}'"
    else
      let
        withImports = builtins.foldl' (
          current: imported: visitProfile current (stack ++ [ profile.name ]) imported
        ) state profile.imports;
      in
      {
        byName = withImports.byName // {
          ${profile.name} = profile;
        };
        order = withImports.order ++ [ profile ];
      };

  collectProfiles =
    profiles:
    builtins.foldl' (state: profile: visitProfile state [ ] profile) emptyProfileState profiles;

  requirementsFor =
    mode: feature:
    if mode == "nixos" then feature.requires.nixos ++ feature.requires.home else feature.requires.home;

  visitFeature =
    mode: state: stack: rawFeature:
    let
      feature = assertDescriptor "feature" rawFeature;
      existing = state.byName.${feature.name} or null;
      optionKey = builtins.concatStringsSep "." feature.optionPath;
      optionOwner = state.byOptionPath.${optionKey} or null;
    in
    if builtins.elem feature.name stack then
      throw "qnix-sdk: feature dependency cycle: ${
        builtins.concatStringsSep " -> " (stack ++ [ feature.name ])
      }"
    else if existing != null then
      if identityOf existing == identityOf feature then
        state
      else
        throw "qnix-sdk: duplicate feature name '${feature.name}'"
    else if optionOwner != null && optionOwner != feature.name then
      throw "qnix-sdk: features '${optionOwner}' and '${feature.name}' use the same option path '${optionKey}'"
    else
      let
        withRequirements = builtins.foldl' (
          current: dependency: visitFeature mode current (stack ++ [ feature.name ]) dependency
        ) state (requirementsFor mode feature);
        dependencyOptionOwner = withRequirements.byOptionPath.${optionKey} or null;
      in
      if dependencyOptionOwner != null && dependencyOptionOwner != feature.name then
        throw "qnix-sdk: features '${dependencyOptionOwner}' and '${feature.name}' use the same option path '${optionKey}'"
      else
        {
          byName = withRequirements.byName // {
            ${feature.name} = feature;
          };
          byOptionPath = withRequirements.byOptionPath // {
            ${optionKey} = feature.name;
          };
          order = withRequirements.order ++ [ feature ];
        };

  collectFeatures =
    mode: features:
    builtins.foldl' (state: feature: visitFeature mode state [ ] feature) emptyFeatureState features;
in
{
  resolveSelection =
    mode: selection:
    if !(selection ? __qnixType) || selection.__qnixType != "selection" then
      throw "qnix-sdk: expected a profile selection"
    else
      let
        profiles = collectProfiles selection.profiles;
        rootFeatures = builtins.concatLists (builtins.map (profile: profile.features) profiles.order);
        features = collectFeatures mode rootFeatures;
      in
      {
        inherit (profiles) order;
        profiles = profiles.order;
        features = features.order;
        defaultModules = builtins.concatLists (
          builtins.map (profile: profile.defaultModules) profiles.order
        );
      };
}
