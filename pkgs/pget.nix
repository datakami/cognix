{ buildGoModule, fetchFromGitHub, lib }:
buildGoModule (rec {
  pname = "pget";
  version = "0.2.1";
  src = fetchFromGitHub {
    owner = "Code-Hex";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-SDe9QH1iSRfMBSCfYiOJPXUbDvxH5cCCWvQq9uTWT9Y=";
  };
  vendorHash = "sha256-p9sgvk5kfim3rApgp++1n05S9XrOWintxJfCeeySuBo=";
  ldflags = [
    "-w" "-s"
    "-X main.version=${version}"
  ];

  meta = with lib; {
    description = " The fastest, resumable file download client";
    homepage = "https://github.com/Code-Hex/pget";
    license = licenses.mit;
    maintainers = with maintainers; [ yorickvp ];
  };
})
