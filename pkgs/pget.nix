{ buildGo122Module, fetchFromGitHub, stdenv, lib }:
buildGo122Module (rec {
  pname = "pget";
  version = "0.8.1";
  src = fetchFromGitHub {
    owner = "replicate";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-YWtVP+raAgmMbwbGBKrtDiJ08pV+IjlVe3tKKPm5tCM=";
  };
  vendorHash = "sha256-L7OJ43MjdclrhIn5orcF1m8b03uiz+jJmoyLY5ltJJU=";
  ldflags = [
    "-X github.com/replicate/pget/pkg/version.Version=${version}"
    "-X github.com/replicate/pget/pkg/version.OS=${stdenv.targetPlatform.uname.system}"
    "-X github.com/replicate/pget/pkg/version.Arch=${stdenv.targetPlatform.linuxArch}"
    # "-X github.com/replicate/pget/pkg/version.CommitHash=${src.rev}"
    # not reproducible!:
    # "-X github.com/replicate/pget/pkg/version.BuildTime=$(BUILD_TIME)"
    "-w"
  ];

  meta = with lib; {
    description = " parallel fetch";
    homepage = "https://github.com/replicate/pget";
    license = licenses.asl20;
    maintainers = with maintainers; [ yorickvp ];
  };
})
