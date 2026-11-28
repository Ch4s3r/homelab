{
  users.users.lampe = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPV9NusNe1LoMlA2y/yWlgpSrJvgL5Pl3j+YQ2ZrnyIi"
    ];
  };
}
