{ pkgs, stdenv, vmTools }:
{
  pname,
  version ? "",
  memSize,
  imageSize ? null,
  previousImage ? null,
  script,
  debInputs ? [ ],
  vmSetup ? "",
  logOutput ? false,
  env ? { },
  qemuImg ? pkgs.buildPackages.qemu_kvm,
}:
let
  inherit (pkgs) lib;

  createImage =
    if previousImage == null then
      assert imageSize != null;
      ''
        ${qemuImg}/bin/qemu-img create -f qcow2 "$diskImage" "${toString imageSize}M"
      ''
    else
      ''
        ${qemuImg}/bin/qemu-img create \
          -o backing_file=${previousImage}/OS.img,backing_fmt=qcow2 \
          -f qcow2 "$diskImage"
      '';

  prepareLog = lib.optionalString logOutput ''
    touch xchg/build.log
    exec 3>/proc/self/fd/1
    tail -n +1 -f xchg/build.log >&3 &
    tailPid=$!
    trap 'kill "$tailPid" 2>/dev/null || true' EXIT
  '';

  runScript =
    if logOutput then
      "${script}/build.sh > /tmp/xchg/build.log 2>&1"
    else
      "${script}/build.sh";

  stageDerivation = stdenv.mkDerivation ({
    inherit pname version memSize;

    preVM = ''
      mkdir -p $out
      diskImage=$out/OS.img
      ${createImage}
      ${prepareLog}
    '';

    buildCommand = ''
      ${vmSetup}
      ${runScript}

      mkdir -p $out/nix-support
      ${lib.optionalString (previousImage != null) ''
        echo ${previousImage}/OS.img > $out/nix-support/backing_image
      ''}
      ${lib.optionalString (debInputs != [ ]) ''
        echo ${toString debInputs} > $out/nix-support/deb-inputs
      ''}
    '';
  } // env);
in
vmTools.runInLinuxVM stageDerivation