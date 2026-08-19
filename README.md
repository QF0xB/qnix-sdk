# QNix SDK

`qnix-sdk` provides the feature, profile, and environment-rendering contracts
used by QNix module repositories. It contains no packages, host definitions,
profiles, identities, or secrets.

## Repository API

`mkRepository` is the recommended authoring API. It discovers feature and
profile files, supplies their identity from their path, and hides the
NixOS-versus-Home configuration plumbing from implementations.

```nix
qnix = inputs.qnix-sdk.lib.mkRepository {
  features = ./features;
  profiles = ./profiles;
};
```

A file at `features/desktop/terminal.nix` defines feature
`desktop.terminal` and owns `qnix.desktop.terminal`:

```nix
{
  environments = [
    "integrated-home"
    "standalone-home"
  ];

  options =
    { lib, pkgs, ... }:
    {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.kitty;
      };
    };

  home =
    { cfg, ... }:
    {
      programs.kitty = {
        enable = true;
        package = cfg.package;
      };
    };
}
```

The SDK automatically:

- declares `qnix.desktop.terminal.enable` with a default of `true`;
- places the relative option declarations below `qnix.desktop.terminal`;
- reads the feature configuration from `config` or `osConfig`, as appropriate;
- injects `cfg`, the complete `qnix` configuration, and `context`;
- wraps the returned implementation body in `lib.mkIf cfg.enable`.

Implementations are configuration bodies, not complete modules. Standard
module arguments such as `lib`, `pkgs`, `config`, and `options` remain
available. An implementation can set `autoEnable = false` or provide a custom
`when = args: ...` predicate when the generated enable guard is not suitable.

Use `optionsOnly = true` for a schema feature that has no implementation and
must not have an enable option:

```nix
{
  environments = [ "nixos" ];
  optionsOnly = true;

  options = { lib, ... }: {
    # Relative option declarations
  };
}
```

Option-only features require explicit environments and cannot contain
implementations, persistence contributions, or upstream imports. Regular
features always receive an enable option. `enableOption` can override its
description, default, or other `mkEnableOption` attributes.

### Environment contract

Environment availability can be explicit:

```nix
{
  environments = [
    "nixos"
    "integrated-home"
  ];

  nixos = { ... }: { };
  home = { ... }: { };
}
```

When `environments` is omitted, a `nixos` implementation implies `nixos` and a
`home` implementation implies `integrated-home`. Standalone Home support is
never inferred. Opt into it either with an explicit environment list or with:

```nix
{
  standaloneHome = true;
  home = { ... }: { };
}
```

`environments` and `standaloneHome` cannot be set together. Declaring an
environment without its corresponding implementation is rejected. An
implementation may exist while being intentionally excluded from the explicit
environment list.

### Dependencies

Requirements use discovered feature names:

```nix
{
  requires = {
    nixos = [ "security.polkit" ];
    home = [ "desktop.xdg-folders" ];
  };

  nixos = { ... }: { };
  home = { ... }: { };
}
```

Dependencies are resolved before their dependents and retain cycle, duplicate,
and option-path validation from the descriptor API.

### Integrations and upstream modules

Repositories can provide external modules without coupling the SDK to a
specific flake input:

```nix
qnix = sdk.mkRepository {
  features = ./features;
  profiles = ./profiles;

  integrations.impermanence =
    inputs.impermanence.nixosModules.impermanence;
};
```

Feature and profile definitions may be functions receiving `integrations`:

```nix
{ integrations }:

{
  imports.nixos = [ integrations.impermanence ];
  nixos = { ... }: { };
}
```

Available import groups are `nixos`, `integratedHome`, and `standaloneHome`.
Upstream imports are selected with the feature and remain unconditional when
the generated feature enable option is false. This ensures their option schema
exists before the guarded QNix implementation is evaluated.

### Persistence contributions

A repository may define an option-only feature named `persist` as its
persistence contract. Other features can contribute values to that contract:

```nix
{
  persistence.users."*".directories = [
    ".local/share/example"
  ];

  home = { ... }: {
    # Home implementation
  };
}
```

`persistence` may also be a function receiving the same injected arguments as
an implementation. The SDK adds `persist` to the feature's NixOS requirements,
creates a NixOS-side contribution under `<namespace>.persist`, and guards that
contribution with the feature enable condition. This lets a separate backend
feature, such as Impermanence, consume the complete persistence intent. A
feature with persistence must support `nixos`; this is inferred when no explicit
environment list is provided.

### Profiles and rendering

A profile file contains feature names and optional profile imports and defaults:

```nix
# profiles/desktop.nix
{
  imports = [ "base" ];

  features = [
    "desktop.sound"
    "desktop.terminal"
  ];

  defaults = {
    context.headless = false;
    desktop.sound.volumeStep = 5;
  };
}
```

For exceptional environment-specific membership, `features` may instead be:

```nix
features = {
  shared = [ "desktop.sound" ];
  nixos = [ "security.polkit" ];
  home = [ "desktop.terminal" ];
};
```

Defaults can similarly contain `shared`, `nixos`, and `home` groups. Default
leaf values are automatically wrapped with `lib.mkDefault`.

Render profile names directly:

```nix
qnix.modulesFor.nixos [ "desktop" ]
qnix.modulesFor.integratedHome [ "desktop" ]
qnix.modulesFor.standaloneHome [ "desktop" ]
```

Or reuse a selection:

```nix
selection = qnix.select [ "desktop" ];

selection.nixosModule
selection.integratedHomeModule
selection.standaloneHomeModule
```

Standalone rendering fails when its selected closure contains a feature that
does not declare `standalone-home` support.

Files named `default.nix` and files whose names start with `_` are ignored by
repository discovery and can be used for local helpers.

## Core model

The lower-level descriptor API remains available for repositories that need
fully explicit construction.

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
