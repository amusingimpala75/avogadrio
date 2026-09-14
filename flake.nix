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
                avogadrio -S 0.0.0.0:''${PORT:-8080} &
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

              config = {
                entrypoint = [ "${lib.getExe self'.packages.default}" ];
                env = [ "XDG_CACHE_HOME=/tmp" ];
              };
            };

            avogadrio =
              let
                src = lib.cleanSourceWith {
                  src = ./.;
                  filter = path: type:
                    let
                      name = lib.baseNameOf path;
                    in
                      !(builtins.elem name [ "flake.nix" "flake.lock" "README.md" ])
                      && lib.cleanSourceFilter path type;
                };

                version = "1.0.0";

                frontend = pkgs.buildNpmPackage {
                  pname = "avogadrio-frontend";
                  inherit src version;

                  npmDepsHash = "sha256-e3oLRuvaVN70uzfzJuPI9nlKcMD5o5W2yElLw0k+M+k=";

                  buildPhase = ''
                    runHook preBuild
                    ./node_modules/.bin/gulp
                    runHook postBuild
                  '';

                  installPhase = ''
                    mkdir -p $out
                    cp -r web/css web/js node_modules/jquery \
                      node_modules/bootstrap node_modules/spectrum-colorpicker \
                      node_modules/animate.css node_modules/font-awesome \
                      node_modules/flat-ui $out/
                  '';
                };

                php = pkgs.php.withExtensions({ all, ... }: with all; [
                  # Composer:
                  ctype
                  filter
                  iconv
                  openssl
                  zlib
                  # Avogadrio:
                  # ctype
                  fileinfo
                  # filter
                  gd
                  # openssl
                ]);
              in
              php.buildComposerProject2 (finalAttrs: {
                pname = "avogadrio";

                inherit frontend src version;

                vendorHash = "sha256-Km9xynFgQ0EaYsCk1V/1MplR84RNeT9ceNhtRtwOzO4=";

                nativeBuildInputs = [ pkgs.makeWrapper ];

                postInstall = ''
                  cp -r ${frontend}/js ${frontend}/css ${frontend}/jquery \
                    ${frontend}/bootstrap ${frontend}/spectrum-colorpicker \
                    ${frontend}/animate.css ${frontend}/font-awesome \
                    ${frontend}/flat-ui $out/share/php/avogadrio/web/
                  substituteInPlace $out/share/php/avogadrio/vendor/twig/twig/lib/Twig/Node.php \
                    --replace-fail "is_object(\$node) ? get_class(\$node) : null === \$node ? 'null' : gettype(\$node)" \
                    "is_object(\$node) ? get_class(\$node) : (null === \$node ? 'null' : gettype(\$node))"

                  mkdir -p $out/etc/avogadrio
                  cp ${./config/config.yaml.dist} $out/etc/avogadrio/config.yaml

                  makeWrapper ${lib.getExe php} $out/bin/avogadrio \
                    --add-flags "-t $out/share/php/avogadrio/web" \
                    --set-default AVOGADRIO_CONFIG "$out/etc/avogadrio/config.yaml"
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
              self'.packages.avogadrio
              self'.packages.avogadrio.frontend
            ];
            packages = [ self'.packages.sourire.locker ];
          };

          formatter = pkgs.nixfmt-tree;
        };
    };
}
