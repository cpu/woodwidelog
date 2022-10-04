{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-parts, }:
    flake-parts.lib.mkFlake { inherit self; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" ];

      perSystem = { pkgs, self', ... }: {
        packages = {
          archie = pkgs.runCommand "archie" {
            src = pkgs.fetchFromGitHub {
              repo = "archie";
              owner = "athul";
              rev = "2f312c3759adf9059791a7cd697788018d09dbe8";
              hash = "sha256-y+XNkLcfXj7php+jYq7kRC9gPkAXtV566Q7KrqzYX6s=";
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
          HUGO_THEMESDIR = self'.packages.themes;
        };
      };
    };
}
