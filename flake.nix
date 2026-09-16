{
  description = "Avogadr.io is a molecule wallpaper rendering website";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    clojure-nix-locker.url = "github:bevuta/clojure-nix-locker";
    clojure-nix-locker.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
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
            default = pkgs.writeShellApplication {
              name = "avogadrio-sourire";
              text = ''
                avogadrio -S "0.0.0.0:''${PORT:-8080}" &
                sourire :port 8081
              '';
              runtimeInputs = [
                self'.packages.avogadrio
                self'.packages.sourire
              ];
            };

            container = inputs.nix2container.packages.${pkgs.stdenv.hostPlatform.system}.nix2container.buildImage {
              name = "ghcr.io/amusingimpala75/avogadrio";
              tag = "latest";

              config.entrypoint = [ "${lib.getExe self'.packages.default}" ];
            };

            avogadrio =
              let
                version = "1.0.0";

                frontend = pkgs.buildNpmPackage {
                  pname = "avogadrio-frontend";
                  inherit version;

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

                  installPhase = ''
                    mkdir -p $out/share/php/avogadrio/web
                    cp -r web/css web/js $out/share/php/avogadrio/web/
                    cp -r node_modules/bootstrap/dist/css/bootstrap.min.css \
                      node_modules/bootstrap/dist/css/bootstrap.min.css.map \
                      node_modules/flat-ui/css/flat-ui.css \
                      node_modules/font-awesome/css/font-awesome.min.css \
                      node_modules/animate.css/animate.min.css \
                      node_modules/@melloware/coloris/dist/coloris.min.css \
                      node_modules/smiles-drawer/dist/smiles-drawer.min.js \
                      $out/share/php/avogadrio/web/css/
                    cp -r node_modules/bootstrap/dist/js/bootstrap.min.js \
                      node_modules/@melloware/coloris/dist/umd/coloris.min.js \
                      $out/share/php/avogadrio/web/js
                    cp -r node_modules/flat-ui/fonts $out/share/php/avogadrio/web/
                  '';
                };

                php = pkgs.php.withExtensions({ all, ... }: with all; [
                  # Composer:
                  ctype
                  curl
                  filter
                  iconv
                  openssl
                  zlib
                  # Avogadrio:
                  # ctype
                  fileinfo
                  # filter
                  gd
                  mbstring
                  # openssl
                ]);

                backend = php.buildComposerProject2 (finalAttrs: {
                  pname = "avogadrio";

                  inherit version;

                  src = lib.fileset.toSource {
                    root = ./.;
                    fileset = lib.fileset.unions [
                      ./composer.json
                      ./composer.lock
                      ./src
                      ./web
                    ];
                  };

                  vendorHash = "sha256-BL6/JpBhxBBhLGW8ZBhdIZQqUVby3nDnEbcG1aUV9cM=";

                  postInstall = ''
                    mkdir -p $out/share/avogadrio
                    cp ${./config/config.yaml.dist} $out/share/avogadrio/config.yaml.dist
                  '';
                });
              in
                pkgs.symlinkJoin {
                  name = "avogadrio-full";
                  paths = [ frontend backend ];

                  nativeBuildInputs = [ pkgs.makeWrapper ];

                  postBuild = ''
                    makeWrapper ${lib.getExe php} $out/bin/avogadrio \
                      --add-flags "-t $out/share/php/avogadrio/web" \
                      --set-default AVOGADRIO_CONFIG "$out/share/avogadrio/config.yaml.dist"
                  '';
                  passthru = { inherit frontend backend; };
                };

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

                java = pkgs.jre_headless;

                runtime = pkgs.runCommand "java-sourire" {
                  nativeBuildInputs = [
                    java
                    pkgs.binutils
                    pkgs.patchelf
                  ];
                  disallowedReferences = [ java ];
                  meta.mainProgram = "java";
                } ''
                  jlink --module-path "${java}/lib/openjdk/jmods" \
                    --add-modules java.base,java.sql,jdk.unsupported \
                    --strip-debug \
                    --no-man-pages \
                    --no-header-files \
                    --output=$out

                  # This loop was courtesy of ChatGPT
                  # jlink copies the Nix-patched ELF files from the input JDK.
                  # Add paths relative to the new image, then discard obsolete
                  # RPATH entries such as $openjdk/lib/openjdk/lib.
                  while IFS= read -r -d "" file; do
                    rpath="$(patchelf --print-rpath "$file" 2>/dev/null)" || continue
                    patchelf --set-rpath "$rpath:\$ORIGIN:\$ORIGIN/..:\$ORIGIN/../lib" "$file"
                    patchelf --shrink-rpath "$file"
                  done < <(find "$out" -type f -print0)
                '';
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
                  makeWrapper ${lib.getExe runtime} $out/bin/sourire \
                    --add-flags "-jar $out/sourire.jar" \
                    --prefix LD_LIBRARY_PATH : ${
                      pkgs.lib.makeLibraryPath [
                        pkgs.freetype
                        pkgs.fontconfig
                      ]
                    }
                '';
              };
          };

          devShells.default = pkgs.mkShell {
            inputsFrom = [
              self'.packages.sourire
              self'.packages.avogadrio.frontend
              self'.packages.avogadrio.backend
            ];
            packages = [ self'.packages.sourire.locker ];
          };

          formatter = pkgs.nixfmt-tree;
        };
    };
}
