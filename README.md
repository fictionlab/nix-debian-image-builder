# nix-debian-image-builder

A Nix library for building Debian-based disk images, pinned to nixpkgs revision
`9387b3fcc0c23c86661636da63faabad4235a0a6`. Consumer flakes should follow this
input so the shared builders and image derivations use the same package set.
Consumers still supply image metadata, package snapshots, stage scripts, and
product-specific system files.

The library exports:

- `mkDebClosureGenerator` to resolve Debian package closures from repository
  package indexes.
- `mkScript` to wrap a stage script with its runtime `PATH` and environment.
- `mkQcow2ImageStage` and `mkImageStageChain` to build layered VM image stages.
- `mkRawImage` and `mkCompressedImage` to produce distributable image files.
- `stageScripts.installDebs` and `stageScripts.finalizeImage` for common stage
  operations parameterized by each consumer.

Configure the consumer's nixpkgs input to follow the shared pin:

```nix
inputs = {
  "nix-debian-image-builder".url = "github:fictionlab/nix-debian-image-builder";
  nixpkgs.follows = "nix-debian-image-builder/nixpkgs";
};
```

The image module selects its system-specific builder library:

```nix
let
  imageBuilder = inputs."nix-debian-image-builder".lib system;
  mkDebClosureGenerator = imageBuilder.mkDebClosureGenerator;
in
...
```

The returned library binds `pkgs`, `lib`, `stdenv`, `vmTools`, and
`makeWrapper` from the pinned nixpkgs input for the selected system. Helper
calls therefore take only product-specific settings.

The Debian repositories, architecture-specific package lists, partition
layouts, image payloads, and product configuration remain owned by each OS
project.