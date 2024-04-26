{ rustPlatform, fetchFromGitHub, lib, cmake, openssl, pkg-config, perl }:
rustPlatform.buildRustPackage {
  pname = "uv";
  version = "0.1.34.post";
  nativeBuildInputs = [ cmake pkg-config perl ];
  buildInputs = [ openssl ];
  src = fetchFromGitHub {
    owner = "yorickvP";
    repo = "uv";
    rev = "03fa5567e96465c9e68903cb612cece6bc98228d";
    hash = "sha256-5kqQsalnTyDuCA3JVhF0g3BOQNl159MT6raQuIBw+Cc=";
  };
  cargoLock = {
    lockFile = builtins.fetchurl {
      url = "https://raw.githubusercontent.com/astral-sh/uv/03fa5567e96465c9e68903cb612cece6bc98228d/Cargo.lock";
      sha256 = "1qy7d6lim0zjzradaakj0xrjcar6139rwklcdi9sn3z3b88c1hfz";
    };
    outputHashes = {
      "async_zip-0.0.17" = "sha256-Q5fMDJrQtob54CTII3+SXHeozy5S5s3iLOzntevdGOs=";
      "pubgrub-0.2.1" = "sha256-sqC7R2mtqymYFULDW0wSbM/MKCZc8rP7Yy/gaQpjYEI=";
    };
  };
  doCheck = false;
}
