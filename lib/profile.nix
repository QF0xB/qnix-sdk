let
  validateProfile =
    profile:
    if !builtins.isString profile.name || profile.name == "" then
      throw "qnix-sdk: a profile requires a non-empty name"
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

  composeProfiles = profiles: {
    __qnixType = "selection";
    inherit profiles;
  };
}
