{
  description = "Avogadr.io is a molecule wallpaper rendering website";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      perSystem =
        {
          lib,
          pkgs,
          self',
          ...
        }:
        {
          packages = {
            default = self'.packages.avogadrio;

            avogadrio = pkgs.buildNpmPackage {
              pname = "avogadrio";
              version = "1.0.0";

              src = lib.fileset.toSource {
                root = ./.;
                fileset = lib.fileset.unions [
                  ./gulpfile.js
                  ./package.json
                  ./package-lock.json
                  ./src/less
                  ./src/coffee
                  ./web
                ];
              };

              npmDepsHash = "sha256-eqy6Sgjs9w46UFEaz5eA4Muw1DtCpHCxZCgfR15icfg=";

              buildPhase = ''
                runHook preBuild
                ./node_modules/.bin/gulp
                runHook postBuild
              '';

              nativeBuildInputs = [ pkgs.makeWrapper ];

              installPhase = ''
                cp -r web $out
                cp -r node_modules/bootstrap/dist/css/bootstrap.min.css \
                  node_modules/bootstrap/dist/css/bootstrap.min.css.map \
                  node_modules/flat-ui/css/flat-ui.css \
                  node_modules/font-awesome/css/font-awesome.min.css \
                  node_modules/animate.css/animate.min.css \
                  node_modules/@melloware/coloris/dist/coloris.min.css \
                  $out/css/
                cp -r node_modules/bootstrap/dist/js/bootstrap.min.js \
                  node_modules/@melloware/coloris/dist/umd/coloris.min.js \
                  node_modules/smiles-drawer/dist/smiles-drawer.min.js \
                  $out/js/
                cp -r node_modules/flat-ui/fonts $out/

                makeWrapper ${lib.getExe pkgs.python3} $out/bin/avogadrio \
                  --add-flags "-m http.server --directory $out \"''${AVOGADRIO_PORT:-8080}\" --bind \"''${AVOGADRIO_INTERFACE:-localhost}\""
              '';
            };
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [ self'.packages.avogadrio ];
          };

          formatter = pkgs.nixfmt-tree;
        };
    };
}
