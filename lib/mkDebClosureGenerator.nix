{ lib, pkgs }:
{
  name,
  packageLists,
  packages,
}:
let
  inherit (pkgs) buildPackages runCommand;
in
runCommand "${name}.nix"
  {
    nativeBuildInputs = [
      buildPackages.perl
      buildPackages.dpkg
    ];
  }
  ''
    ${toString (
      lib.lists.forEach packageLists (list: ''
        echo "adding ${list.name}"
        packagesFile=${toString list.packagesFile}
        case $packagesFile in
          *.xz | *.lzma)
            xz -d < $packagesFile > ./Packages-${list.name}
            ;;
          *.bz2)
            bunzip2 < $packagesFile >> ./Packages-${list.name}
            ;;
          *.gz)
            gzip -dc < $packagesFile >> ./Packages-${list.name}
            ;;
        esac
      '')
    )}

    perl -w ${./deb-closure.pl} \
      ${
        toString (
          lib.lists.forEach packageLists (list: "--package-list ./Packages-${list.name},${list.urlPrefix}")
        )
      } \
      -- ${toString packages} > $out
  ''
