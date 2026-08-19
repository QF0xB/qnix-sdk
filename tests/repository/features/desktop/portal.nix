{
  environments = [ "integrated-home" ];

  home = { ... }: {
    test.portalLoaded = true;
  };
}
