{
  users.users.lampe = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOtWq3QnYEHRMdbp2f9/sMSAJ4Lncw2RrnglTAeOrCvm"
    ];
  };
}
