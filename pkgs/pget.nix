{ buildGo121Module, fetchFromGitHub, lib }:
buildGo121Module (rec {
  pname = "pget";
  version = "0.5.4";
  src = fetchFromGitHub {
    owner = "replicate";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-FWK1tOzj6+A0vYXH35ZdQgLu5BFVBwknw6SlPifHbp4=";
  };
  vendorHash = "sha256-A5xfD4ykk34JDt7h976rKJD87KkeQ2rIY2tIfhjdO9g=";
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
