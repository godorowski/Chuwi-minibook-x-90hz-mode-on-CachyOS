# 90hz fix for chuwi minibook x (n100/n150)

patched VBT firmware to force 90hz on the internal panel via i915.

## files

- `vbt_patched.bin` - patched VBT
- `install_90hz.sh` - install script

## install

```
sudo ./install_90hz.sh
```

reboot after.

## what it does

- backs up original VBT to `/lib/firmware/vbt_original_backup.bin`
- copies patched VBT to `/lib/firmware/vbt`
- adds it to FILES in `/etc/mkinitcpio.conf`
- adds `i915.vbt_firmware=vbt` to kernel cmdline in `/etc/default/limine`
- rebuilds initramfs

## requirements

- arch (or derivative) with mkinitcpio
- limine bootloader
- i915

## revert

```
sudo cp /lib/firmware/vbt_original_backup.bin /lib/firmware/vbt
sudo limine-mkinitcpio
```

reboot. optionally remove `i915.vbt_firmware=vbt` from cmdline too.
