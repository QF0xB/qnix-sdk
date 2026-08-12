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
result
