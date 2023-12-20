{ config, lib, dream2nix, pkgs, ... }:
let
  cognixcfg = config.cognix;
  cfg = config.cog.build;

  # conditional overrides: only active when a lib is in use
  pipOverridesModule = { config, lib, ... }:
    let
      overrides = import ./../overrides.nix;
      metadata = config.lock.content.fetchPipMetadata.sources;
    in {
      pip.drvs = lib.mapAttrs (name: info: overrides.${name} or { }) metadata;
    };

  # derivation containing all files in dir, basis of /src
  entirePackage = pkgs.runCommand "cog-source" {
    src = builtins.path {
      name = "cognix-src-in";
      path = cognixcfg.rootPath;
      filter =
        if cognixcfg.sourceIgnores != ""
        then pkgs.nix-gitignore.gitignoreFilterPure pkgs.lib.cleanSourceFilter cognixcfg.sourceIgnores cognixcfg.rootPath
        else pkgs.lib.cleanSourceFilter;
    };
    nativeBuildInputs = [ pkgs.yj pkgs.jq ];
  } ''
    mkdir $out
    cp -r $src $out/src
    chmod -R +w $out
    # we have to modify cog.yaml to make sure predict: is in there
    yj < $src/cog.yaml | jq --arg PREDICT "${config.cog.predict}" '.predict = $PREDICT' \
      ${if config.cog.train != null then ''| jq --arg TRAIN "${config.cog.train}" '.train = $TRAIN' '' else ""} \
      > $out/src/cog.yaml
    ${cognixcfg.postCopyCommands}
  '';
  # add org.cogmodel and run.cog prefixes to attr set
  mapAttrNames = f: set:
    lib.listToAttrs (map (attr: { name = f attr; value = set.${attr}; }) (lib.attrNames set));
  addLabelPrefix = labels: (mapAttrNames (x: "run.cog.${x}") labels) // (mapAttrNames (x: "org.cogmodel.${x}") labels);
  # hack: replicate calls "pip -U cog" before starting
  fakePip = pkgs.writeShellScriptBin "pip" ''
    echo "this is not a pip (cognix)"
  '';
  # resolve system_packages to cognix.systemPackages
  resolvedSystemPackages = map (pkg:
    if lib.isDerivation pkg then pkg else
      config.cognix.systemPackages.${pkg}) cfg.system_packages;

  generateJSON = args: files: pkgs.runCommand "generated-json.json" {
    nativeBuildInputs = [ pkgs.jq ];
  } ''
    jq --null-input '${args}' \
    ${lib.concatMapStringsSep " " (filename: "--rawfile ${filename} ${files.${filename}}") (builtins.attrNames files)} \
    > $out
  '';

  proxyLockModule = content: {
    # we put python env deps in config.python-env
    # but lock should be top-level
    disabledModules = [ dream2nix.modules.dream2nix.lock ];
    options.lock = {
      fields = lib.mkOption {};
      invalidationData = lib.mkOption {};
      content = lib.mkOption {
        default = content;
      };
    };
  };
  toCogPythonVersion = builtins.replaceStrings ["-beta"] ["b"];
in {
  imports = [
    ./cog-interface.nix
    ./cuda.nix
    ./stream-layered-image.nix
    ({ config, ... }: { public.config = config; })
  ];
  options.openapi-spec = with lib; mkOption {
    type = types.path;
  };
  config = {
    cognix.systemPackages = {
      inherit (pkgs) pget;
    };
    # read dockerignore
    cognix.sourceIgnores = lib.mkIf
      (builtins.pathExists "${cognixcfg.rootPath}/.dockerignore")
      (builtins.readFile "${cognixcfg.rootPath}/.dockerignore");

    cognix.rootPath = if config.paths.package == "./." then
      "${config.paths.projectRoot}"
               else "${config.paths.projectRoot}/${config.paths.package}";

    cognix.environment.PYTHONUNBUFFERED = true;

    dockerTools.streamLayeredImage = {
      passthru.entirePackage = entirePackage;
      # glibc.out is needed for gpu
      contents = with pkgs;
        [
          bashInteractive
          busybox
          cacert
          config.python-env.public.pyEnv
          entirePackage
          fakePip
          glibc.out
        ] ++ resolvedSystemPackages;
      config = {
        Entrypoint = [ "${pkgs.tini}/bin/tini" "--" ];
        Env = lib.mapAttrsToList (name: val: "${name}=${toString val}") config.cognix.environment;
        EXPOSE = 5000;
        CMD = [ "python" "-m" "cog.server.http" ];
        WorkingDir = "/src";
        # todo: my cog doesn't like run.cog.config
        Labels = addLabelPrefix {
          has_init = "true";
          config = builtins.toJSON config.cog;
          cog_version = "${cfg.cog_version}";
          # Initially we had openapi_schema here, but there is a problem with doing that:
          # builtins.readFile has to generate the file to read the contents,
          # and so computing the hash would require building most of the dependencies.
          # To avoid this, we insert openapi_schema in `extraJSONFile`, when all of the deps
          # have been built anyways.
        };
      };
      # needed for gpu:
      # fixed in https://github.com/NixOS/nixpkgs/pull/260063
      extraCommands = ''
        mkdir tmp
        mkdir -p var/run
        ln -s ca-bundle.crt etc/ssl/certs/ca-certificates.crt
      '';
      extraJSONFile = generateJSON ''
        {
          config: { Labels: {
            "run.cog.openapi_schema": $openapi_schema,
            "org.cogmodel.openapi_schema": $openapi_schema
          } }
        }
      '' { openapi_schema = config.openapi-spec; };
    };
    lock = {
      inherit (config.python-env.public.config.lock) fields invalidationData;
    };
    openapi-spec = lib.mkDefault (pkgs.runCommand "openapi.json" {} ''
      cd ${entirePackage}/src
      ${config.python-env.public.pyEnv}/bin/python -m cog.command.openapi_schema > $out
    '');
    python-env = {
      imports = [
        dream2nix.modules.dream2nix.pip
        pipOverridesModule
        (proxyLockModule config.lock.content)
      ];
      paths = { inherit (config.paths) projectRoot package; };
      name = "cog-docker-env";
      version = "0.1.0";
      deps.python = {
        "3.8" = pkgs.python38;
        "3.9" = pkgs.python39;
        "3.10" = pkgs.python310;
        "3.11" = pkgs.python311;
        "3.12" = pkgs.python312;
      }.${cfg.python_version};
      pip = {
        pypiSnapshotDate = cfg.python_snapshot_date;
        requirementsList = [ "cog==${toCogPythonVersion cfg.cog_version}" ] ++ cfg.python_packages
          ++ (lib.concatMap (x: [ "--extra-index-url" x ])
            cfg.python_extra_index_urls);
        #requirementsList = [ "${./inputs}/cog-0.0.1.dev-py3-none-any.whl" ];
        flattenDependencies = true; # todo: why?
        drvs = { };
      };
    };
  };
}
