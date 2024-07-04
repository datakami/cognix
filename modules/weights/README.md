---
title: "weights"
state: released
maintainers:
  - YorickvP
---

This module facilitates getting weights (mainly from huggingface) into your cog image. It can do this in two different ways:
1. Embedding into the image. This is suitable for small weights.
2. Loaded from replicate.delivery using [pget](https://github.com/replicate/pget). Your script should call the `download-weights` binary to do this during `setup`.

To use this, add a section to your `cog.yaml`:

```yaml

weights:
  - src: thenlper/gte-large
    download_include: ["model.safetensors"]
```

Then, run `cognix lock` to write the weight information into the `lock.json` file.
Call `cognix push` to push the weights to replicate.delivery.

