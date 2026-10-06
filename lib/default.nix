{
  pkgs,
  lib,
  stdenv,
  vmTools,
  makeWrapper,
}:
let
  mkQcow2ImageStage = import ./mkQcow2ImageStage.nix {
    inherit pkgs stdenv vmTools;
  };

  mkImageStageChain = import ./mkImageStageChain.nix {
    inherit mkQcow2ImageStage pkgs;
  };
in
{
  mkDebClosureGenerator = import ./mkDebClosureGenerator.nix { inherit lib pkgs; };
  mkScript = import ./mkScript.nix { inherit pkgs stdenv makeWrapper; };
  inherit mkQcow2ImageStage mkImageStageChain;
  mkRawImage = import ./mkRawImage.nix { inherit pkgs stdenv; };
  mkCompressedImage = import ./mkCompressedImage.nix { inherit pkgs stdenv; };
  stageScripts = {
    installDebs = ./scripts/buildStageDebs.sh;
    finalizeImage = ./scripts/buildStageFinal.sh;
  };
}
