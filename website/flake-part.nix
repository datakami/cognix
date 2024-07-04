{
  self,
  inputs,
  ...
}: {
  perSystem = {
    pkgs,
    lib,
    system,
    ...
  }: let
#     modules' = self.inputs.dream2nix.modules.dream2nix;
#     modules = (lib.filterAttrs (name: _: ! lib.elem name excludes) modules') // {
#       stream-layered-image = ../modules/stream-layered-image.nix;
#       cognix = ../modules/cog-interface.nix;
#       # uv-solver = ../modules/uv-solver.nix;
#       weights = ../modules/weights/interface.nix;
#     };
#     public = lib.genAttrs [
#       "pip"
#       "cognix"
#       "weights"
#     ] (name: null);
  isDirectory = path:
    let
      dirName = builtins.dirOf path;
      baseName = builtins.baseNameOf path;
      dirContent = builtins.readDir dirName;
    in
      builtins.hasAttr baseName dirContent &&
      dirContent.${baseName} == "directory";

# let
    inherit (inputs) dream2nix;
    dream2nixRoot = ./..;
    baseUrl = "https://github.com/nix-community/dream2nix/blob/master";
    cognixUrl = "https://github.com/datakami/cognix/blob/main";

    getOptions = {modules}: let
      options = lib.flip lib.mapAttrs modules (
        name: module: let
          evaluated = lib.evalModules {
            specialArgs = {
              inherit dream2nix;
              packageSets.nixpkgs = pkgs;
            };
            modules = [module];
          };
        in
          evaluated.options
      );
      docs = lib.flip lib.mapAttrs options (name: options:
        pkgs.nixosOptionsDoc {
          inherit options;
          inherit transformOptions;
          warningsAreErrors = false;
        });
    in {
      inherit options docs;
    };

    transformOptions = opt:
      opt
      // {
        declarations =
          map
          (
            decl: let
              declstr = toString decl;
            in {
              url = lib.replaceStrings [ (toString dream2nix) (toString self) ] [ baseUrl cognixUrl ] declstr;
              name = lib.replaceStrings [ (toString dream2nix) (toString self) ] [ "dream2nix" "cognix" ] declstr;
            }
          )
          opt.declarations;
      };
    modules = {
      inherit (dream2nix.modules.dream2nix)
        buildPythonPackage
        builtins-derivation
        mkDerivation
        overrides
        pip;
      cognix = ../modules/cog;
      stream-layered-image = ../modules/stream-layered-image;
      pip-uv = ../modules/pip-uv;
      weights = ../modules/weights/interface.nix;
    };

    options = getOptions {
      inherit modules;
    };

    optionsReference = let

      toSource = sourcePath: if isDirectory sourcePath then sourcePath else dirOf sourcePath;
      publicModules =
        lib.filterAttrs
          (n: v: lib.pathExists ((toSource v) + "/README.md"))
        modules;
      createReference = name: sourcePath: ''
        target_dir="$out/${name}/"
        mkdir -p "$target_dir"
        ln -s ${toSource sourcePath}/README.md "$target_dir/index.md"
        ln -s ${options.docs.${name}.optionsJSON}/share/doc/nixos/options.json "$target_dir"
        cat > "$target_dir/.pages" <<EOF
        collapse_single_pages: true
        nav:
          - ...
        EOF
      '';
    in
      pkgs.runCommand "reference" {
      } ''
        ${lib.concatStringsSep "\n" (lib.attrValues (lib.mapAttrs createReference publicModules))}
      '';

    website =
      pkgs.runCommand "website" {
        nativeBuildInputs = [
          pkgs.python3.pkgs.mkdocs
          pkgs.python3.pkgs.mkdocs-material
          dream2nix.packages.${system}.mkdocs-awesome-pages-plugin
          optionsReference
        ];
      } ''
        cp -rL --no-preserve=mode ${./.}/* .
        cp -rL --no-preserve=mode  ${inputs.dream2nix}/docs/ d2n
        cp -rL --no-preserve=mode ${inputs.dream2nix}/docs/src/style.css src/
        ln -sfT ${optionsReference} ./src/reference
        mkdocs build
      '';
  in {
    packages.optionsReference = optionsReference;
    packages.website = website;
    devShells.website = let
      pythonWithDeps = pkgs.python3.withPackages (
        ps: [
          ps.ipython
          ps.black
          ps.pytest
          ps.pytest-cov
        ]
      );
    in
      pkgs.mkShell {
        inputsFrom = [self.packages.${system}.website];
        packages = [
          pythonWithDeps
        ];

        shellHook = ''
          cd $PRJ_ROOT/website
          if [ ! -d src/reference ]; then
            echo "linking .#reference to src/reference, you need to update this manually\
            and remove it before a production build"
            ln -sfT $(nix build ..#optionsReference --no-link --print-out-paths) src/reference
            ln -sfT ${inputs.dream2nix}/docs/ d2n
            ln -sfT ${inputs.dream2nix}/docs/src/style.css src/style.css
          fi
        '';
      };
  };
}
