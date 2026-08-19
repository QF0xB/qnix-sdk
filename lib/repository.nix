{ sdk }:
let
  validEnvironments = [
    "nixos"
    "integrated-home"
    "standalone-home"
  ];

  hasPrefix =
    prefix: value:
    builtins.stringLength value >= builtins.stringLength prefix
    && builtins.substring 0 (builtins.stringLength prefix) value == prefix;

  hasSuffix =
    suffix: value:
    let
      valueLength = builtins.stringLength value;
      suffixLength = builtins.stringLength suffix;
    in
    valueLength >= suffixLength
    && builtins.substring (valueLength - suffixLength) suffixLength value == suffix;

  dropSuffix =
    suffix: value:
    builtins.substring 0 (builtins.stringLength value - builtins.stringLength suffix) value;

  hasDot = value: builtins.match ".*[.].*" value != null;

  discoverNixFiles =
    root:
    let
      visit =
        directory: prefix:
        builtins.foldl' (
          result: name:
          let
            kind = (builtins.readDir directory).${name};
            path = directory + "/${name}";
          in
          if kind == "directory" then
            if hasDot name then
              throw "qnix-sdk: repository paths cannot contain dots: '${builtins.concatStringsSep "/" (prefix ++ [ name ])}'"
            else
              result // visit path (prefix ++ [ name ])
          else if
            kind == "regular" && hasSuffix ".nix" name && name != "default.nix" && !hasPrefix "_" name
          then
            let
              leaf = dropSuffix ".nix" name;
              optionPath = prefix ++ [ leaf ];
              key = builtins.concatStringsSep "." optionPath;
            in
            if hasDot leaf then
              throw "qnix-sdk: repository paths cannot contain dots: '${builtins.concatStringsSep "/" optionPath}'"
            else
              result
              // {
                ${key} = {
                  inherit path optionPath;
                };
              }
          else
            result
        ) { } (builtins.attrNames (builtins.readDir directory));
    in
    visit root [ ];

  loadDefinition =
    kind: entry: args:
    let
      imported = import entry.path;
      definition = if builtins.isFunction imported then imported args else imported;
    in
    if builtins.isAttrs definition then
      definition
    else
      throw "qnix-sdk: ${kind} '${builtins.concatStringsSep "." entry.optionPath}' must evaluate to an attribute set";

  normalizeImports =
    name: imports:
    if !builtins.isAttrs imports then
      throw "qnix-sdk: feature '${name}' imports must be an attribute set"
    else
      let
        keys = builtins.attrNames imports;
      in
      if
        builtins.any (
          key:
          !builtins.elem key [
            "nixos"
            "integratedHome"
            "standaloneHome"
          ]
        ) keys
      then
        throw "qnix-sdk: feature '${name}' imports only supports 'nixos', 'integratedHome', and 'standaloneHome'"
      else if
        !builtins.all builtins.isList [
          (imports.nixos or [ ])
          (imports.integratedHome or [ ])
          (imports.standaloneHome or [ ])
        ]
      then
        throw "qnix-sdk: feature '${name}' import groups must be lists"
      else
        {
          nixos = imports.nixos or [ ];
          integratedHome = imports.integratedHome or [ ];
          standaloneHome = imports.standaloneHome or [ ];
        };

  evalSpec =
    description: spec: args:
    let
      imported = if builtins.isPath spec then import spec else spec;
      value = if builtins.isFunction imported then imported args else imported;
    in
    if builtins.isAttrs value then
      value
    else
      throw "qnix-sdk: ${description} must evaluate to an attribute set";

  normalizeRequires =
    name: requires:
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
    else if !builtins.all builtins.isString ((requires.nixos or [ ]) ++ (requires.home or [ ])) then
      throw "qnix-sdk: feature '${name}' requirements must be feature-name strings"
    else
      {
        nixos = requires.nixos or [ ];
        home = requires.home or [ ];
      };

  normalizeEnvironments =
    name: definition: imports:
    let
      optionsOnly = definition.optionsOnly or false;
      hasNixos = definition ? nixos || definition ? persistence || imports.nixos != [ ];
      hasIntegratedHome = definition ? home || imports.integratedHome != [ ];
      hasStandaloneHome = definition ? home || imports.standaloneHome != [ ];
      explicit = definition.environments or null;
      standaloneHome = definition.standaloneHome or false;
      inferred =
        (if hasNixos then [ "nixos" ] else [ ])
        ++ (if hasIntegratedHome then [ "integrated-home" ] else [ ])
        ++ (if hasStandaloneHome && standaloneHome then [ "standalone-home" ] else [ ]);
      environments = if explicit == null then inferred else explicit;
      invalid = builtins.filter (environment: !builtins.elem environment validEnvironments) environments;
    in
    if definition ? generateEnable then
      throw "qnix-sdk: feature '${name}' uses removed generateEnable; use optionsOnly for schema features"
    else if explicit != null && definition ? standaloneHome then
      throw "qnix-sdk: feature '${name}' cannot set both environments and standaloneHome"
    else if !builtins.isList environments || !builtins.all builtins.isString environments then
      throw "qnix-sdk: feature '${name}' environments must be a list of strings"
    else if environments == [ ] then
      throw "qnix-sdk: feature '${name}' supports no environments"
    else if invalid != [ ] then
      throw "qnix-sdk: feature '${name}' contains an unsupported environment"
    else if definition ? persistence && !builtins.elem "nixos" environments then
      throw "qnix-sdk: feature '${name}' declares persistence but does not support 'nixos'"
    else if optionsOnly && !(definition ? options) then
      throw "qnix-sdk: option-only feature '${name}' requires options"
    else if
      optionsOnly
      && (
        definition ? nixos
        || definition ? home
        || definition ? persistence
        || imports.nixos != [ ]
        || imports.integratedHome != [ ]
        || imports.standaloneHome != [ ]
      )
    then
      throw "qnix-sdk: option-only feature '${name}' cannot contain implementations, persistence, or imports"
    else if builtins.elem "nixos" environments && !hasNixos && !optionsOnly then
      throw "qnix-sdk: feature '${name}' supports 'nixos' but has no NixOS implementation"
    else if builtins.elem "integrated-home" environments && !hasIntegratedHome && !optionsOnly then
      throw "qnix-sdk: feature '${name}' supports 'integrated-home' but has no integrated Home implementation"
    else if builtins.elem "standalone-home" environments && !hasStandaloneHome && !optionsOnly then
      throw "qnix-sdk: feature '${name}' supports 'standalone-home' but has no standalone Home implementation"
    else
      environments;

  normalizeFeatureList =
    name: value:
    let
      normalized = if builtins.isList value then { shared = value; } else value;
    in
    if !builtins.isAttrs normalized then
      throw "qnix-sdk: profile '${name}' features must be a list or attribute set"
    else
      let
        keys = builtins.attrNames normalized;
      in
      if
        builtins.any (
          key:
          !builtins.elem key [
            "shared"
            "nixos"
            "home"
          ]
        ) keys
      then
        throw "qnix-sdk: profile '${name}' features only supports 'shared', 'nixos', and 'home'"
      else if
        !builtins.all builtins.isList [
          (normalized.shared or [ ])
          (normalized.nixos or [ ])
          (normalized.home or [ ])
        ]
      then
        throw "qnix-sdk: profile '${name}' feature groups must be lists"
      else if
        !builtins.all builtins.isString (
          (normalized.shared or [ ]) ++ (normalized.nixos or [ ]) ++ (normalized.home or [ ])
        )
      then
        throw "qnix-sdk: profile '${name}' features must be feature-name strings"
      else
        {
          shared = normalized.shared or [ ];
          nixos = normalized.nixos or [ ];
          home = normalized.home or [ ];
        };
in
{
  mkRepository =
    {
      features,
      profiles ? null,
      integrations ? { },
    }:
    let
      repositoryArgs = { inherit integrations; };
      featureEntries = discoverNixFiles features;
      rawFeatures = builtins.mapAttrs (
        _: entry: loadDefinition "feature" entry repositoryArgs
      ) featureEntries;

      featureDescriptors = builtins.mapAttrs (
        name: definition:
        let
          entry = featureEntries.${name};
          imports = normalizeImports name (definition.imports or { });
          environments = normalizeEnvironments name definition imports;
          optionsOnly = definition.optionsOnly or false;
          declaredRequires = normalizeRequires name (definition.requires or { });
          stringRequires = declaredRequires // {
            nixos =
              declaredRequires.nixos
              ++ (
                if
                  definition ? persistence && name != "persist" && !builtins.elem "persist" declaredRequires.nixos
                then
                  [ "persist" ]
                else
                  [ ]
              );
          };

          enableOptionModule =
            { lib, ... }:
            let
              overrides = definition.enableOption or { };
              default = overrides.default or true;
              description = overrides.description or name;
            in
            {
              options = lib.setAttrByPath (sdk.namespace ++ entry.optionPath ++ [ "enable" ]) (
                lib.mkEnableOption description // overrides // { inherit default; }
              );
            };

          relativeOptionsModule =
            args@{ lib, ... }:
            {
              options = lib.setAttrByPath (sdk.namespace ++ entry.optionPath) (
                evalSpec "feature '${name}' options" definition.options args
              );
            };

          implementationModule =
            environment: spec:
            args@{
              lib,
              config,
              osConfig ? null,
              ...
            }:
            let
              qnix =
                if environment == "integrated-home" then
                  if osConfig == null then
                    throw "qnix-sdk: integrated Home feature '${name}' requires osConfig"
                  else
                    sdk.getQnixConfig {
                      config = osConfig;
                      inherit osConfig;
                    }
                else
                  sdk.getQnixConfig {
                    inherit config;
                    osConfig = null;
                  };
              cfg = sdk.getFeatureConfig {
                qcfg = qnix;
                optionPath = entry.optionPath;
              };
              featureArgs = args // {
                inherit cfg qnix;
                qcfg = qnix;
                context = qnix.context or { };
              };
              implementationBody =
                if spec == null then
                  { }
                else
                  evalSpec "feature '${name}' ${environment} implementation" spec featureArgs;
              persistenceBody =
                if environment == "nixos" && definition ? persistence then
                  sdk.setQnixOption lib [ "persist" ] (
                    evalSpec "feature '${name}' persistence" definition.persistence featureArgs
                  )
                else
                  { };
              body = lib.mkMerge [
                implementationBody
                persistenceBody
              ];
              enabled =
                if definition ? when then
                  let
                    predicate = definition.when;
                  in
                  if builtins.isFunction predicate then predicate featureArgs else predicate
                else if definition.autoEnable or true then
                  cfg.enable
                else
                  true;
            in
            {
              # Keep the condition lazy. Forcing cfg.enable while the module
              # graph is being collected creates a config fixed-point cycle.
              config = lib.mkIf enabled body;
            };

          optionModules =
            (if optionsOnly then [ ] else [ enableOptionModule ])
            ++ (if definition ? options then [ relativeOptionsModule ] else [ ]);
          nixosModules =
            imports.nixos
            ++ (
              if definition ? nixos || definition ? persistence then
                [ (implementationModule "nixos" (definition.nixos or null)) ]
              else
                [ ]
            );
          homeModuleFor =
            environment:
            let
              upstream =
                if environment == "integrated-home" then imports.integratedHome else imports.standaloneHome;
            in
            upstream
            ++ (if definition ? home then [ (implementationModule environment definition.home) ] else [ ]);
        in
        {
          __qnixType = "feature";
          inherit
            name
            environments
            optionModules
            nixosModules
            ;
          optionPath = entry.optionPath;
          description = definition.description or name;
          source = entry.path;
          supportedEnvironments = environments;
          requires = {
            nixos = builtins.map (
              dependency:
              featureDescriptors.${dependency}
                or (throw "qnix-sdk: feature '${name}' requires unknown feature '${dependency}'")
            ) stringRequires.nixos;
            home = builtins.map (
              dependency:
              featureDescriptors.${dependency}
                or (throw "qnix-sdk: feature '${name}' requires unknown feature '${dependency}'")
            ) stringRequires.home;
          };
          homeModules =
            if definition ? home || imports.integratedHome != [ ] || imports.standaloneHome != [ ] then
              # The renderer chooses the environment-specific wrapper below.
              [ true ]
            else
              [ ];
          __requiresNames = stringRequires;
          __homeModuleFor = homeModuleFor;
        }
      ) rawFeatures;

      # The core renderer stores one Home module list on a descriptor. Replace it
      # per render so injected configuration comes from the correct owner.
      featuresFor =
        environment:
        let
          environmentFeatures = builtins.mapAttrs (
            name: feature:
            feature
            // {
              requires = {
                nixos = builtins.map (
                  dependency:
                  environmentFeatures.${dependency}
                    or (throw "qnix-sdk: feature '${name}' requires unknown feature '${dependency}'")
                ) feature.__requiresNames.nixos;
                home = builtins.map (
                  dependency:
                  environmentFeatures.${dependency}
                    or (throw "qnix-sdk: feature '${name}' requires unknown feature '${dependency}'")
                ) feature.__requiresNames.home;
              };
              homeModules =
                if feature ? __homeModuleFor && feature.homeModules != [ ] then
                  feature.__homeModuleFor environment
                else
                  [ ];
            }
          ) featureDescriptors;
        in
        environmentFeatures;

      profileEntries = if profiles == null then { } else discoverNixFiles profiles;
      rawProfiles = builtins.mapAttrs (
        _: entry: loadDefinition "profile" entry repositoryArgs
      ) profileEntries;

      profileDescriptorsFor =
        environment:
        let
          environmentFeatures = featuresFor environment;
          descriptors = builtins.mapAttrs (
            name: definition:
            let
              featureGroups = normalizeFeatureList name (definition.features or [ ]);
              selectedNames =
                if environment == "nixos" then
                  featureGroups.shared ++ featureGroups.nixos ++ featureGroups.home
                else
                  featureGroups.shared ++ featureGroups.home;
              lookupFeature =
                featureName:
                environmentFeatures.${featureName}
                  or (throw "qnix-sdk: profile '${name}' references unknown feature '${featureName}'");
              defaults = definition.defaults or { };
              environmentDefaults = defaults.__qnixEnvironment or { };
              directDefaults = builtins.removeAttrs defaults [ "__qnixEnvironment" ];
              defaultValues =
                [ directDefaults ]
                ++ (if environment == "nixos" then
                  [
                    (environmentDefaults.shared or { })
                    (environmentDefaults.nixos or { })
                    (environmentDefaults.home or { })
                  ]
                else
                  [
                    (environmentDefaults.shared or { })
                    (environmentDefaults.home or { })
                  ]);
              defaultModules = builtins.map (
                values:
                { lib, ... }:
                sdk.mkQnixConfig lib (lib.mapAttrsRecursive (_: value: lib.mkDefault value) values)
              ) (builtins.filter (values: values != { }) defaultValues);
            in
            sdk.mkProfile {
              inherit name defaultModules;
              source = profileEntries.${name}.path;
              imports = builtins.map (
                imported:
                descriptors.${imported}
                  or (throw "qnix-sdk: profile '${name}' imports unknown profile '${imported}'")
              ) (definition.imports or [ ]);
              features = builtins.map lookupFeature selectedNames;
            }
          ) rawProfiles;
        in
        descriptors;

      selectionFor =
        environment: names:
        let
          availableProfiles = profileDescriptorsFor environment;
        in
        sdk.composeProfiles (
          builtins.map (
            name: availableProfiles.${name} or (throw "qnix-sdk: unknown profile '${name}'")
          ) names
        );

      modulesForNames = {
        nixos = names: sdk.modulesFor.nixos (selectionFor "nixos" names);
        integratedHome = names: sdk.modulesFor.integratedHome (selectionFor "integrated-home" names);
        standaloneHome = names: sdk.modulesFor.standaloneHome (selectionFor "standalone-home" names);
      };

      select = names: {
        inherit names;
        nixosModules = modulesForNames.nixos names;
        integratedHomeModules = modulesForNames.integratedHome names;
        standaloneHomeModules = modulesForNames.standaloneHome names;
        nixosModule.imports = modulesForNames.nixos names;
        integratedHomeModule.imports = modulesForNames.integratedHome names;
        standaloneHomeModule.imports = modulesForNames.standaloneHome names;
      };
    in
    {
      inherit select;
      features = featureDescriptors;
      profileNames = builtins.attrNames rawProfiles;
      featureNames = builtins.attrNames rawFeatures;
      modulesFor = modulesForNames;
    };
}
