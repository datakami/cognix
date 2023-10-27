from cog import BasePredictor, Input, BaseModel
from torch import Tensor
from transformers import AutoTokenizer, AutoModel
from subprocess import run
import torch

class Output(BaseModel):
    vectors: list[float]
    text: str

def average_pool(last_hidden_states: Tensor,
                 attention_mask: Tensor) -> Tensor:
    last_hidden = last_hidden_states.masked_fill(~attention_mask[..., None].bool(), 0.0)
    return last_hidden.sum(dim=1) / attention_mask.sum(dim=1)[..., None]

class Predictor(BasePredictor):
    def setup(self) -> None:
        """Load the model into memory"""
        run(["download-weights"], check=True)
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.tokenizer = AutoTokenizer.from_pretrained("thenlper/gte-large")
        self.model = AutoModel.from_pretrained("thenlper/gte-large").to(self.device)

    def predict(
        self,
        text: str = Input(description="Text string to embed"),
    ) -> Output:
        """Run a single prediction on the model"""

        # Tokenize the input texts
        batch_dict = self.tokenizer([text], max_length=512, padding=True, truncation=True, return_tensors='pt').to(self.device)

        outputs = self.model(**batch_dict)
        embeddings = average_pool(outputs.last_hidden_state, batch_dict['attention_mask'])

        return Output(vectors=embeddings[0].tolist(), text=text)

