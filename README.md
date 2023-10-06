# Cognix [WIP]

Build cog images deterministically using Nix.

Example (./example-ebsynth/default.nix):
```
$ git clone ...
$ nix build .#ebsynth-cpu.img && ./result | docker load
$ cog predict ebsynth-cpu:...... -i style=@...
```

# Why?
- Smaller images, they only contain the packages needed at runtime.
- Determinism! Building an image twice on different machines should give you the exact same image, even after years.
- Completeness: The dependencies for an image are fully specified, so there are no build steps you don't know about.
- Better, granular caching: Nix generates a docker image with a layer for every dependency (up to ~limit, then it starts merging cleverly), images sharing dependencies will share layers as well.


# Not done yet
- [ ] GPU support
- [ ] Automatically parsing cog.yaml
- [ ] Better ergonomics: module system
- [ ] Fully sort out cog/r8 compat
- [ ] Other python versions than 3.10
- [ ] System dependencies mapping
- [ ] `cog.yaml` run commands
- [ ] Make `pip install -U cog` work
- [ ] Injecting weights, probably want to do that outside of nix
- [ ] Generating openapi.yaml during the build
