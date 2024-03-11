{ buildGo122Module, fetchFromGitHub, lib }:
buildGo122Module (rec {
  pname = "pget";
  version = "0.7.1";
  src = fetchFromGitHub {
    owner = "replicate";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-oABvqeEdq1gxM8aoGkjPw1xTV8SG29M9g77NJ4ko/NM=";
  };
  vendorHash = "sha256-Jx5d+wCmwXa/XqdrSTxW58ZVZPvYXn4fnxRREUFjerg=";
  ldflags = [
    "-X github.com/replicate/pget/pkg/version.Version=${version}"
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
