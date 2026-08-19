{ lib }:
let
  defaultSdk = import ../lib;
  sdk = defaultSdk.mkSdk {
    namespace = [
      "custom"
      "qnix"
    ];
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
    defaultModules = [
      ({ lib, ... }: sdk.setQnixOption lib [ "context" "laptop" ] true)
    ];
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
      integrationLoaded = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      statefulHomeLoaded = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };
  };

  testIntegrationModule = {
    config.test.integrationLoaded = true;
  };

  repository = sdk.mkRepository {
    features = ./repository/features;
    profiles = ./repository/profiles;
    integrations.testModule = testIntegrationModule;
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

  invalidRequires = builtins.tryEval (
    (sdk.mkFeature {
      name = "invalid";
      optionPath = [ "invalid" ];
      supportedEnvironments = [ "nixos" ];
      requires.hmoe = [ ];
    }).requires
  );

  result = {
    defaultNamespace = defaultSdk.namespace;
    customNamespace = sdk.namespace;
    nixosClosure = builtins.map (feature: feature.name) nixosResolved.features;
    homeClosure = builtins.map (feature: feature.name) homeResolved.features;
    enableDefault = evaluated.config.custom.qnix.desktop.test.enable;
    laptopDefault = evaluated.config.custom.qnix.context.laptop;
    invalidRequiresRejected = !invalidRequires.success;
    helperConfig = sdk.mkQnixConfig lib { marker = true; };
    repositoryFeatureNames = repository.featureNames;
    inferredEnvironments = repository.features."system.inferred".supportedEnvironments;
    repositoryNixosVolume = repositoryNixos.config.test.nixosVolume;
    repositoryHomeVolume = repositoryIntegratedHome.config.test.homeVolume;
    repositoryStandaloneVolume = repositoryStandaloneHome.config.test.homeVolume;
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
    repositoryIntegrationLoaded = repositoryNixos.config.test.integrationLoaded;
    disabledIntegrationLoaded = disabledRepositoryNixos.config.test.integrationLoaded;
    integratedPortalLoaded = repositoryIntegratedHome.config.test.portalLoaded;
    statefulHomeLoaded = repositoryStandaloneHome.config.test.statefulHomeLoaded;
    disabledImplementationValue = disabledRepositoryNixos.config.test.nixosVolume;
    unsupportedStandaloneRejected = !unsupportedStandalone.success;
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
assert result.laptopDefault;
assert result.invalidRequiresRejected;
assert result.helperConfig.custom.qnix.marker;
assert
  result.repositoryFeatureNames == [
    "apps.stateful"
    "base.marker"
    "desktop.portal"
    "desktop.sound"
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
assert result.repositoryDependency == "dependency";
assert result.repositoryLaptopContext;
assert result.repositoryPersistence == [ "/var/lib/sound" ];
assert result.repositoryUserPersistence == [ ".local/share/stateful" ];
assert result.disabledPersistence == [ ];
assert !result.persistHasEnable;
assert result.repositoryIntegrationLoaded;
assert result.disabledIntegrationLoaded;
assert result.integratedPortalLoaded;
assert result.statefulHomeLoaded;
assert result.disabledImplementationValue == 0;
assert result.unsupportedStandaloneRejected;
result
