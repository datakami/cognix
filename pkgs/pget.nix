{ buildGoModule, fetchFromGitHub, lib }:
buildGoModule (rec {
  pname = "pget";
  version = "0.3.1";
  src = fetchFromGitHub {
    owner = "replicate";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-cS6CCCgrkgWu2wklmoBeHkGdhGuRnV84f0GMEjdT8NM=";
  };
  vendorHash = "sha256-YGP7BQhOuBriKceUYdcvB6UJZ2KJX+2LNbE3f4GvXCo=";
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
