import os
import logging

import requests
import streamlit as st

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# -----------------------------------------------------------------------
# Configuration from environment variables
# -----------------------------------------------------------------------
HOSTNAME = os.getenv("HOSTNAME", "iris-classifier-kserve.servicefoundry.org")
MODEL_NAME = os.getenv("MODEL_NAME", "iris-classifier")
FULL_URL = f"https://{HOSTNAME}/v1/models/{MODEL_NAME}:predict"


# -----------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------

def build_payload(sepal_length: float, sepal_width: float,
                  petal_length: float, petal_width: float) -> dict:
    """Build the simple JSON payload that the KServe Transformer accepts."""
    return {
        "sepal_length": sepal_length,
        "sepal_width": sepal_width,
        "petal_length": petal_length,
        "petal_width": petal_width,
    }


def get_prediction(payload: dict, url: str = FULL_URL) -> dict | None:
    """
    POST the payload to the KServe Transformer endpoint.

    Returns the parsed JSON response dict, or None on error.
    """
    try:
        logger.info("POST %s  payload=%s", url, payload)
        response = requests.post(
            url,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=30,
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as exc:
        logger.error("Request failed: %s", exc)
        st.error(f"Request failed: {exc}")
        return None


def parse_prediction(response: dict) -> str | None:
    """Extract the first prediction label from the transformer response."""
    predictions = response.get("predictions", [])
    if predictions:
        return predictions[0]
    return None


# -----------------------------------------------------------------------
# Streamlit UI
# -----------------------------------------------------------------------

def main():
    st.set_page_config(
        page_title="Iris Classifier — Transformer",
        page_icon="🌸",
        layout="centered",
    )

    st.title("🌸 Iris Flower Classification")
    st.caption(f"Powered by KServe Transformer · `{FULL_URL}`")

    st.divider()

    # ── Sidebar: feature inputs ──────────────────────────────────────────
    st.sidebar.header("🌿 Flower Measurements")

    sepal_length = st.sidebar.slider("Sepal Length (cm)", 4.0, 8.0, 5.1, 0.1)
    sepal_width  = st.sidebar.slider("Sepal Width (cm)",  2.0, 4.5, 3.5, 0.1)
    petal_length = st.sidebar.slider("Petal Length (cm)", 1.0, 7.0, 1.4, 0.1)
    petal_width  = st.sidebar.slider("Petal Width (cm)",  0.1, 2.5, 0.2, 0.1)

    # ── Main panel: input summary ────────────────────────────────────────
    st.subheader("Input Parameters")
    col1, col2 = st.columns(2)
    col1.metric("Sepal Length", f"{sepal_length} cm")
    col1.metric("Sepal Width",  f"{sepal_width} cm")
    col2.metric("Petal Length", f"{petal_length} cm")
    col2.metric("Petal Width",  f"{petal_width} cm")

    st.divider()

    # ── Classify button ──────────────────────────────────────────────────
    if st.button("🔍 Classify", use_container_width=True, type="primary"):
        payload = build_payload(sepal_length, sepal_width, petal_length, petal_width)

        with st.spinner("Calling KServe Transformer…"):
            result = get_prediction(payload)

        if result is not None:
            label = parse_prediction(result)

            if label:
                st.success(f"### ✅ Predicted Species: **{label}**")
            else:
                st.warning("The transformer returned an empty predictions list.")

            with st.expander("📄 Raw JSON Response"):
                st.json(result)

            with st.expander("📤 Request Payload Sent"):
                st.json(payload)


if __name__ == "__main__":
    main()
