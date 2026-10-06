{ pkgs, stdenv }:
{
  image,
  osName,
  osVersion,
  variant,
  filename ? "${osName}-${osVersion}-${variant}.img",
  additionalSectors ? 1,
  repairGpt ? false,
}:
stdenv.mkDerivation {
  pname = "${osName}-${variant}-raw-image";
  version = osVersion;

  buildCommand = ''
    mkdir -p $out
    diskImage=$out/${filename}
    ${pkgs.buildPackages.qemu_kvm}/bin/qemu-img convert -f qcow2 -O raw \
      ${image}/OS.img "$diskImage"

    LAST_SECTOR=$(${pkgs.parted}/bin/parted "$diskImage" -ms unit s print | tail -n +3 | cut -d: -f3 | sed 's/s//' | sort -n | tail -1)
    SECTOR_SIZE=512
    DISK_SIZE=$(( (LAST_SECTOR + ${toString additionalSectors}) * SECTOR_SIZE ))

    ${pkgs.buildPackages.qemu_kvm}/bin/qemu-img resize --shrink -f raw "$diskImage" "$DISK_SIZE"
    ${pkgs.lib.optionalString repairGpt ''
      ${pkgs.gptfdisk}/bin/sgdisk -e "$diskImage"
    ''}
  '';
}