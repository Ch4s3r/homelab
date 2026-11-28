{
  disko.devices.disk = {
    data-a = {
      type = "disk";
      device = "/dev/disk/by-id/ata-Samsung_SSD_870_EVO_4TB_S758NX0W506454H";
      content = {
        type = "gpt";
        partitions.data.size = "100%";
      };
    };
    data-b = {
      type = "disk";
      device = "/dev/disk/by-id/ata-Samsung_SSD_870_EVO_4TB_S758NX0W506456A";
      content = {
        type = "gpt";
        partitions.data = {
          size = "100%";
          content = {
            type = "btrfs";
            extraArgs = [
              "-f"
              "-L"
              "data"
              "-d"
              "raid1"
              "-m"
              "raid1"
              "/dev/disk/by-partlabel/disk-data-a-data"
            ];
            mountpoint = "/mnt/data";
            mountOptions = [
              "compress=zstd"
              "noatime"
              "nofail"
            ];
          };
        };
      };
    };
  };

  services.btrfs.autoScrub.fileSystems = [ "/mnt/data" ];
}
