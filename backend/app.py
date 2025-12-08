from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response, JSONResponse
from typing import Dict, Any
import base64
import requests
import os
from dotenv import load_dotenv

load_dotenv()

# Import ai_modules
from ai_modules.segmentation import segment_and_pose
from ai_modules.clothing_segmentation import segment_clothing_ai
from ai_modules.validator import validate_image_quality
from ai_modules.tagging import auto_tag_clothing
from ai_modules.stylist_local import ask_local_stylist
from ai_modules.recommendation import recommend_perfume
from ai_modules.tagging import analyze_outfit_for_perfume
from ai_modules.dress_splitter import split_dress_intelligently
from ai_modules.tryon import apply_try_on

# Import Firebase
from firebase_config import (
    save_avatar_to_firebase, 
    save_clothing_to_firebase, 
    get_user_wardrobe, 
    save_outfit_to_firebase,
    delete_clothing_from_firebase
)
from PIL import Image, ImageOps
import io

FIREBASE_API_KEY = os.getenv("FIREBASE_API_KEY")


def fix_image_orientation(image_bytes):
    image = Image.open(io.BytesIO(image_bytes))
    image = ImageOps.exif_transpose(image)

    buffer = io.BytesIO()
    if image.mode in ("RGBA", "P"):
        image.save(buffer, format="PNG")
    else:
        image.save(buffer, format="JPEG")

    return buffer.getvalue()

# Initializare aplicatie
app = FastAPI(
    title="Virtual Try-On & AI Stylist API",
    description="Backend complete"
)

# Configurare CORS
origins = ["*"] 
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==========================================
# 1. RUTA DE TEST
# ==========================================
@app.get("/")
def read_root():
    return {"status": "ok", "message": "Virtual Try-On : active"}

# ==========================================
# 1.1 RUTE AUTENTIFICARE
# ==========================================

@app.post("/auth/signup")
async def signup(email: str = Form(...), password: str = Form(...)):
    """Crete new acc"""
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={FIREBASE_API_KEY}"
    payload = {
        "email": email,
        "password": password,
        "returnSecureToken": True
    }
    
    try:
        resp = requests.post(url, json=payload)
        data = resp.json()
        
        if resp.status_code == 200:
            return {
                "status": "success", 
                "email": data['email'], 
                "user_id": data['localId'],
                "token": data['idToken']
            }
        else:
            msg = data.get('error', {}).get('message', 'Signup failed')
            return JSONResponse(status_code=400, content={"message": msg})
            
    except Exception as e:
        return JSONResponse(status_code=500, content={"message": f"Server error: {str(e)}"})

@app.post("/auth/login")
async def login(email: str = Form(...), password: str = Form(...)):
    """Log in"""
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={FIREBASE_API_KEY}"
    payload = {
        "email": email,
        "password": password,
        "returnSecureToken": True
    }
    
    try:
        resp = requests.post(url, json=payload)
        data = resp.json()
        
        if resp.status_code == 200:
            return {
                "status": "success", 
                "email": data['email'], 
                "user_id": data['localId'], 
                "token": data['idToken']
            }
        else:
            msg = data.get('error', {}).get('message', 'Login failed')
            return JSONResponse(status_code=400, content={"message": msg})
            
    except Exception as e:
        return JSONResponse(status_code=500, content={"message": f"Server error: {str(e)}"})

# ==========================================
# 2. PROCESARE CORP (Avatar)
# ==========================================
@app.post("/process-body/", response_model=Dict[str, Any])
async def process_user_body(
        user_id: str = Form(...),
        file: UploadFile = File(...)
):
    try:
        image_bytes = await file.read()

        image_bytes = fix_image_orientation(image_bytes)

        validation = validate_image_quality(image_bytes)
        if not validation["valid"]:
            return JSONResponse(status_code=400, content={"message": validation["error"]})


        segmented_png_bytes = segment_and_pose(image_bytes)

        avatar_url = await save_avatar_to_firebase(user_id, segmented_png_bytes)

        base64_encoded_image = base64.b64encode(segmented_png_bytes).decode('utf-8')

        return {
            "status": "success",
            "base64_image_png": base64_encoded_image,
            "image_url": avatar_url
        }
    except Exception as e:
        print(f" Error processing body {e}")
        return JSONResponse(status_code=500, content={"message": str(e)})


# ==========================================
# 3. SEGMENTARE HAINE + AUTO-TAGGING + PARFUM CACHE
# ==========================================
@app.post("/segment-clothing/")
async def segment_clothing(
    user_id: str = Form(..., description="ID os user"),
    file: UploadFile = File(..., description="Raw image of piece of clothing")
):
    try:
        clothing_bytes = await file.read()

        # 1. SEGMENTARE (rembg)
        print(" Removing background..")
        segmented_png_bytes = await segment_clothing_ai(clothing_bytes)

        # 2.A. YOLO + Llama Vision
        clothing_details = auto_tag_clothing(segmented_png_bytes)

        detected_category = clothing_details['category']

        # 2.B. ANALIZA SEMANTICA

        print("Using perfume attributes..")

        perfume_traits = {
            "style": clothing_details.get("style", "Casual"),
            "color": clothing_details.get("color", "Black"),
            "texture": clothing_details.get("texture", "Cotton")
        }

        full_metadata = {
            **clothing_details,
        }

        # 3. SALVARE (Firebase)
        image_url = await save_clothing_to_firebase(
            user_id, 
            segmented_png_bytes, 
            detected_category,
            full_metadata
        )

        # 4. RESPONSES
        base64_image = base64.b64encode(segmented_png_bytes).decode('utf-8')

        return {
            "status": "success",
            "category": detected_category,
            "description": clothing_details['description'],
            "perfume_attributes": perfume_traits,
            "image_url": image_url,
            "base64_preview": base64_image
        }

    except Exception as e:
        print(f" Error processing clothes.. {e}")
        return JSONResponse(status_code=500, content={"message": str(e)})

@app.delete("/delete-garment/{user_id}/{garment_id}")
async def delete_garment(user_id: str, garment_id: str):
    success = await delete_clothing_from_firebase(user_id, garment_id)
    
    if success:
        return {"status": "success", "message": "Piece of clothing deleted."}
    else:
        return JSONResponse(
            status_code=500, 
            content={"message": "Error deleting clothing."}
        )


@app.post("/try-on-outfit/")
async def try_on_outfit(
        body_image: UploadFile = File(...),
        top_image: UploadFile = File(None),
        bottom_image: UploadFile = File(None),
        dress_image: UploadFile = File(None),
):
    try:
        print(" Request for Try On Outfit..")
        body_raw = await body_image.read()
        current_body_bytes = fix_image_orientation(body_raw)

        # CAZUL 1: UTILIZATORUL A TRIMIS O ROCHIE (DRESS)
        if dress_image:
            print("Processing dress..")
            dress_raw = await dress_image.read()
            dress_bytes = fix_image_orientation(dress_raw)

            top_part, bottom_part = split_dress_intelligently(dress_bytes)

            if top_part and bottom_part:
                print("Dress cut. Applying Top...")
                current_body_bytes = apply_try_on(current_body_bytes, top_part, "TOP")

                print("Applying Bottom...")
                current_body_bytes = apply_try_on(current_body_bytes, bottom_part, "PANTS")
            else:
                print("Cut failed... Sending as whole..")
                current_body_bytes = apply_try_on(current_body_bytes, dress_bytes, "DRESS")

        # CAZUL 2: UTILIZATORUL A TRIMIS TOP + PANTS
        else:
            if top_image:
                print("Applying top...")
                top_raw = await top_image.read()
                top_bytes = fix_image_orientation(top_raw)
                current_body_bytes = apply_try_on(current_body_bytes, top_bytes, "TOP")

            if bottom_image:
                print("Applying bottom...")
                bottom_raw = await bottom_image.read()
                bottom_bytes = fix_image_orientation(bottom_raw)
                current_body_bytes = apply_try_on(current_body_bytes, bottom_bytes, "PANTS")

        return Response(content=current_body_bytes, media_type="image/png")

    except Exception as e:
        print(f" Error Try-On Final: {e}")
        return JSONResponse(status_code=500, content={"message": str(e)})

# ==========================================
# 6. CHATBOT STILIST
# ==========================================
@app.post("/chat-stylist/")
async def chat_stylist(
        user_id: str = Form(...),
        question: str = Form(...),
        city: str = Form("Timisoara"),
        current_outfit: str = Form("Nothing selected")
):
    try:
        # 1. Luam garderoba utilizatorului
        wardrobe = await get_user_wardrobe(user_id)

        # 2. Luam contextul meteo de la Open-Meteo
        weather_context = ""
        try:
            # A. Coordonate oras
            geo_url = f"https://geocoding-api.open-meteo.com/v1/search?name={city}&count=1&language=en&format=json"
            geo_res = requests.get(geo_url).json()

            if geo_res.get('results'):
                lat = geo_res['results'][0]['latitude']
                lon = geo_res['results'][0]['longitude']

                # B. Luam prognoza pe 7 zile
                weather_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto"
                w_res = requests.get(weather_url).json()

                for i in range(len(w_res['daily']['time'])):
                    date = w_res['daily']['time'][i]
                    t_max = w_res['daily']['temperature_2m_max'][i]
                    t_min = w_res['daily']['temperature_2m_min'][i]
                    code = w_res['daily']['weather_code'][i]
                    desc = "Senin" if code <= 3 else "Ploaie/Noros"

                    weather_context += f"- Data: {date}, Temp: {t_min}°C - {t_max}°C, Condiții: {desc}\n"
            else:
                weather_context = "Couldn't find city..."
        except Exception as e:
            print(f"Error meteo {e}")
            weather_context = "Unavailable meteo information"

        # 3.Trimitem totul la Llama
        reply = ask_local_stylist(
            user_question=question,
            wardrobe_data=wardrobe,
            weather_context=weather_context,
            current_outfit=current_outfit
        )
        return {"reply": reply}

    except Exception as e:
        return JSONResponse(status_code=500, content={"message": str(e)})

# ==========================================
# 7. SALVARE OUTFIT
# ==========================================
@app.post("/save-outfit/")
async def save_outfit(user_id: str = Form(...), file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        url = await save_outfit_to_firebase(user_id, image_bytes)
        return {"status": "success", "image_url": url}
    except Exception as e:
        return JSONResponse(status_code=500, content={"message": str(e)})


# ==========================================
# 8. RUTA RECOMANDARE PARFUM
# ==========================================
@app.post("/recommend-perfume/")
async def recommend_scent_from_image(
    file: UploadFile = File(..., description="Update final image of the outfit..")
):
    """
    AUTOMATIZARE COMPLETĂ:
    1. Primește poza cu userul îmbrăcat.
    2. Llama Vision extrage Stilul, Culoarea și Textura.
    3. Modelul ML (Random Forest) prezice familia olfactivă.
    4. Returnează parfumul recomandat.
    """
    try:
        image_bytes = await file.read()

        # 1. Analiza Vizuala
        traits = analyze_outfit_for_perfume(image_bytes)
        
        print(f" Detected traits: {traits}")

        # 2. Recomandare ML
        result = recommend_perfume(
            style=traits['style'],
            color=traits['color'],
            texture=traits['texture']
        )
        
        return result

    except Exception as e:
        return JSONResponse(status_code=500, content={"message": str(e)})
    
    # ==========================================
# 9. RUTA GET USER DATA (Garderobă & Avatar)
# ==========================================
@app.post("/get-user-data/")
async def get_user_data(user_id: str = Form(...)):
    try:

        wardrobe_items = await get_user_wardrobe(user_id)

        return {
            "status": "success",
            "wardrobe": wardrobe_items
        }
    except Exception as e:
        return JSONResponse(status_code=500, content={"message": str(e)})
    
    # ==========================================
# 10. DATE METEO (VREME PE 7 ZILE)
# ==========================================

@app.get("/get-weather/")
async def get_weekly_weather(city: str = "Timisoara"):
    try:
        # 1. Aflam coordonatele orasului
        geo_url = f"https://geocoding-api.open-meteo.com/v1/search?name={city}&count=1&language=en&format=json"
        geo_res = requests.get(geo_url).json()
        
        if not geo_res.get('results'):
            return JSONResponse(status_code=400, content={"message": "City not found"})
            
        lat = geo_res['results'][0]['latitude']
        lon = geo_res['results'][0]['longitude']
        actual_city_name = geo_res['results'][0]['name']

        # 2. Cerem prognoza pe 7 zile
        weather_url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto"
        response = requests.get(weather_url)
        data = response.json()

        # 3. Mapam datele
        forecast_days = []
        for i in range(len(data['daily']['time'])):
            code = data['daily']['weather_code'][i]
            
            condition_text = "Senin"
            icon_url = "https://cdn.weatherapi.com/weather/64x64/day/113.png"
            
            if code == 0:
                condition_text = "Senin"
                icon_url = "https://cdn.weatherapi.com/weather/64x64/day/113.png"
            elif 1 <= code <= 3:
                condition_text = "Parțial Noros"
                icon_url = "https://cdn.weatherapi.com/weather/64x64/day/116.png"
            elif code >= 61:
                condition_text = "Ploaie"
                icon_url = "https://cdn.weatherapi.com/weather/64x64/day/302.png"
            elif code >= 45:
                condition_text = "Ceață"
                icon_url = "https://cdn.weatherapi.com/weather/64x64/day/143.png"

            forecast_days.append({
                "date": data['daily']['time'][i],
                "max_temp": data['daily']['temperature_2m_max'][i],
                "min_temp": data['daily']['temperature_2m_min'][i],
                "condition": condition_text,
                "icon": icon_url,
                "will_it_rain": 1 if code >= 61 else 0
            })
            
        return {
            "status": "success",
            "city": actual_city_name, 
            "forecast": forecast_days
        }

    except Exception as e:
        print(f"Eroare meteo: {e}")
        return JSONResponse(status_code=500, content={"message": f"Eroare internă meteo: {str(e)}"})

    # ==========================================
# 11. PLANIFICATOR OUTFIT-URI (CALENDAR)
# ==========================================


@app.post("/plan-outfit/")
async def plan_outfit_for_date(
        user_id: str = Form(...),
        date: str = Form(...),
        image_url: str = Form(...)
):
    try:
        from firebase_admin import firestore
        db = firestore.client()

        calendar_ref = db.collection('users').document(user_id).collection('planned_outfits').document(date)
        calendar_ref.set({
            "outfit_url": image_url,
            "date": date,
            "timestamp": firestore.SERVER_TIMESTAMP
        })
        print(f"Outfit saved for {date}")
        return JSONResponse(status_code=200,
                            content={"status": "success", "message": f"Outfit planned for {date}!"})
    except Exception as e:
        print(f" Error at planning outfit {e}")
        return JSONResponse(status_code=500, content={"message": str(e)})


@app.post("/get-planned-outfits/")
async def get_planned_outfits(user_id: str = Form(...)):
    try:
        from firebase_admin import firestore
        db = firestore.client()

        calendar_ref = db.collection('users').document(user_id).collection('planned_outfits')
        docs = calendar_ref.stream()

        planned_data = {}
        for doc in docs:
            data = doc.to_dict()
            url = data.get('outfit_url') or data.get('image_url')
            if url:
                planned_data[doc.id] = url

        print(f"Found {len(planned_data)} plans for user  {user_id}")
        return JSONResponse(status_code=200, content={
            "status": "success",
            "planned_outfits": planned_data
        })
    except Exception as e:
        print(f" Error reading calendar.. {e}")
        return JSONResponse(status_code=500, content={"message": str(e)})

# ============================================================
# 12. GENERARE AI + PROCESARE + SALVARE (FLUX COMPLET)
# ============================================================

import httpx

@app.post("/create-ai-garment/")
async def create_ai_garment(
        user_id: str = Form(...),
        description: str = Form(...)
):
    """
    AI Designer endpoint: Connects to Vast.ai GPU, processes the image, and saves to wardrobe.
    """
    print(f"New design requested by {user_id}: {description}")

    VAST_AI_URL = "http://188.36.196.221:5200/generate/"

    try:
        # 2. GENERATION (Using httpx for non-blocking async calls)
        print(" Sending request to RTX 4090 server...")
        payload = {"description": f"{description}, flat lay, white background"}

        async with httpx.AsyncClient() as client:
            response = await client.post(VAST_AI_URL, json=payload, timeout=120.0)

        if response.status_code != 200:
            return JSONResponse(status_code=500,
                                content={"message": "GPU Server did not respond. Check if the instance is running."})

        data = response.json()
        raw_image_bytes = base64.b64decode(data["image_base64"])

        # 3. BACKGROUND REMOVAL (Local - rembg / remove.bg)
        print(" Removing background...")
        try:
            segmented_png_bytes = await segment_clothing_ai(raw_image_bytes)
        except Exception as e:

            print(f" Couldn t cut background..({e}).Keeping original picture")
            segmented_png_bytes = raw_image_bytes

        # 4. AUTOMATIC TAGGING (Local - Llama/YOLO)
        print("🏷 Analyzing garment and categorizing...")
        tags = auto_tag_clothing(segmented_png_bytes)
        detected_category = tags.get('category', 'TOP')

        # 5. SAVE TO FIREBASE
        print(" Saving to Firebase Wardrobe...")
        image_url = await save_clothing_to_firebase(
            user_id,
            segmented_png_bytes,
            detected_category,
            tags
        )

        # 6. RESPONSE
        return {
            "status": "success",
            "category": detected_category,
            "image_url": image_url,
            "preview_base64": base64.b64encode(segmented_png_bytes).decode('utf-8')
        }

    except Exception as e:
        print(f" Creation flow error: {e}")
        return JSONResponse(status_code=500, content={"message": f"Design generation error: {str(e)}"})

# ==========================================
# 11.1 ȘTERGERE PLANIFICARE CALENDAR
# ==========================================
@app.delete("/delete-planned-outfit/{user_id}/{date}")
async def delete_planned_outfit(user_id: str, date: str):

    try:
        from firebase_admin import firestore
        db = firestore.client()

        db.collection('users').document(user_id).collection('planned_outfits').document(date).delete()

        return {"status": "success", "message": f"Planned outfit for {date} has been deleted"}
    except Exception as e:
        print(f" Error deleting from calendar.{e}")
        return JSONResponse(status_code=500, content={"message": str(e)})

if __name__ == "__main__":
        import uvicorn
        print(" Server starting at http://127.0.0.1:8000")
        uvicorn.run(app, host="127.0.0.1", port=8000)