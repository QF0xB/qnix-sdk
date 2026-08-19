{
  features = [ "home" ];

  defaults = {
    home.value = 7;

    __qnixEnvironment.nixos.home.value = 9;
  };
}
