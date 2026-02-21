import logging
from typing import Dict, Any

import httpx
import kserve
from kserve import Model, ModelServer

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Map class index -> species name
IRIS_CLASSES = {
    0: "Iris-Setosa",
    1: "Iris-Versicolor",
    2: "Iris-Virginica",
}


class IrisTransformer(Model):
    """KServe Transformer for the Iris classifier.

    Pre-processing  : Converts a simple dict of flower measurements into the
                      V2 KServe inference protocol format expected by the model.
    Post-processing : Converts the model's INT64 class-index output back into
                      a human-readable species name.

    The `predict()` method is overridden to call the predictor directly over
    HTTP so that we are not dependent on the `PredictorConfig` context variable,
    which is not propagated to uvicorn worker subprocesses.
    """

    def __init__(self, name: str, predictor_host: str, protocol: str = "v2"):
        super().__init__(name)
        self.predictor_host = predictor_host
        self.protocol = protocol
        self.ready = True

    # ------------------------------------------------------------------
    # Pre-process: simple JSON  →  V2 inference request
    # ------------------------------------------------------------------
    def preprocess(self, inputs: Dict[str, Any], headers: Dict[str, str] = None) -> Dict[str, Any]:
        """Transform incoming user-friendly input into the V2 inference protocol.

        Expected input:
            {
                "sepal_length": 5.1,
                "sepal_width":  3.5,
                "petal_length": 1.4,
                "petal_width":  0.2
            }

        V2 output sent to the predictor:
            {
                "inputs": [{
                    "name": "input-0",
                    "shape": [1, 4],
                    "datatype": "FP32",
                    "data": [[5.1, 3.5, 1.4, 0.2]]
                }]
            }
        """
        logger.info("preprocess input: %s", inputs)

        sepal_length = float(inputs["sepal_length"])
        sepal_width  = float(inputs["sepal_width"])
        petal_length = float(inputs["petal_length"])
        petal_width  = float(inputs["petal_width"])

        v2_request = {
            "inputs": [
                {
                    "name": "input-0",
                    "shape": [1, 4],
                    "datatype": "FP32",
                    "data": [[sepal_length, sepal_width, petal_length, petal_width]],
                }
            ]
        }

        logger.info("preprocess output (V2 request): %s", v2_request)
        return v2_request

    # ------------------------------------------------------------------
    # predict: forward V2 request to the predictor over HTTP directly
    # ------------------------------------------------------------------
    async def predict(self, payload: Dict[str, Any], headers: Dict[str, str] = None, response_headers: Dict[str, str] = None) -> Dict[str, Any]:
        """Forward the pre-processed V2 request to the predictor.

        We override `predict()` to call the predictor directly via httpx.
        This avoids the `PredictorConfig` context variable, which is not
        propagated to uvicorn worker subprocesses in KServe 0.16.
        """
        predictor_url = f"http://{self.predictor_host}/v2/models/{self.name}/infer"
        logger.info("Forwarding V2 request to predictor: %s", predictor_url)

        async with httpx.AsyncClient() as client:
            response = await client.post(
                predictor_url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=60.0,
            )
            response.raise_for_status()
            result = response.json()

        logger.info("Predictor response: %s", result)
        return result

    # ------------------------------------------------------------------
    # Post-process: V2 inference response  →  friendly JSON
    # ------------------------------------------------------------------
    def postprocess(self, response: Dict[str, Any], headers: Dict[str, str] = None) -> Dict[str, Any]:
        """Convert the V2 model response into a user-friendly prediction dict.

        Model output example:
            {
                "model_name": "iris-classifier",
                "outputs": [{
                    "name": "output-0",
                    "datatype": "INT64",
                    "shape": [1],
                    "data": [0]
                }]
            }

        Transformer output:
            {"predictions": ["Iris-Setosa"]}
        """
        logger.info("postprocess input (V2 response): %s", response)

        outputs = response.get("outputs", [])
        if not outputs:
            logger.warning("No outputs found in model response")
            return {"predictions": []}

        data = outputs[0].get("data", [])
        predictions = []
        for class_index in data:
            label = IRIS_CLASSES.get(int(class_index), f"Unknown({class_index})")
            predictions.append(label)

        result = {"predictions": predictions}
        logger.info("postprocess output: %s", result)
        return result


if __name__ == "__main__":
    # kserve.model_server.parser already defines:
    #   --model_name, --predictor_host, --predictor_protocol, etc.
    # Adding them again causes argparse.ArgumentError: conflicting option string.
    args, _ = kserve.model_server.parser.parse_known_args()

    transformer = IrisTransformer(
        name=args.model_name,
        predictor_host=args.predictor_host,
        protocol=args.predictor_protocol,
    )

    server = ModelServer()
    server.start(models=[transformer])
