{ rustPlatform, fetchFromGitHub, lib, cmake, openssl, pkg-config, perl }:
rustPlatform.buildRustPackage {
  pname = "uv";
  version = "0.1.34.post";
  nativeBuildInputs = [ cmake pkg-config perl ];
  buildInputs = [ openssl ];
  src = fetchFromGitHub {
    owner = "yorickvP";
    repo = "uv";
    rev = "6ef1d706379a3403d917b75d41697e98f9a0619d";
    hash = "sha256-U4mowALk3XKSzRkhbZT333v3mVlLBpeatl8mwfeg6uw=";
  };
  cargoLock = {
    lockFile = builtins.fetchurl {
      url = "https://raw.githubusercontent.com/astral-sh/uv/6ef1d706379a3403d917b75d41697e98f9a0619d/Cargo.lock";
      sha256 = "12v38b50gyi5g7dz269vl4briw5jffw16mlsmiswh0f6q8nb64q4";
    };
    outputHashes = {
      "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
      "pubgrub-0.2.1" = "sha256-sqC7R2mtqymYFULDW0wSbM/MKCZc8rP7Yy/gaQpjYEI=";
    };
  };
  doCheck = false;
}
