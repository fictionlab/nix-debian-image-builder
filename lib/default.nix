{
  pkgs,
  lib,
  stdenv,
  vmTools,
  makeWrapper,
}:
(finalAttrs: {
  mkQcow2ImageStage = import ./mkQcow2ImageStage.nix { inherit pkgs stdenv vmTools; };
  mkImageStageChain = import ./mkImageStageChain.nix {
    inherit pkgs;
    mkQcow2ImageStage = finalAttrs.mkQcow2ImageStage;
  };
  mkDebClosureGenerator = import ./mkDebClosureGenerator.nix { inherit lib pkgs; };
  mkScript = import ./mkScript.nix { inherit pkgs stdenv makeWrapper; };
  mkRawImage = import ./mkRawImage.nix { inherit pkgs stdenv; };
  mkCompressedImage = import ./mkCompressedImage.nix { inherit pkgs stdenv; };
  stageScripts = {
    installDebs = ./scripts/buildStageDebs.sh;
    finalizeImage = ./scripts/buildStageFinal.sh;
  };
})
