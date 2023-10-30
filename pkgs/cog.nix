{ stdenv, fetchurl }:
stdenv.mkDerivation rec {
  pname = "cog";
  version = "0.8.6";
  src = fetchurl {
    url = "https://github.com/replicate/cog/releases/download/v${version}/cog_linux_x86_64";
    hash = "sha256-Ng62tbRmlrL23JRdP3Zt4nT8JfLrHThF0mmMf1jee7g=";
  };
  dontUnpack = true;
  installPhase = ''
    install -Dm 755 $src $out/bin/cog
    mkdir -p $out/share/{fish/vendor_completions.d,bash-completion/completions,zsh/site-functions}
    $out/bin/cog completion bash > $out/share/bash-completion/completions/cog
    $out/bin/cog completion fish > $out/share/fish/vendor_completions.d/cog.fish
    $out/bin/cog completion zsh > $out/share/zsh/site-functions/_cog
  '';
}
