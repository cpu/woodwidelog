{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = { url = "github:hercules-ci/flake-parts"; };
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" ];

      perSystem = { pkgs, self', ... }: {
        packages = {
          archie = pkgs.runCommand "archie" {
            src = pkgs.fetchFromGitHub {
              repo = "archie";
              owner = "athul";
              rev = "d8819d5eee8b0817f41bda3a9dc2100cd6b2b0bd";
              sha256 = "sha256-VFXk21T1UofZUj5xVethaZG+u6pwMJKw+fmk+Vep9uc=";
            };
          } ''
            cp -ra $src $out
          '';

          themes = pkgs.linkFarmFromDrvs "themes" [ self'.packages.archie ];

          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "woodwidelog";
            version = builtins.substring 0 8 self.lastModifiedDate;
            src = self;
            nativeBuildInputs = [ pkgs.hugo ];
            HUGO_THEMESDIR = self'.packages.themes;
            buildPhase = ''
              runHook preBuild
              mkdir -p $out
              hugo --minify --destination $out
              runHook postBuild
            '';
            dontInstall = true;
          };

          serve = pkgs.writeShellScriptBin "serve" ''
            ${pkgs.ran}/bin/ran -r ${self'.packages.default}
          '';
        };

        devShells.default = pkgs.mkShellNoCC {
          name = "woodwidelog";
          inputsFrom = [ self'.packages.default ];
          buildInputs = [ pkgs.exiftool pkgs.lychee ];
          HUGO_THEMESDIR = self'.packages.themes;
        };
      };
    };
}
