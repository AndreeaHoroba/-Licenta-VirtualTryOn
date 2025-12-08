from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
from diffusers import StableDiffusionPipeline
import base64
from io import BytesIO

# Initialize the mini-app for the Cloud Server
app = FastAPI(title="Vast.ai GPU Garment Generator")

# Load the model directly into the RTX 4090 VRAM when the server starts
try:
    print("Loading Stable Diffusion model onto GPU...")
    model_id = "runwayml/stable-diffusion-v1-5"
    pipe = StableDiffusionPipeline.from_pretrained(model_id, torch_dtype=torch.float16)
    pipe = pipe.to("cuda")
    print("Model loaded successfully!")
except Exception as e:
    print(f"Failed to load model: {e}")


class PromptRequest(BaseModel):
    prompt: str


@app.post("/generate-garment/")
async def generate_garment(request: PromptRequest):
    """
    Endpoint exposed on Vast.ai.
    Receives a text prompt, runs inference on the RTX 4090, and returns the Base64 image.
    """
    try:
        # 1. Prompt Engineering for E-commerce format
        system_modifiers = "flat lay photography, high quality, pure white background, centered clothing item"
        negative_prompt = "human model, body parts, text, watermark, blurry, low resolution, multiple items, realistic background"

        final_prompt = f"{request.prompt}, {system_modifiers}"

        # 2. Neural Inference
        image = pipe(
            prompt=final_prompt,
            negative_prompt=negative_prompt,
            num_inference_steps=30
        ).images[0]

        # 3. Encode image to Base64 to send it back via HTTP
        buffer = BytesIO()
        image.save(buffer, format="PNG")
        base64_string = base64.b64encode(buffer.getvalue()).decode("utf-8")

        return {"status": "success", "image_base64": base64_string}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))