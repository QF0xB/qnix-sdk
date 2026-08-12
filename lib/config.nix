{ namespace }:
let
  getByPath =
    path: value:
    builtins.foldl' (
      current: name:
      if builtins.hasAttr name current then
        builtins.getAttr name current
      else
        throw "qnix-sdk: missing option path '${builtins.concatStringsSep "." path}'"
    ) value path;
in
{
  getQnixConfig =
    {
      config,
      osConfig ? null,
    }:
    getByPath namespace (if osConfig != null then osConfig else config);

  getFeatureConfig =
    {
      qcfg,
      optionPath,
    }:
    getByPath optionPath qcfg;

  mkQnixConfig = lib: value: lib.setAttrByPath namespace value;

  setQnixOption =
    lib: optionPath: value:
    lib.setAttrByPath (namespace ++ optionPath) value;

  isGraphical = qcfg: !qcfg.context.headless;
}
