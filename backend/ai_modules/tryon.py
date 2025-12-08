import replicate
import os
import requests
import rembg
from io import BytesIO
from PIL import Image
from dotenv import load_dotenv

load_dotenv()


def prepare_image_for_api(image_bytes: bytes) -> BytesIO:
    """ Cleans the image and converts it to RGB PNG with a white background. """
    try:
        img = Image.open(BytesIO(image_bytes))
        if img.mode == "RGBA":
            background = Image.new("RGB", img.size, (255, 255, 255))
            background.paste(img, mask=img.split()[3])
            img = background
        elif img.mode != "RGB":
            img = img.convert("RGB")
        output_buffer = BytesIO()
        img.save(output_buffer, format="PNG")
        output_buffer.seek(0)
        return output_buffer
    except Exception as e:
        print(f"Local image processing error: {e}")
        raise ValueError("Corrupted image.")


def apply_try_on(body_bytes: bytes, clothing_bytes: bytes, item_type: str = "TOP") -> bytes:
    print(f" Preparing images for Try-On (Type: {item_type})...")

    clean_body = prepare_image_for_api(body_bytes)
    clean_clothing = prepare_image_for_api(clothing_bytes)

    model_owner = "cuuupid"
    model_name = "idm-vton"
    version_id = "c871bb9b046607b680449ecbae55fd8c6d945e0a1948644bf2361b3d021d3ff4"

    import io

    category = "upper_body"
    prompt_text = "a piece of clothing"

    img = Image.open(io.BytesIO(clothing_bytes))
    width, height = img.size
    aspect_ratio = height / width
    print(f" Garment proportion (Height/Width): {aspect_ratio:.2f}")

    if item_type == "PANTS":
        category = "lower_body"
        if aspect_ratio > 1.4:
            print(" Detected: LONG skirt.")
            prompt_text = "long flowing skirt, maxi skirt, floor-length dress bottom, elegant long skirt reaching the ankles, covering legs"
        else:
            print("Detected: SHORT skirt.")
            prompt_text = "short skirt, mini skirt, above the knee dress bottom, showing legs"
    elif item_type == "DRESS":
        category = "dresses"
        if aspect_ratio > 1.8:
            prompt_text = "beautiful long flowing dress, floor-length elegant gown"
        else:
            prompt_text = "short dress, above the knee elegant dress, cocktail dress"
    elif item_type == "TOP":
        category = "upper_body"
        prompt_text = "upper body clothing, top, shirt"

    max_retries = 3
    for attempt in range(max_retries):
        try:
            print(f" Attempt {attempt + 1} at Replicate ({category})...")
            output = replicate.run(
                f"{model_owner}/{model_name}:{version_id}",
                input={
                    "human_img": clean_body,
                    "garm_img": clean_clothing,
                    "garment_des": prompt_text,
                    "category": category,
                    "crop": True,
                    "seed": 42,
                    "steps": 30,
                    "force_dc": False
                }
            )
            break
        except Exception as e:
            print(f" Error on attempt {attempt + 1}: {e}")
            if attempt < max_retries - 1:
                import time
                time.sleep(2)
                clean_body.seek(0)
                clean_clothing.seek(0)
            else:
                raise Exception(f"Persistent network error at Replicate: {e}")

    print(" Downloading the result...")
    if isinstance(output, list) and len(output) > 0:
        image_url = output[0]
    else:
        image_url = output

    if not image_url:
        raise Exception("Replicate did not return any image.")

    response = requests.get(image_url)
    if response.status_code == 200:
        print(" Removing the background from the Replicate result...")
        return rembg.remove(response.content)
    else:
        raise Exception(f"Download error (Status {response.status_code})")
