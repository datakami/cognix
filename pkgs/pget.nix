{ buildGoModule, fetchFromGitHub, lib }:
buildGoModule (rec {
  pname = "pget";
  version = "0.1.1";
  src = fetchFromGitHub {
    owner = "replicate";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-nKJCKN55a3wE3DE0cuIMEcXa7hVu9lBM1/uX/ojDmL8=";
  };
  vendorHash = "sha256-elbFgpLf6dzg1xqWQgg9Vz0GtQkU5cBuC0q7WYIiWLM=";
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
