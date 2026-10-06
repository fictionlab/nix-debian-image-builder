{
  pkgs,
  lib,
  stdenv,
  vmTools,
  makeWrapper,
}:
rec {
  mkQcow2ImageStage = import ./mkQcow2ImageStage.nix {
    inherit pkgs stdenv vmTools;
  };
  mkImageStageChain = import ./mkImageStageChain.nix {
    inherit mkQcow2ImageStage pkgs;
  };
  mkDebClosureGenerator = import ./mkDebClosureGenerator.nix { inherit lib pkgs; };
  mkScript = import ./mkScript.nix { inherit pkgs stdenv makeWrapper; };
  mkInstallDebsScript =
    {
      name,
      environment ? { },
    }:
    mkScript {
      inherit name environment;
      src = ./scripts/buildStageDebs.sh;
      packages = with pkgs; [
        coreutils
        util-linux
      ];
    };
  mkFinalizeImageScript =
    {
      name,
      environment ? { },
    }:
    mkScript {
      inherit name environment;
      src = ./scripts/buildStageFinal.sh;
      packages = with pkgs; [
        coreutils
        e2fsprogs
        findutils
        gawk
        gnugrep
        gnused
        parted
        util-linux
        zerofree
      ];
    };
  mkRawImage = import ./mkRawImage.nix { inherit pkgs stdenv; };
  mkCompressedImage = import ./mkCompressedImage.nix { inherit pkgs stdenv; };
}
