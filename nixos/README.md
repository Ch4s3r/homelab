# NixOS: Mac Mini M2

NixOS configuration for the homelab node, based on [nixos-apple-silicon](https://github.com/nix-community/nixos-apple-silicon).

`hosts/macmini/hardware-configuration.nix` is generated on the machine during installation and committed afterwards.

## Install

Follow the nixos-apple-silicon [UEFI standalone guide](https://github.com/nix-community/nixos-apple-silicon/blob/main/docs/uefi-standalone.md) up to "Partitioning and Formatting", then:

```bash
sgdisk /dev/nvme0n1 -n 0:0 -s
mkfs.btrfs -L nixos /dev/nvme0n1p<root>
mount /dev/disk/by-label/nixos /mnt
for subvolume in root home nix var; do btrfs subvolume create /mnt/$subvolume; done
umount /mnt
mount -o subvol=root,compress=zstd,noatime /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/{home,nix,var,boot}
for subvolume in home nix var; do mount -o subvol=$subvolume,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/$subvolume; done
mount /dev/disk/by-partuuid/$(cat /proc/device-tree/chosen/asahi,efi-system-partition) /mnt/boot

git clone https://github.com/Ch4s3r/homelab /mnt/etc/homelab
nixos-generate-config --root /mnt --show-hardware-config > /mnt/etc/homelab/nixos/hosts/macmini/hardware-configuration.nix
git -C /mnt/etc/homelab add nixos/hosts/macmini/hardware-configuration.nix
nixos-install --flake /mnt/etc/homelab/nixos#macmini --no-root-password
nixos-enter --root /mnt -c 'passwd lampe'
```

The Asahi kernel has no binary cache and is compiled during install (roughly 30–60 minutes).

## Deploy

From a machine with Nix, building on the Mac Mini itself:

```bash
nixos-rebuild switch --flake ./nixos#macmini --target-host lampe@macmini --build-host lampe@macmini --sudo
```

## Notes

- Peripheral firmware (Wi-Fi, Bluetooth) is not extracted: the node uses Ethernet, and extracting it would need `--impure` evaluation.
