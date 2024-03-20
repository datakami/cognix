{ buildGo122Module, fetchFromGitHub, lib }:
buildGo122Module (rec {
  pname = "pget";
  version = "0.6.2";
  src = fetchFromGitHub {
    owner = "replicate";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-vutkaw7UOpGk1LxHBH13SlQ4YdOzHVduVqedoFGhsfw=";
  };
  vendorHash = "sha256-U+ZoROoaJuvxExFVmUOBslybx2dEgejwfLs6eJvS91o=";
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
