{ stdenv, fetchurl }:
stdenv.mkDerivation rec {
  pname = "cog";
  version = "0.9.12";
  src = fetchurl {
    url = "https://github.com/replicate/cog/releases/download/v${version}/cog_linux_x86_64";
    hash = "sha256-DBuR1cHa7Z+WAE+ZrXewgook6uXAKA425N781G9PxPw=";
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
