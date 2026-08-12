# QNix SDK

`qnix-sdk` provides the feature, profile, and environment-rendering contracts
used by QNix module repositories. It contains no packages, host definitions,
profiles, identities, or secrets.

## Core model

- `mkFeature` creates a feature descriptor and automatically declares its
  `<namespace>.<optionPath>.enable` option with a default of `true`.
- `requires.nixos` and `requires.home` declare environment-specific feature
  requirements.
- Every feature explicitly lists its supported environments: `nixos`,
  `integrated-home`, and/or `standalone-home`.
- `mkProfile` groups features and other profiles.
- `composeProfiles` creates a lazy selection from requested profiles.
- `modulesFor.nixos` renders canonical options, defaults, and NixOS modules.
- `modulesFor.integratedHome` renders only Home Manager implementations.
- `modulesFor.standaloneHome` renders canonical options, defaults, and Home
  Manager implementations.
- `getQnixConfig` reads the configured namespace from `osConfig` when
  integrated and `config` when standalone.

Only profiles reachable from `composeProfiles` and their feature requirements
are traversed. Features outside the selected closure are not imported.

Only selected features are imported, so every feature enable option defaults to
`true`. Host configuration can override it normally. Context conditions such as
`<namespace>.context.headless` are independent implementation guards and do
not change the meaning of `enable`.

## Requirements

Requirements are feature descriptors, not string names. `requires.nixos` is
followed by the NixOS renderer. `requires.home` is followed by both Home Manager
renderers and by the NixOS owner so the canonical Home options exist for an
integrated configuration. Standalone Home Manager never follows
`requires.nixos`.

## Namespace

The default SDK uses `qnix` as its option namespace:

```nix
sdk = inputs.qnix-sdk.lib;
```

Create an SDK instance to use another top-level or nested namespace:

```nix
sdk = inputs.qnix-sdk.lib.mkSdk {
  namespace = [ "company" "workstation" ];
};
```

Feature `optionPath` values remain relative to that namespace. Feature modules
should use `sdk.getQnixConfig`, profile defaults can use `sdk.mkQnixConfig`, and
individual defaults can use `sdk.setQnixOption` instead of hardcoding `qnix`.

```nix
hyprland = sdk.mkFeature {
  name = "hyprland";
  optionPath = [ "desktop" "hyprland" ];
  supportedEnvironments = [ "nixos" "integrated-home" ];

  requires = {
    nixos = [ polkit ];
    home = [ xdg ];
  };

  nixosModules = [ ./nixos.nix ];
  homeModules = [ ./home.nix ];
};
```
