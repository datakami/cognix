from cog import BasePredictor, Input, BaseModel
from transformers import AutoModel
#from subprocess import run
import torch

class Output(BaseModel):
    vectors: list[float]
    text: str

class Predictor(BasePredictor):
    def setup(self) -> None:
        """Load the model into memory"""
        #run(["download-weights"], check=True)
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model = AutoModel.from_pretrained("jinaai/jina-embeddings-v2-base-en", trust_remote_code=True).to(self.device)

    def predict(
        self,
        text: str = Input(description="Text string to embed"),
    ) -> Output:
        """Run a single prediction on the model"""

        embeddings = self.model.encode([text])
        return Output(vectors=embeddings[0].tolist(), text=text)
