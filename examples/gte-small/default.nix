{ pkgs, ... }:
let
  # workaround: the filename needs to be right
  toSymlink = drv: name: pkgs.runCommand "${drv.name}-renamed" {} ''
    mkdir -p $(dirname $out/${name})
    ln -s ${drv} $out/${name}
  '';
  rename = drv: name: "${toSymlink drv name}/${name}";
  cpu_torch = rename (pkgs.fetchurl {
    url = "https://download.pytorch.org/whl/cpu/torch-2.0.1%2Bcpu-cp310-cp310-linux_x86_64.whl";
    hash = "sha256-/sJXJJugFMaGKaGZSwxuc1biDhr8d6h7mUGkDlCVKF0=";
  }) "torch-2.0.1+cpu-cp310-cp310-linux_x86_64.whl";
  model = pkgs.fetchurl {
    url = "https://huggingface.co/thenlper/gte-small/resolve/c20abe89ac0cdf484944ebdc26ecaaa1bfc9cf89/model.safetensors";
    hash = "sha256-mh65C7rDI+oIqlYptiT+auddsSG5BHmcImah4sLeItI=";
  };
  weights = pkgs.fetchgit {
    url = "https://huggingface.co/thenlper/gte-small";
    rev = "c20abe89ac0cdf484944ebdc26ecaaa1bfc9cf89";
    hash = "sha256-+9iyjUF6DpJD1ISUS4j5vqYzgL9MmlyknAsXu+LDkdA=";
    postFetch = ''
      cp ${model} $out/model.safetensors
    '';
  };
  weights_renamed = toSymlink weights "src/thenlper/gte-small";
in
{
  cog = {
    name = "gte-small";
    build.gpu = true;
    system_packages = [ weights_renamed ];
    python_version = "3.10";
    python_packages = [ cpu_torch "transformers" ];
    python_snapshot_date = "2023-10-05";
    predict = "${./predict.py}:Predictor";
  };
}
