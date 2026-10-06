{ pkgs, stdenv, makeWrapper }:
{ name, src, packages, environment ? { } }:
let
  inherit (pkgs) lib;
  wrapperArgs = [
    "--set PATH ${lib.escapeShellArg (lib.makeBinPath packages)}"
  ] ++ lib.mapAttrsToList
    (key: value: "--set ${key} ${lib.escapeShellArg (toString value)}")
    environment;
in
stdenv.mkDerivation {
  inherit name;
  inherit src;
  nativeBuildInputs = [ makeWrapper ];
  phases = [ "installPhase" "postFixup" ];

  installPhase = ''
    mkdir -p $out
    cp -v $src $out/build.sh
    patchShebangs $out/build.sh
  '';

  postFixup = ''
    wrapProgram $out/build.sh \
      ${lib.concatStringsSep " " wrapperArgs}
  '';
}