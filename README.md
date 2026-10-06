# nix-debian-image-builder

A Nix library for building Debian-based disk images. It provides common package
closure, script, VM-stage, and image-finalization builders. Each OS project
continues to own its package snapshots, image metadata, board-specific
configuration, and system files.

## Add the Input

Declare the builder as a flake input. Following its nixpkgs input keeps the
builder helpers and the consumer's package set aligned:

```nix
inputs = {
  "nix-debian-image-builder".url = "github:fictionlab/nix-debian-image-builder";
  nixpkgs.follows = "nix-debian-image-builder/nixpkgs";
};
```

The `lib` output is a function of the target system. Select it once inside the
consumer's flake outputs, then pass it to the image module:

```nix
outputs = { nix-debian-image-builder, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    imageBuilder = nix-debian-image-builder.lib system;
    pkgs = import nixpkgs { inherit system; };
  in
  {
    packages.${system}.os-image = pkgs.callPackage ./OS-image {
      OSName = "MyOS";
      OSVersion = "1.0.0";
      inherit imageBuilder;
      buildSystem = system;
    };
  };
```

The selected library binds `pkgs`, `lib`, `stdenv`, `vmTools`, and
`makeWrapper` for that system. Most helper calls therefore need only the
consumer's image-specific arguments.

## Debian Package Closures

`mkDebClosureGenerator` downloads and parses repository `Packages` indexes,
then resolves the requested packages and their dependencies. Import the
resulting derivation with the same `fetchurl` used for the package indexes:

```nix
let
  packageLists = [
    {
      name = "ubuntu-main";
      packagesFile = fetchurl {
        url = "https://mirror.example/ubuntu/dists/noble/main/binary-amd64/Packages.xz";
        sha256 = "sha256-REPLACE_WITH_THE_INDEX_HASH";
      };
      urlPrefix = "https://mirror.example/ubuntu";
    }
  ];

  debsClosure = import (imageBuilder.mkDebClosureGenerator {
    name = "myos-debs-closure";
    inherit packageLists;
    packages = [
      "base-passwd"
      "base-files"
      "---"
      "bash"
      "coreutils"
    ];
  }) { inherit fetchurl; };
in
...
```

Arguments:

| Argument | Required | Description |
| --- | --- | --- |
| `name` | Yes | Name of the generated closure derivation. |
| `packageLists` | Yes | Repository index descriptions. Each entry has `name`, `packagesFile`, and `urlPrefix`. |
| `packages` | Yes | Top-level Debian package names. Use `"---"` to separate installation stages. |

`packagesFile` can be an `.xz`, `.lzma`, `.bz2`, or `.gz` index. `urlPrefix` is
prepended to each package's repository-relative `Filename` when the closure is
generated. The imported result is a list of stages; each stage is a list of
strings, with one string per dependency component. Each string contains the
space-separated store paths for the component's `.deb` files. For example:

```nix
[
  [ "/nix/store/a.deb /nix/store/b.deb" "/nix/store/c.deb" ]
  [ "/nix/store/d.deb" ]
]
```

Select one stage with `builtins.elemAt debsClosure 1` and pass it to a VM stage
as the `debsStage` environment attribute expected by the install script.

## Stage Scripts

`mkScript` wraps a supplied script as `$out/build.sh`, patches its shebang, and
sets its runtime `PATH`. It always provides `NIX_STORE_DIR`; additional
environment attributes are set on the wrapper.

```nix
customScript = imageBuilder.mkScript {
  name = "myos-custom-stage-script";
  src = ./buildCustomStage.sh;
  packages = with pkgs; [ coreutils gnused ];
  environment = {
    CONFIG_DIR = configFiles;
  };
};
```

Arguments:

| Argument | Required | Description |
| --- | --- | --- |
| `name` | Yes | Name of the script derivation. |
| `src` | Yes | Source shell script. |
| `packages` | Yes | Packages added to the script's `PATH`. |
| `environment` | No | Attribute set of extra wrapper environment variables; defaults to `{ }`. |

For common image stages, use the dedicated factories. Their runtime package
lists are maintained by this repository; `environment` supplies
product-specific values such as the boot mount point.

```nix
installDebs = imageBuilder.mkInstallDebsScript {
  name = "myos-stage2-script";
  environment.BOOT_MOUNT = "/boot/firmware";
};

finalizeImage = imageBuilder.mkFinalizeImageScript {
  name = "myos-finalize-script";
  environment.BOOT_MOUNT = "/boot/firmware";
};
```

Both factories take `name` (required) and `environment` (optional, defaults
to `{ }`). The install script also reads `debsStage` from the VM stage's
environment. The finalizer reads `OSName`, `OSVersion`, and `OSVariant` from
that environment. `BOOT_MOUNT` is required by both scripts at runtime.

## QCOW2 Stages

`mkQcow2ImageStage` runs one wrapped script in a Linux VM and produces
`$out/OS.img`. For the first stage, set `imageSize`. For a later stage, set
`previousImage`; the new image uses that image as its QCOW2 backing file.

```nix
finalImage = imageBuilder.mkQcow2ImageStage {
  pname = "myos-lite-image";
  version = "1.0.0";
  memSize = 4096;
  previousImage = stageImages.OSStage4Image;
  script = finalizeImage;
  env = {
    OSName = "MyOS";
    OSVersion = "1.0.0";
    OSVariant = "lite";
  };
};
```

Arguments:

| Argument | Required | Default | Description |
| --- | --- | --- | --- |
| `pname` | Yes | | Derivation name. |
| `version` | No | `""` | Derivation version. |
| `memSize` | Yes | | VM memory size in MiB. |
| `imageSize` | First stage | `null` | Initial disk size in MiB. Required when `previousImage` is absent. |
| `previousImage` | No | `null` | Previous stage derivation, used as the QCOW2 backing image. |
| `script` | Yes | | Wrapped script derivation containing `build.sh`. |
| `debInputs` | No | `[ ]` | Package paths recorded in `nix-support/deb-inputs`. |
| `vmSetup` | No | `""` | Shell setup run inside the VM before the script. |
| `logOutput` | No | `false` | Capture and forward script output through the VM log. |
| `env` | No | `{ }` | Additional derivation environment attributes available to the script. |
| `qemuImg` | No | `pkgs.buildPackages.qemu_kvm` | Package providing `qemu-img`. |

`mkImageStageChain` creates a sequence of these derivations and returns an
attribute set containing each stage image:

```nix
stageImages = imageBuilder.mkImageStageChain {
  name = "MyOS";
  imageSize = 8192;
  memSize = 4096;
  stages = [
    {
      name = "stage1";
      outputName = "OSStage1Image";
      script = installBase;
      env = { debsStage = debsStage1; };
      debInputs = [ debsStage1 ];
    }
    {
      name = "stage2";
      script = installRos;
      env = { debsStage = debsStage2; };
      debInputs = [ debsStage2 ];
    }
  ];
};
```

Chain arguments are `name`, `imageSize`, `memSize`, and `stages` (all
required). Optional chain arguments `vmSetup`, `logOutput`, and `qemuImg`
provide defaults for the stages. Every stage requires `name` and `script`.
Optional stage arguments are:

| Argument | Default | Description |
| --- | --- | --- |
| `outputName` | Stage `name` | Attribute name used for this image in the returned set. |
| `version` | `""` | Derivation version. |
| `memSize` | Chain `memSize` | VM memory size in MiB. |
| `debInputs` | `[ ]` | Package paths recorded in `nix-support/deb-inputs`. |
| `vmSetup` | Chain `vmSetup` or `""` | Shell setup run before the stage script. |
| `logOutput` | Chain `logOutput` or `false` | Whether to capture and forward script output. |
| `env` | `{ }` | Extra derivation environment attributes for the stage. |
| `qemuImg` | Chain `qemuImg` or `pkgs.buildPackages.qemu_kvm` | Package providing `qemu-img`. |

The first stage creates the disk; each following stage is layered on its
predecessor.

## Raw and Compressed Images

`mkRawImage` converts a QCOW2 image to raw, shrinks it to the final partition,
and optionally repairs the GPT backup table:

```nix
rawImage = imageBuilder.mkRawImage {
  image = finalImage;
  osName = "MyOS";
  osVersion = "1.0.0";
  variant = "lite";
};
```

Required arguments are `image`, `osName`, `osVersion`, and `variant`.
Optional arguments are `filename` (defaults to
`"${osName}-${osVersion}-${variant}.img"`), `additionalSectors` (defaults to
`34`), and `repairGpt` (defaults to `true`).

`mkCompressedImage` compresses a raw image using xz:

```nix
compressedImage = imageBuilder.mkCompressedImage {
  image = rawImage;
  osName = "MyOS";
  osVersion = "1.0.0";
  variant = "lite";
};
```

It requires `image`, `osName`, `osVersion`, and `variant`. The input image must
contain the default raw filename `${osName}-${osVersion}-${variant}.img`.