{ ... }:
{
  programs.git = {
    enable   = true;
    settings = {
      user.name  = "Abhishek Kaith";
      user.email = "abhishekkaith76@gmail.com";
      init.defaultBranch   = "main";
      push.autoSetupRemote = true;
      pull.rebase          = false;
    };
  };
}
