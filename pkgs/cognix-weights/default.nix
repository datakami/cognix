{ python3, lib, stdenv, pget, nix, makeWrapper }:
let
  py-buildtime = (python3.withPackages (ps: [ ps.pygit2 ps.google-cloud-storage ]));
  py-runtime = python3;
in
stdenv.mkDerivation {
    name = "cognix-weights";
    src = ./.;
    nativeBuildInputs = [ makeWrapper ];
    installPhase = ''
      makeWrapper ${py-buildtime}/bin/python $out/bin/fetchHuggingface \
        --add-flags $src/fetchHuggingface.py \
        --prefix PATH : ${lib.makeBinPath [ nix ]}
      makeWrapper ${py-runtime}/bin/python $run/bin/downloadWeights \
        --add-flags $src/downloadWeights.py \
        --prefix PATH : ${lib.makeBinPath [ pget ]}
    '';
    outputs = [ "out" "run" ];
}
