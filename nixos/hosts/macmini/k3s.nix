{ pkgs, ... }:
{
  services.k3s = {
    enable = true;
    package = pkgs.k3s_1_36;
    role = "server";
    extraFlags = [ "--default-local-storage-path=/mnt/data" ];
  };

  systemd.services.k3s.unitConfig.RequiresMountsFor = [ "/mnt/data" ];

  boot.kernel.sysctl = {
    "fs.inotify.max_user_instances" = 8192;
    "fs.inotify.max_user_watches" = 1048576;
  };

  networking.firewall.trustedInterfaces = [
    "end0"
    "cni0"
    "flannel.1"
  ];
}
