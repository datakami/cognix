{ python3, lib, stdenv, nix, cog, makeWrapper }:
let
  py = (python3.withPackages (ps: [ ps.click ]));
in
stdenv.mkDerivation {
    name = "cognix-cli";
    src = ./.;
    nativeBuildInputs = [ makeWrapper ];
    installPhase = ''
      makeWrapper ${py}/bin/python $out/bin/cognix \
        --add-flags $src/index.py \
        --prefix PATH : ${lib.makeBinPath [ nix cog ]}
    '';
    meta.mainProgram = "cognix";
}
