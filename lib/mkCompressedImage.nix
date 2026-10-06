{ pkgs, stdenv }:
{
  image,
  osName,
  osVersion,
  variant,
}:
stdenv.mkDerivation {
  pname = "${osName}-${variant}-compressed-image";
  version = osVersion;

  buildCommand = ''
    mkdir -p $out
    echo "Compressing the image"
    ${pkgs.xz}/bin/xz -T0 --compress --extreme -c \
      ${image}/${osName}-${osVersion}-${variant}.img \
      > $out/${osName}-${osVersion}-${variant}.img.xz
  '';
}