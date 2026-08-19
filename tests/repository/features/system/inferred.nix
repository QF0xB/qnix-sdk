{
  nixos = { ... }: {
    test.inferredNixos = true;
  };

  home = { ... }: {
    test.inferredHome = true;
  };
}
