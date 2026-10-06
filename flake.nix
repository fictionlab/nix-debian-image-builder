{
  description = "Reusable Nix builders for Debian-based disk images";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/9387b3fcc0c23c86661636da63faabad4235a0a6";

  outputs = { nixpkgs, ... }: {
    lib =
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      pkgs.callPackage ./lib { };
  };
}
