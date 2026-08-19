{
  standaloneHome = true;

  persistence.users."*".directories = [ ".local/share/stateful" ];

  home = { ... }: {
    test.statefulHomeLoaded = true;
  };
}
