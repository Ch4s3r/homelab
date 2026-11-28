{ lib, ... }:
{
  hardware.asahi = {
    enable = true;
    extractPeripheralFirmware = false;
  };

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };
  boot.loader.efi.canTouchEfiVariables = false;

  fileSystems =
    let
      btrfsOptions = [
        "compress=zstd"
        "noatime"
      ];
    in
    {
      "/".options = btrfsOptions;
      "/home".options = btrfsOptions;
      "/nix".options = btrfsOptions;
      "/var".options = btrfsOptions;
      "/boot".options = lib.mkForce [
        "fmask=0077"
        "dmask=0077"
      ];
    };

  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
  };
  services.fstrim.enable = true;
}
