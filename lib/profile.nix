let
  validateProfile =
    profile:
    if !builtins.isString profile.name || profile.name == "" then
      throw "qnix-sdk: a profile requires a non-empty name"
    else if !builtins.isList profile.imports then
      throw "qnix-sdk: profile '${profile.name}' imports must be a list"
    else if !builtins.all builtins.isString profile.imports then
      throw "qnix-sdk: profile '${profile.name}' imports must contain profile-name strings"
    else if !builtins.isList profile.features then
      throw "qnix-sdk: profile '${profile.name}' features must be a list"
    else if !builtins.isList profile.defaultModules then
      throw "qnix-sdk: profile '${profile.name}' defaultModules must be a list"
    else
      profile;
in
{
  mkProfile =
    {
      name,
      source ? null,
      imports ? [ ],
      features ? [ ],
      defaultModules ? [ ],
    }:
    validateProfile {
      __qnixType = "profile";
      inherit
        name
        source
        imports
        features
        defaultModules
        ;
    };

  composeProfiles = profiles:
    if !builtins.isList profiles then
      throw "qnix-sdk: profile selection must be a list"
    else {
      __qnixType = "selection";
      inherit profiles;
    };
}
