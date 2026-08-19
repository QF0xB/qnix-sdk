let
  normalizeNamespace =
    namespace:
    let
      normalized = if builtins.isString namespace then [ namespace ] else namespace;
    in
    if
      !builtins.isList normalized
      || normalized == [ ]
      || !builtins.all (part: builtins.isString part && part != "") normalized
    then
      throw "qnix-sdk: namespace must be a non-empty string or list of non-empty strings"
    else
      normalized;

  mkSdk =
    {
      namespace ? "qnix",
    }:
    let
      normalizedNamespace = normalizeNamespace namespace;
      contextModule = import ../modules/context.nix { namespace = normalizedNamespace; };
      featureLib = import ./feature.nix { namespace = normalizedNamespace; };
      profileLib = import ./profile.nix;
      resolveLib = import ./resolve.nix;
      configLib = import ./config.nix { namespace = normalizedNamespace; };
      renderLib = import ./render.nix {
        inherit contextModule;
        inherit (resolveLib) resolveSelection;
      };
      repositoryLib = import ./repository.nix { sdk = instance; };
      instance = {
        namespace = normalizedNamespace;
        inherit contextModule;
        inherit (featureLib) mkFeature;
        inherit (profileLib) mkProfile composeProfiles;
        inherit (configLib)
          getQnixConfig
          getFeatureConfig
          isGraphical
          mkQnixConfig
          setQnixOption
          ;
        inherit (resolveLib) resolveSelection;
        inherit (renderLib) modulesFor;
        inherit (repositoryLib) mkRepository;
      };
    in
    instance;

  defaultSdk = mkSdk { };
in
defaultSdk // { inherit mkSdk; }
