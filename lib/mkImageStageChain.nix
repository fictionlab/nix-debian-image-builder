{ mkQcow2ImageStage, pkgs }:
{
  name,
  memSize,
  imageSize,
  stages,
  vmSetup ? "",
  logOutput ? true,
  qemuImg ? pkgs.buildPackages.qemu_kvm,
}:
let
  buildStages = previousImage: remainingStages:
    if remainingStages == [ ] then
      [ ]
    else
      let
        stage = builtins.head remainingStages;
        stageImage = mkQcow2ImageStage {
          pname = "${name}-${stage.name}-image";
          version = stage.version or "";
          memSize = stage.memSize or memSize;
          imageSize = if previousImage == null then imageSize else null;
          inherit previousImage;
          script = stage.script;
          debInputs = stage.debInputs or [ ];
          vmSetup = stage.vmSetup or vmSetup;
          logOutput = stage.logOutput or logOutput;
          env = stage.env or { };
          qemuImg = stage.qemuImg or qemuImg;
        };
      in
      [
        {
          name = stage.outputName or stage.name;
          value = stageImage;
        }
      ] ++ buildStages stageImage (builtins.tail remainingStages);
in
builtins.listToAttrs (buildStages null stages)