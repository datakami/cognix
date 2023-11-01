{
  inputs = {
    cognix.url = "github:datakami/cognix";
  };

  outputs = { self, cognix }@inputs: {
    packages.x86_64-linux.default = cognix.legacyPackages.x86_64-linux.callCognix ./.;
    devShells.x86_64-linux.default = cognix.devShells.x86_64-linux.default;
    apps.x86_64-linux.default = {
      type = "app";
      program = "${cognix.packages.x86_64-linux.default}/bin/cognix";
    };
  };
}
