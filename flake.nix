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
              rev = "0f3a862fc89e1f4a56e4380b9f27b7b71f964a34";
              sha256 = "sha256-Cfjk7maDspj8QB4F6gflyvW0AcnReukUlO+oZQs2pZ0=";
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
