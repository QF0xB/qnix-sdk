{ lib }:
let
  defaultSdk = import ../lib;
  sdk = defaultSdk.mkSdk {
    namespace = [
      "custom"
      "qnix"
    ];
    context = {
      laptop = true;
      location = "test-lab";
    };
  };

  polkit = sdk.mkFeature {
    name = "polkit";
    optionPath = [
      "security"
      "polkit"
    ];
    supportedEnvironments = [ "nixos" ];
  };

  xdg = sdk.mkFeature {
    name = "xdg";
    optionPath = [
      "home"
      "xdg"
    ];
    supportedEnvironments = [
      "integrated-home"
      "standalone-home"
    ];
    homeModules = [ ({ ... }: { }) ];
  };

  desktop = sdk.mkFeature {
    name = "desktop";
    optionPath = [
      "desktop"
      "test"
    ];
    supportedEnvironments = [
      "nixos"
      "integrated-home"
    ];
    requires = {
      nixos = [ polkit ];
      home = [ xdg ];
    };
    homeModules = [ ({ ... }: { }) ];
  };

  profile = sdk.mkProfile {
    name = "desktop";
    features = [ desktop ];
  };

  selection = sdk.composeProfiles [ profile ];
  nixosResolved = sdk.resolveSelection "nixos" selection;
  homeResolved = sdk.resolveSelection "integrated-home" selection;
  evaluated = lib.evalModules {
    modules = sdk.modulesFor.nixos selection;
  };

  testOptionsModule = {
    options.test = {
      dependencyLabel = lib.mkOption {
        type = lib.types.str;
        default = "missing";
      };
      nixosVolume = lib.mkOption {
        type = lib.types.int;
        default = 0;
      };
      homeVolume = lib.mkOption {
        type = lib.types.int;
        default = 0;
      };
      isLaptop = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      portalLoaded = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      inferredNixos = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      inferredHome = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      statefulHomeLoaded = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };

  repository = sdk.mkRepository {
    features = ./repository/features;
    profiles = ./repository/profiles;
  };

  repositoryNixos = lib.evalModules {
    modules = [ testOptionsModule ] ++ repository.modulesFor.nixos [ "integrated" ];
  };

  repositoryIntegratedHome = lib.evalModules {
    specialArgs.osConfig = repositoryNixos.config;
    modules = [ testOptionsModule ] ++ repository.modulesFor.integratedHome [ "integrated" ];
  };

  repositoryStandaloneHome = lib.evalModules {
    modules = [ testOptionsModule ] ++ repository.modulesFor.standaloneHome [ "audio" ];
  };

  repositoryDirectHomeDefault = lib.evalModules {
    modules = [ testOptionsModule ] ++ repository.modulesFor.nixos [ "direct-home-default" ];
  };

  disabledRepositoryNixos = lib.evalModules {
    modules = [
      testOptionsModule
      {
        custom.qnix.desktop.sound.enable = false;
      }
    ]
    ++ repository.modulesFor.nixos [ "audio" ];
  };

  unsupportedStandalone = builtins.tryEval (
    builtins.length (repository.modulesFor.standaloneHome [ "integrated" ])
  );

  unsupportedIntegrated = builtins.tryEval (
    builtins.length (sdk.modulesFor.integratedHome (sdk.composeProfiles [
      (sdk.mkProfile {
        name = "unsupported-integrated";
        features = [ polkit ];
      })
    ]))
  );

  invalidRequires = builtins.tryEval (
    (sdk.mkFeature {
      name = "invalid";
      optionPath = [ "invalid" ];
      supportedEnvironments = [ "nixos" ];
      requires.hmoe = [ ];
    }).requires
  );

  standaloneDependency = sdk.mkFeature {
    name = "standalone-dependency";
    optionPath = [ "standalone-dependency" ];
    supportedEnvironments = [ "standalone-home" ];
    homeModules = [ ({ ... }: { }) ];
  };

  integratedDependent = sdk.mkFeature {
    name = "integrated-dependent";
    optionPath = [ "integrated-dependent" ];
    supportedEnvironments = [ "integrated-home" ];
    requires.home = [ standaloneDependency ];
    homeModules = [ ({ ... }: { }) ];
  };

  incompatibleHomeDependency = builtins.tryEval (
    builtins.length (sdk.modulesFor.integratedHome (sdk.composeProfiles [
      (sdk.mkProfile {
        name = "incompatible-home-dependency";
        features = [ integratedDependent ];
      })
    ]))
  );

  dottedPathRejected = builtins.tryEval (
    (sdk.mkRepository {
      features = ./invalid-repository/features;
    }).featureNames
  );

  invalidImportsRejected = builtins.tryEval (
    (sdk.mkRepository {
      features = ./invalid-imports-repository/features;
    }).features.invalid.supportedEnvironments
  );

  invalidProfileFeaturesRejected = builtins.tryEval (
    builtins.length ((sdk.mkRepository {
      features = ./invalid-profile-repository/features;
      profiles = ./invalid-profile-repository/profiles;
    }).modulesFor.nixos [ "invalid" ])
  );

  result = {
    defaultNamespace = defaultSdk.namespace;
    customNamespace = sdk.namespace;
    nixosClosure = builtins.map (feature: feature.name) nixosResolved.features;
    homeClosure = builtins.map (feature: feature.name) homeResolved.features;
    enableDefault = evaluated.config.custom.qnix.desktop.test.enable;
    sdkContext = sdk.context;
    invalidRequiresRejected = !invalidRequires.success;
    incompatibleHomeDependencyRejected = !incompatibleHomeDependency.success;
    dottedPathRejected = !dottedPathRejected.success;
    invalidImportsRejected = !invalidImportsRejected.success;
    invalidProfileFeaturesRejected = !invalidProfileFeaturesRejected.success;
    helperConfig = sdk.mkQnixConfig lib { marker = true; };
    repositoryFeatureNames = repository.featureNames;
    inferredEnvironments = repository.features."system.inferred".supportedEnvironments;
    repositoryNixosVolume = repositoryNixos.config.test.nixosVolume;
    repositoryHomeVolume = repositoryIntegratedHome.config.test.homeVolume;
    repositoryStandaloneVolume = repositoryStandaloneHome.config.test.homeVolume;
    repositoryDirectHomeDefault = repositoryDirectHomeDefault.config.custom.qnix.home.value;
    repositoryDependency = repositoryIntegratedHome.config.test.dependencyLabel;
    repositoryLaptopContext = repositoryNixos.config.test.isLaptop;
    repositoryPersistence = repositoryNixos.config.custom.qnix.persist.root.directories;
    repositoryUserPersistence = repositoryNixos.config.custom.qnix.persist.users."*".directories;
    disabledPersistence = disabledRepositoryNixos.config.custom.qnix.persist.root.directories;
    persistHasEnable = lib.hasAttrByPath [
      "custom"
      "qnix"
      "persist"
      "enable"
    ] repositoryNixos.options;
    integratedPortalLoaded = repositoryIntegratedHome.config.test.portalLoaded;
    statefulHomeLoaded = repositoryStandaloneHome.config.test.statefulHomeLoaded;
    disabledImplementationValue = disabledRepositoryNixos.config.test.nixosVolume;
    unsupportedStandaloneRejected = !unsupportedStandalone.success;
    unsupportedIntegratedRejected = !unsupportedIntegrated.success;
  };
in
assert result.defaultNamespace == [ "qnix" ];
assert
  result.customNamespace == [
    "custom"
    "qnix"
  ];
assert
  result.nixosClosure == [
    "polkit"
    "xdg"
    "desktop"
  ];
assert
  result.homeClosure == [
    "xdg"
    "desktop"
  ];
assert result.enableDefault;
assert result.sdkContext == {
  laptop = true;
  location = "test-lab";
};
assert result.invalidRequiresRejected;
assert result.incompatibleHomeDependencyRejected;
assert result.dottedPathRejected;
assert result.invalidImportsRejected;
assert result.invalidProfileFeaturesRejected;
assert result.helperConfig.custom.qnix.marker;
assert
  result.repositoryFeatureNames == [
    "apps.stateful"
    "base.marker"
    "desktop.portal"
    "desktop.sound"
    "home"
    "persist"
    "system.inferred"
  ];
assert
  result.inferredEnvironments == [
    "nixos"
    "integrated-home"
  ];
assert result.repositoryNixosVolume == 11;
assert result.repositoryHomeVolume == 11;
assert result.repositoryStandaloneVolume == 11;
assert result.repositoryDirectHomeDefault == 42;
assert result.repositoryDependency == "dependency";
assert result.repositoryLaptopContext;
assert result.repositoryPersistence == [ "/var/lib/sound" ];
assert result.repositoryUserPersistence == [ ".local/share/stateful" ];
assert result.disabledPersistence == [ ];
assert !result.persistHasEnable;
assert result.integratedPortalLoaded;
assert result.statefulHomeLoaded;
assert result.disabledImplementationValue == 0;
assert result.unsupportedStandaloneRejected;
assert result.unsupportedIntegratedRejected;
result
