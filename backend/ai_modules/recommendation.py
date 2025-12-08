import pickle
import pandas as pd
import os
import random

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_PATH = os.path.join(BASE_DIR, 'data', 'perfume_model.pkl')
DB_PATH = os.path.join(BASE_DIR, 'data', 'perfumes.csv')

print(" Loading scent perfume model...")
model = None
perfumes_db = None

try:
    if os.path.exists(MODEL_PATH) and os.path.exists(DB_PATH):
        # A. Load the ML Model
        with open(MODEL_PATH, 'rb') as f:
            model = pickle.load(f)

        # B. Load the Database
        perfumes_db = pd.read_csv(DB_PATH).fillna("")

        print("Scent-AI  system is active!")
    else:
        print(f"no folder found - 'data'.")
except Exception as e:
    print(f" Error at loading models  {e}")


def generate_smart_reason(style, color, texture, family, perfume_name):
    """
    Builds a dynamic explanation that looks like it was written by a stylist.
    """
    # 1. Style-based introduction
    intro = ""
    if style in ['Elegant', 'Evening', 'Business']:
        intro = f"For an {style} outfit, which denotes refinement, "
    elif style in ['Sport', 'Streetwear', 'Casual']:
        intro = f"For a relaxed {style} look, "
    elif style in ['Bohemian', 'Grunge']:
        intro = f"The {style} style calls for something unconventional, so "
    else:
        intro = f"Given the {style} style, "

    # 2. Connection with Olfactory Family and Texture
    middle = ""
    if family in ['Floral', 'Oriental']:
        if texture in ['Silk', 'Velvet', 'Leather']:
            middle = f"we chose the {family} family to complement the precious {texture} texture. "
        else:
            middle = f"the {family} notes add a touch of elegance. "
    elif family in ['Fresh', 'Citrus', 'Aquatic']:
        middle = f"the {family} family is ideal for maintaining a fresh aura. "
    elif family in ['Woody', 'Spicy']:
        middle = f"we opted for the {family} family, which offers depth and mystery. "
    else:
        middle = f"the {family} family perfectly balances the outfit. "

    # 3. Color-related conclusion
    outro = f"More specific, the {perfume_name} perfume subtly complements the {color} shades."

    return intro + middle + outro


def recommend_perfume(style: str, color: str, texture: str) -> dict:
    """
    Uses the ML Model for prediction + NLG Logic for explanation.
    """
    if model is None or perfumes_db is None:
        return {
            "error": "The recommendation system is currently unavailable.",
            "recommendation": {"name": "Unknown", "brand": "-", "reason": "Model not loaded."}
        }

    try:
        input_data = pd.DataFrame([[style, color, texture]],
                                  columns=['Style', 'Color', 'Texture'])

        predicted_family = model.predict(input_data)[0]
        print(f"👃 AI Prediction: {style}/{color}/{texture} -> {predicted_family}")

        matches = perfumes_db[perfumes_db['Family'] == predicted_family]

        if matches.empty:
            matches = perfumes_db

        selection = matches.sample(1).iloc[0]
        p_name = str(selection['Name'])
        p_brand = str(selection['Brand'])

        smart_reason = generate_smart_reason(style, color, texture, predicted_family, p_name)

        return {
            "status": "success",
            "outfit_analysis": {
                "style": style,
                "color": color,
                "texture": texture,
                "predicted_scent_family": predicted_family
            },
            "recommendation": {
                "name": p_name,
                "brand": p_brand,
                "notes": str(selection.get('Notes', 'N/A')),
                "description": str(selection.get('Description', '')),
                "reason": smart_reason
            }
        }

    except Exception as e:
        print(f" Recommendation error: {e}")
        return {"error": str(e)}