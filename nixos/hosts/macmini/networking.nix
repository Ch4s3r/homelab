{ config, ... }:
{
  networking = {
    hostName = "macmini";
    useNetworkd = true;
    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
    };
  };

  systemd.network.networks."10-ethernet" = {
    matchConfig.Name = "end0";
    networkConfig.DHCP = "yes";
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.sops.secrets.tailscale-auth-key.path;
    extraUpFlags = [ "--ssh" ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };
}
