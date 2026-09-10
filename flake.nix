{
  description = "Avogadr.io is a molecule wallpaper rendering website";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    clojure-nix-locker.url = "github:bevuta/clojure-nix-locker";
    clojure-nix-locker.inputs.nixpkgs.follows = "nixpkgs";
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

            avogadrio =
              let
                frontend = pkgs.buildNpmPackage {
                  pname = "avogadrio-frontend";
                  version = "1.0.0";
                  src = lib.sources.cleanSource ./.;

                  npmDepsHash = "sha256-Vsd0VCB2h5g6Dhi1rXyTdRLDDQfTdEm7i3DHPjkVGI0=";

                  buildPhase = ''
                    runHook preBuild
                    ./node_modules/.bin/gulp
                    runHook postBuild
                  '';

                  installPhase = ''
                    mkdir -p $out
                    cp -r web/css web/js $out/
                  '';
                };
              in
              pkgs.php.buildComposerProject2 (finalAttrs: {
                pname = "avogadrio";
                version = "1.0.0";

                inherit frontend;

                src = lib.sources.cleanSource ./.;
                vendorHash = "sha256-Km9xynFgQ0EaYsCk1V/1MplR84RNeT9ceNhtRtwOzO4=";

                postInstall = ''
                  cp -r ${frontend}/js ${frontend}/css $out/share/php/avogadrio/web/
                  substituteInPlace $out/share/php/avogadrio/vendor/twig/twig/lib/Twig/Node.php \
                    --replace-fail "is_object(\$node) ? get_class(\$node) : null === \$node ? 'null' : gettype(\$node)" \
                    "is_object(\$node) ? get_class(\$node) : (null === \$node ? 'null' : gettype(\$node))"
                '';
              });

            sourire =
              let
                src = pkgs.runCommand "sourire-src" { } ''
                  cp -r --no-preserve=mode ${
                    pkgs.fetchFromGitHub {
                      owner = "tmoerman";
                      repo = "sourire";
                      rev = "0f1042812c7104917986677bea2d59e5ea7ff55a";
                      hash = "sha256-cRWvQ8uGkzZLKPOMWCfx9zg6DzFmrb4i82R3UlBaMk4=";
                    }
                  } $out
                  cd $out
                  patch -p1 < ${./sourire-deps.patch}
                '';

                locker = inputs.clojure-nix-locker.lib.customLocker {
                  inherit pkgs;
                  command = "${lib.getExe pkgs.leiningen} create-standalone";
                  lockfile = "./sourire-deps.lock.json";
                  src = pkgs.symlinkJoin {
                    name = "sourire-locker-src";
                    paths = [
                      src
                      (pkgs.runCommand "sourire-deps-lock" { } ''
                        mkdir -p $out
                        cp ${./sourire-deps.lock.json} $out/sourire-deps.lock.json
                      '')
                    ];
                  };
                };
              in
              pkgs.stdenvNoCC.mkDerivation {
                name = "sourire";
                version = "dev";

                inherit src;
                inherit (locker) locker;

                nativeBuildInputs = with pkgs; [
                  makeWrapper
                  clojure
                  leiningen
                ];

                buildPhase = ''
                  source ${locker.shellEnv}
                  lein create-standalone
                '';

                installPhase = ''
                  mkdir -p $out
                  cp target/sourire-0.1.0-SNAPSHOT-standalone.jar $out/sourire.jar
                  makeWrapper ${pkgs.openjdk}/bin/java $out/bin/sourire \
                    --add-flags "-jar $out/sourire.jar"
                '';
              };
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              self'.packages.sourire
              self'.packages.avogadrio
              self'.packages.avogadrio.frontend
            ];
            packages = [ self'.packages.sourire.locker ];
          };

          formatter = pkgs.nixfmt-tree;
        };
    };
}
