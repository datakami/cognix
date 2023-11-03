from typing import Union, List
from cog import BasePredictor, Input, BaseModel
from transformers import AutoModel
#from subprocess import run
import torch
import base64

FORMATS = [
    ("base64", base64.b64encode),
    ("array", lambda x: x.tolist()),
]
FORMATS_MAP = dict(FORMATS)

class Output(BaseModel):
    vectors: str | list[float]
    text: str

class Predictor(BasePredictor):
    def setup(self) -> None:
        """Load the model into memory"""
        #run(["download-weights"], check=True)
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model = AutoModel.from_pretrained("jinaai/jina-embeddings-v2-small-en", trust_remote_code=True, local_files_only=True).eval().to(self.device)

    def predict(
        self,
        text: Union[str, List[str]] = Input(description="Text string to embed"),
        output_format: str = Input(
            description="Format to use in outputs",
            default=FORMATS[0][0],
            choices=[k for (k, _v) in FORMATS],
        ),
    ) -> list[Output]:
        """Run a single prediction on the model"""
        map_func = FORMATS_MAP[output_format]
        if not isinstance(text, list):
            text = [text]

        embeddings = self.model.encode(text)
        res = []
        for text_, vectors in zip(text, embeddings):
            res.append(Output(vectors=map_func(vectors), text=text_))
        return res
