# Prediction interface for Cog ⚙️
# https://github.com/replicate/cog/blob/main/docs/python.md

from cog import BasePredictor, Input, Path
from subprocess import run
import torch

class Predictor(BasePredictor):
    def setup(self) -> None:
        """Load the model into memory to make running multiple predictions efficient"""

    def predict(
        self,
    ) -> str:
        """Run a single prediction on the model"""
        if torch.cuda.is_available():
            return "cuda works!"
        return "cuda failed :("
