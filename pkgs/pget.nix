{ buildGoModule, fetchFromGitHub, lib }:
buildGoModule (rec {
  pname = "pget";
  version = "0.0.4";
  src = fetchFromGitHub {
    owner = "replicate";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-u1UMpZGiJK3cwo3E2u8E6b4F7fctQEiMTreWajijYes=";
  };
  vendorHash = "sha256-y1q/eL5vcpieAy1wo9QxTwMiKjn7QimZMZciEvSG6Zc=";
  ldflags = [
    "-w" "-s"
  ];

  meta = with lib; {
    description = " parallel fetch";
    homepage = "https://github.com/replicate/pget";
    license = licenses.asl20;
    maintainers = with maintainers; [ yorickvp ];
  };
})
