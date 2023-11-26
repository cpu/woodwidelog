---
title: "A Beyond-the-basics Rust Flake"
summary: A Nix Flake for a Rust project with non-trivial requirements.
date: 2023-11-26T08:00:00-04:00
type: article
---

# About

There are many resources for writing [Nix flakes] for Rust projects but in my
experience they can often be too simple. They may focus on projects without
complex native code dependencies, or only offer a single development environment
with a fixed Rust toolchain version.

I think Nix thrives at addressing these kinds of complications but it's hard
to find examples in the space between trivial and omg-this-is-too-many-things.
This page is my attempt to rectify that by documenting a Rust project flake that
goes beyond a basic example by showing:

* Support for native code dependencies.
  * In particular, "-sys" crate dependencies that use [cbindgen] for
    generating [FFI] bindings.
* A development environment for three Rust versions:
  * A Minimum Supported Rust Version (MSRV).
  * Latest Stable.
  * A selected Nightly.
* Multiple output packages, with different Cargo features selected.

# The Flake

Without further ado, here's the final flake. It packages a simple Rust command
line program from a Cargo project located in the same directory. The CLI
binary, `example`, demonstrates text-to-speech on Linux as an excuse to use a more
complex dependency. The crate also has an optional `foobar` feature that when
enabled will change the spoken message. You can find the complete example in
[cpu/rust-flake].

The Rust code depends on the [tts-rs] crate for its text-to-speech magic, which
in turn uses the [speech-dispatcher] and [speech-dispatcher-sys] crates. On
Linux, the `-sys` crate uses [pkg-config] and [cbindgen] to generate FFI headers
for the native [speechd] dependency. Getting this working reliably without Nix
would require manually installing extra system packages (using `apt-get`, `yum`,
`brew`, etc) and be difficult to reproduce consistently across systems.


```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      perSystem = { config, self', pkgs, lib, system, ... }:
        let
          runtimeDeps = with pkgs; [ alsa-lib speechd ];
          buildDeps = with pkgs; [ pkg-config rustPlatform.bindgenHook ];
          devDeps = with pkgs; [ gdb ];

          cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
          msrv = cargoToml.package.rust-version;

          rustPackage = features:
            (pkgs.makeRustPlatform {
              cargo = pkgs.rust-bin.stable.latest.minimal;
              rustc = pkgs.rust-bin.stable.latest.minimal;
            }).buildRustPackage {
              inherit (cargoToml.package) name version;
              src = ./.;
              cargoLock.lockFile = ./Cargo.lock;
              buildFeatures = features;
              buildInputs = runtimeDeps;
              nativeBuildInputs = buildDeps;
              # Uncomment if your cargo tests require networking or otherwise
              # don't play nicely with the Nix build sandbox:
              # doCheck = false;
            };

          mkDevShell = rustc:
            pkgs.mkShell {
              shellHook = ''
                export RUST_SRC_PATH=${pkgs.rustPlatform.rustLibSrc}
              '';
              buildInputs = runtimeDeps;
              nativeBuildInputs = buildDeps ++ devDeps ++ [ rustc ];
            };
        in {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [ (import inputs.rust-overlay) ];
          };

          packages.default = self'.packages.example;
          devShells.default = self'.devShells.nightly;

          packages.example = (rustPackage "foobar");
          packages.example-base = (rustPackage "");

          devShells.nightly = (mkDevShell (pkgs.rust-bin.selectLatestNightlyWith
            (toolchain: toolchain.default)));
          devShells.stable = (mkDevShell pkgs.rust-bin.stable.latest.default);
          devShells.msrv = (mkDevShell pkgs.rust-bin.stable.${msrv}.default);
        };
    };
}
```

# Usage

## Default Package

After cloning the repo, you can run the default flake output package directly:

```bash
nix run
```

Or, to run the output package that doesn't enable the "foobar" feature:

```bash
nix run '.#example-base'
```

## Dev. Environments

You can quickly enter a development environment for one of the three Rust
versions:

```bash
# Rust nightly (default):
nix develop
# Rust stable:
nix develop '.#stable'
# MSRV:
nix develop '.#msrv'
```

### Cargo

In each development environment you'll have the usual `cargo` tooling, the
required native dependencies and any extra `devDeps` specified:

```bash
rustc --version && speech-dispatcher --version && gdb --version
cargo fmt && cargo clippy && cargo test
cargo run
cargo run --all-features --release
```

### Quickly running a command

Rather than enter a development shell you can also run a command in the
development environment directly:

```bash
# Nightly:
nix develop '.#nightly' --command cargo test
# Stable:
nix develop '.#stable'  --command cargo test
# MSRV:
nix develop '.#msrv'    --command cargo test
```

## Details

Some points of interest:

1. `cargoToml` - The Cargo metadata is read into a Nix binding, `cargoToml`,
   and used to avoid duplicating the project name, Cargo version, or MSRV in
   both the `Cargo.toml` and the Nix flake.
2. `runtimeDeps`, `buildDeps` and `devDeps` - I often have to remind myself the
   difference between `buildInputs` and `nativeBuildInputs` so I make these
   helpful bindings:
   1. `runtimeDeps` corresponds to `buildInputs` - things needed at runtime.
   2. `buildDeps` corresponds to `nativeBuildInputs` - things needed only when
      building.
   3. `devDeps` is for extra dev. packages - things needed only in `nix develop`
      shells.
3. `cbindgen` - Getting this working requires `cbindgen` be able to find
   `libclang`, and `libclang` being able to find your native dependencies.
   There's a handy `bindgenHook` that we use for this purpose, letting it do all
   the heavy lifting. No need to muck with `LIBCLANG_PATH`.
4. `withFeatures` - this is a small helper function that reduces duplication
   building a Nix flake output from a Rust project. It makes it easy to define
   multiple flake package outputs that differ only in Cargo feature selections.
5. `mkDevShell` - this is a small helper function that reduces duplication
   creating a development shell with a specific Rust version. It also sets the
   `RUST_SRC_PATH` that many IDEs will use to find the Rust stdlib.
6. `inputs` - there are lots of ways to build Rust packages in Nix. Oxalica's
   [rust-overlay] has given me minimal grief, and I think [flake parts] add
   a lot of value as flake complexity scales up. YMMV.

## Why bother?

This might seem like a lot of work. Why not just use `rustup` to manage three
Rust versions and call it a day? For me there are a few primary advantages (_and
lots of smaller ones!_):

* Rustup can't manage system level dependencies. Typically you'll have to
  describe which packages a user needs to install before building, or write
  adhoc scripts to install the required dependencies. Keeping the versions used
  by different developers in-sync with one another across different OSes is
  a nightmare. Using a Nix flake makes this trivially reproducible. 
* Users of `nix` or `NixOS` can consume your project through the flake,
  effortlessly adding the flake as an input to their own Nix flakes, or running
  the project in an ephemeral shell:
```bash
nix run github:cpu/rust-flake
```
* It works for more than just Rust. As one example, if your project needs Python
  to generate test data you can easily extend the flake to manage Python runtime
  versions and `pip` dependencies.
* You can reuse the same reproducible dev. environments for your CI. This
  eliminates the classic blunders that ensue when the native dependency versions
  or toolchain versions installed in CI drift from what you use locally.

Other tools like Docker aim to solve some of the same problems but do it in ways
I've often found clumsy to use or that fell short in different areas. Nix isn't
without its own downsides but for me the time invested in learning it continues
to pay off.

## Conclusion

This flake isn't too complicated, but it can take some time to combine the
bits and pieces from different documentation sources to make a unified whole.
Hopefully this example helps demystify the complete picture.

You can find the complete example with the accompanying Rust crate in
[cpu/rust-flake]. That repo also shows how to set up GitHub actions CI to use
the `nix` environment. No more mismatched dependency and tooling versions
between dev. and CI!

[Nix flakes]: https://zero-to-nix.com/concepts/flakes
[cbindgen]: https://github.com/mozilla/cbindgen
[FFI]: https://doc.rust-lang.org/nomicon/ffi.html
[Nixpkgs]: https://github.com/NixOS/nixpkgs
[flake parts]: https://flake.parts/
[rust-overlay]: https://github.com/oxalica/rust-overlay
[cpu/rust-flake]: https://github.com/cpu/rust-flake
[tts-rs]: https://crates.io/crates/tts
[speech-dispatcher]: https://crates.io/crates/speech-dispatcher
[speech-dispatcher-sys]: https://crates.io/crates/speech-dispatcher-sys
[speechd]: https://wiki.archlinux.org/title/Speech_dispatcher
[pkg-config]: https://www.freedesktop.org/wiki/Software/pkg-config/
