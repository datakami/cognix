# Cognix [WIP]

Build cog images deterministically using Nix.


## Example (./examples/torch-demo/default.nix):
```
# build the image and stream it to docker
$ nix build github:yorickvp/cognix#torch-demo && ./result | docker load

$ cog predict torch-demo:......

Starting Docker image torch-demo:.... and running setup()...
Running prediction...
cuda works!

$ docker image ls torch-demo:....
REPOSITORY   TAG                                IMAGE ID       CREATED        SIZE
torch-demo   c209d6h86w7j7ksnjks4rkynjfw3ahwb   8fe343a42975   53 years ago   4.7GB

# explore the contribution of various packages to the image size
# format: store-path                                                           own-size  size-with-deps
$ nix path-info ./result -rSsh | sort -hk3
[..]
/nix/store/rbrw4jb0bz54kznbwwf47lj7k77jg00j-python3.10-nvidia-cudnn-cu11-8.5.0.96      	 868.8M	   1.4G
/nix/store/qqrzrbsgzk3bbg1pfficq5l2qnyz2b2k-python3.10-torch-2.0.1                     	   1.3G	   4.3G
```

## Example (./examples/ebsynth-cpu/default.nix):
```
$ git clone ...
$ nix build .#ebsynth-cpu && ./result | docker load
$ cog predict ebsynth-cpu:...... -i style=@...
```

# Why?
- Smaller images, they only contain the packages needed at runtime.
- Determinism! Building an image twice on different machines should give you the exact same image, even after years.
- Completeness: The dependencies for an image are fully specified, so there are no build steps you don't know about.
- Better, granular caching: Nix generates a docker image with a layer for every dependency (up to ~limit, then it starts merging cleverly), images sharing dependencies will share layers as well.


# Not done yet
- [x] GPU support
- [ ] Automatically parsing cog.yaml
- [ ] Auto-resolving torch/cuda versions
- [x] Better ergonomics: module system
- [x] Fully sort out cog/r8 compat
- [x] Other python versions than 3.10
- [x] System dependencies mapping
- [ ] `cog.yaml` run commands
- [ ] Support upgrading `cog` at runtime
- [ ] Injecting weights, probably want to do that outside of nix
- [x] Generating openapi.yaml during the build
