{ buildGo122Module, fetchFromGitHub, stdenv, lib }:
buildGo122Module (rec {
  pname = "pget";
  version = "0.8.2";
  src = fetchFromGitHub {
    owner = "replicate";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-FVuEfR035Y47ky1Ecku1GYE6P/NN5sc8HMnn/+9/wRE=";
  };
  vendorHash = "sha256-iX3wXXGJ29v7PNHrj9LwJg7HGZ4IkFoafVnJILBVulA=";
  ldflags = [
    "-X github.com/replicate/pget/pkg/version.Version=${version}"
    "-X github.com/replicate/pget/pkg/version.OS=${stdenv.targetPlatform.uname.system}"
    "-X github.com/replicate/pget/pkg/version.Arch=${stdenv.targetPlatform.linuxArch}"
    "-X github.com/replicate/pget/pkg/version.CommitHash=2e764c4c67c0fee366cd57d03e190b95040636e0"
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
