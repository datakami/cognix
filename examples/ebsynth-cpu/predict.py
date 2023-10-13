# Prediction interface for Cog ⚙️
# https://github.com/replicate/cog/blob/main/docs/python.md

from cog import BasePredictor, Input, Path
from subprocess import run
import tempfile

opts = """
  -style <style.png>
  -guide <source.png> <target.png>
  -output <output.png>
  -weight <value>
  -uniformity <value>
  -patchsize <size>
  -pyramidlevels <number>
  -searchvoteiters <number>
  -patchmatchiters <number>
  -stopthreshold <value>
  -extrapass3x3
  -backend [cpu|cuda]
"""

class Predictor(BasePredictor):
    def setup(self) -> None:
        """Load the model into memory to make running multiple predictions efficient"""
        # self.model = torch.load("./weights.pth")

    def guide_opts(self, guide_source, guide_target, guide_weight):
        if guide_source is guide_target is guide_weight is None:
            return []
        if guide_source is None or guide_target is None:
            raise ValueError("Guide source and target must be specified together")
        ret = []
        ret.extend(["-guide", guide_source, guide_target])
        if guide_weight is not None:
            ret.extend(["-weight", str(guide_weight)])
        return ret
            

    def predict(
        self,
        style: Path = Input(description="Style image"),
        styleWeight: float = Input(description="Style weight", default=None),
        guide1_source: Path = Input(description="Guide image 1 source", default=None),
        guide1_target: Path = Input(description="Guide image 1 target", default=None),
        guide1_weight: float = Input(description="Guide image 1 weight", default=None),
        guide2_source: Path = Input(description="Guide image 2 source", default=None),
        guide2_target: Path = Input(description="Guide image 2 target", default=None),
        guide2_weight: float = Input(description="Guide image 2 weight", default=None),
        uniformity_weight: float = Input(description="Uniformity weight", default=3500),
        patch_size: int = Input(description="Patch size", default=5),
        pyramid_levels: int = Input(description="Pyramid levels. Defaults to the maximum possible.", default=None),
        searchvote_iters: int = Input(description="Search vote iterations", default=6),
        patchmatch_iters: int = Input(description="Patch match iterations", default=4),
        stop_threshold: float = Input(description="Stop threshold", default=5),
        extra_pass_3x3: bool = Input(description="Extra pass 3x3", default=False),
    ) -> Path:
        """Run a single prediction on the model"""
        outpath = tempfile.mkstemp(suffix=".png")[1]
        # run /bin/ebsynth with the parameters
        params = [
            "-style", style,
        ]
        if styleWeight is not None:
            params.extend(["-weight", str(styleWeight)])
            
        params += self.guide_opts(guide1_source, guide1_target, guide1_weight)
        params += self.guide_opts(guide2_source, guide2_target, guide2_weight)

        params.extend([
            "-uniformity", str(uniformity_weight),
            "-patchsize", str(patch_size),
            "-searchvoteiters", str(searchvote_iters),
            "-patchmatchiters", str(patchmatch_iters),
            "-stopthreshold", str(stop_threshold),
        ])
        if pyramid_levels is not None:
            params.extend(["-pyramidlevels", str(pyramid_levels)])
        if extra_pass_3x3:
            params.append("-extrapass3x3")
        params.append("-output")
        params.append(outpath)
        run(["ebsynth", *params], check=True)
        return Path(outpath)
