import ollama
import json
import re
import os
import io
from PIL import Image
from ultralytics import YOLO


BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MODEL_HAINE_PATH = os.path.join(BASE_DIR, "models", "best.pt")
MODEL_GENTI_PATH = os.path.join(BASE_DIR, "models", "yolo_genti.pt")

model_haine = None
model_genti = None

# Incarcare model haine
if os.path.exists(MODEL_HAINE_PATH):
    try:
        model_haine = YOLO(MODEL_HAINE_PATH)
        print(f"Clothes model loaded ! Classes: {model_haine.names}")
    except Exception as e:
        print(f" Error YOLO clothes {e}")

# Incarcare model genti
if os.path.exists(MODEL_GENTI_PATH):
    try:
        model_genti = YOLO(MODEL_GENTI_PATH)
        print(f"Bags model loaded! Classes: {model_genti.names}")
    except Exception as e:
        print(f"Error YOLO bags {e}")



def auto_tag_clothing(image_bytes: bytes) -> dict:
    print(" Start Hybrid process.. ")

    detected_category = "TOP"
    confidence = 0.0
    haina_gasita = False

    try:
        img = Image.open(io.BytesIO(image_bytes))

        if model_haine:
            print(" Step 1. Looking for clothes..")
            results_haine = model_haine(img, verbose=False)

            for r in results_haine:
                if len(r.boxes) > 0:
                    box = sorted(r.boxes, key=lambda x: x.conf[0], reverse=True)[0]
                    cls_id = int(box.cls[0])
                    conf = float(box.conf[0])
                    raw_class_name = model_haine.names[cls_id].lower()

                    if conf > 0.45:
                        print(f"YOLO detected piece of clothing '{raw_class_name}' (Confidence: {conf:.2f})")

                        # Am actualizat listele strict cu clasele din noul model
                        if raw_class_name in ['pants', 'short', 'skirt']:
                            detected_category = "PANTS"
                        elif raw_class_name == 'dress':
                            detected_category = "DRESS"
                        elif raw_class_name in ['tshirt', 'jacket', 'shirt', 'sweater']:
                            detected_category = "TOP"
                        else:
                            detected_category = "TOP"

                        confidence = conf
                        haina_gasita = True
                        break

        if not haina_gasita and model_genti:
            print("step 2. No piece of clothing.Searching for bags..")
            results_genti = model_genti(img, verbose=False)

            for r in results_genti:
                if len(r.boxes) > 0:
                    box = sorted(r.boxes, key=lambda x: x.conf[0], reverse=True)[0]
                    cls_id = int(box.cls[0])
                    conf = float(box.conf[0])
                    raw_class_name = model_genti.names[cls_id].lower()

                    if raw_class_name in ['handbag', 'backpack'] and conf > 0.55:
                        print(f"YOLO detected a bag'{raw_class_name}' (Confidence: {conf:.2f})")
                        detected_category = "BAG"
                        confidence = conf
                        break

    except Exception as e:
        print(f" Error YOLO Inference: {e}")

    print(f"Sending to Llama forced category {detected_category} and extracting everything..")

    prompt = f"""
    You are analyzing a fashion item identified as: {detected_category}.
    Task:
    1. Create a short description (color, material, style). Max 6 words.
    2. Do NOT change the category from {detected_category}.
    3. Identify 3 attributes strictly from these lists for perfume recommendation:
       - STYLE: [Casual, Elegant, Sport, Bohemian, Business, Streetwear, Evening]
       - COLOR: [Red, Blue, Black, White, Green, Yellow, Pink, Beige]
       - TEXTURE: [Cotton, Silk, Leather, Denim, Wool, Velvet]

    Respond ONLY with this JSON format:
    {{
        "description": "...", 
        "tags": ["tag1", "tag2"],
        "style": "...",
        "color": "...",
        "texture": "..."
    }}
    """

    description = "Fashion Item"
    tags = []
    style = "Casual"
    color = "Black"
    texture = "Cotton"

    vision_models = ['llama3.2-vision', 'llava']
    for vision_model in vision_models:
        try:
            response = ollama.chat(
                model=vision_model,
                messages=[{'role': 'user', 'content': prompt, 'images': [image_bytes]}]
            )

            content = response['message']['content'].strip()
            json_match = re.search(r'\{.*\}', content, re.DOTALL)

            if json_match:
                data = json.loads(json_match.group(0))
                description = data.get("description", f"A nice {detected_category.lower()}")
                tags = data.get("tags", [])
                style = data.get("style", "Casual")
                color = data.get("color", "Black")
                texture = data.get("texture", "Cotton")
            break
        except Exception as e:
            print(f" Error Llama Vision ({vision_model}): {e}")
            if vision_model == vision_models[-1]:
                print(" All vision models failed. Using defaults.")

    return {
        "category": detected_category,
        "description": description,
        "tags": tags,
        "style": style,
        "color": color,
        "texture": texture,
        "ai_confidence": confidence
    }


def analyze_outfit_for_perfume(image_bytes: bytes) -> dict:
    print("Llama Vision:Looking for perfume style...")

    prompt = """
    Analyze this outfit to recommend a perfume.
    Identify 3 attributes strictly from these lists:
    1. STYLE: [Casual, Elegant, Sport, Bohemian, Business, Streetwear, Evening]
    2. COLOR: [Red, Blue, Black, White, Green, Yellow, Pink, Beige]
    3. TEXTURE: [Cotton, Silk, Leather, Denim, Wool, Velvet]
    
    Respond ONLY with this JSON:
    {"style": "...", "color": "...", "texture": "..."}
    """

    vision_models = ['llama3.2-vision', 'llava']
    for vision_model in vision_models:
        try:
            response = ollama.chat(
                model=vision_model,
                messages=[{'role': 'user', 'content': prompt, 'images': [image_bytes]}]
            )
            content = response['message']['content']
            json_match = re.search(r'\{.*\}', content, re.DOTALL)

            if json_match:
                data = json.loads(json_match.group(0))
                return {
                    "style": data.get("style", "Casual"),
                    "color": data.get("color", "Black"),
                    "texture": data.get("texture", "Cotton")
                }
            break
        except Exception as e:
            print(f" Error Vision (Perfume) ({vision_model}): {e}")

    return {"style": "Casual", "color": "Blue", "texture": "Cotton"}