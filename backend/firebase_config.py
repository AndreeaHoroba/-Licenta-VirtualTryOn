import firebase_admin
from firebase_admin import credentials, firestore, storage
from datetime import datetime
from uuid import uuid4
import os
from dotenv import load_dotenv

load_dotenv()

# ==========================================
# 1. CONFIGURARE
# ==========================================
CRED_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH", "serviceAccountKey.json")
BUCKET_NAME = os.getenv("FIREBASE_BUCKET", "licenta-app-d0f2c.firebasestorage.app")

# ==========================================
# 2. INITIALIZARE
# ==========================================
if not firebase_admin._apps:
    try:
        if not os.path.exists(CRED_PATH):
            print(f"❌ EROARE CRITICĂ: Nu găsesc fișierul {CRED_PATH}!")
        else:
            cred = credentials.Certificate(CRED_PATH)
            firebase_admin.initialize_app(cred, {
                'storageBucket': BUCKET_NAME
            })
            print("✅ Firebase conectat cu succes!")
    except Exception as e:
        print(f"❌ Eroare la inițializare Firebase: {e}")

# Instanțe globale
db = firestore.client()
bucket = storage.bucket()

# ==========================================
# 3. FUNCȚII UTILITARE
# ==========================================

async def save_avatar_to_firebase(user_id: str, image_bytes: bytes) -> str:
    """ Salvează silueta utilizatorului (Avatar). """
    try:
        filename = f"avatar_{uuid4()}.png"
        storage_path = f"users/{user_id}/avatar/{filename}"

        # 1. Upload Imagine
        blob = bucket.blob(storage_path)
        blob.upload_from_string(image_bytes, content_type='image/png')
        blob.make_public()
        image_url = blob.public_url

        # 2. Salvare Metadata în Firestore
        doc_ref = db.collection('users').document(user_id)

        doc_ref.set({
            'image_url': image_url,
            'current_avatar_path': storage_path,
            'last_updated': datetime.now()
        }, merge=True)
        
        # Salvăm și în colecția 'wardrobe' ca să apară în istoric
        wardrobe_ref = db.collection('users').document(user_id).collection('wardrobe').document()
        wardrobe_ref.set({
            'image_url': image_url,
            'category': 'BODY',
            'name': 'My Avatar',
            'created_at': datetime.now(),
            'tags': ['avatar']
        })
        
        return image_url

    except Exception as e:
        print(f"❌ Eroare salvare avatar: {e}")
        raise e

async def save_clothing_to_firebase(user_id: str, image_bytes: bytes, category: str, details: dict = None) -> str:
    """ Salvează haina și link-ul ei. """
    try:
        filename = f"{uuid4()}.png"
        storage_path = f"users/{user_id}/{category}/{filename}"
        
        # 1. Upload Imagine
        blob = bucket.blob(storage_path)
        blob.upload_from_string(image_bytes, content_type='image/png')
        blob.make_public()
        image_url = blob.public_url

        # 2. Pregătim datele
        if details is None: details = {}
        
        item_name = details.get('description', f"{category} Item")
        tags = details.get('tags', [])

        doc_data = {
            'image_url': image_url,      # <--- AICI ESTE CHEIA IMPORTANTA
            'category': category,
            'storage_path': storage_path,
            'created_at': datetime.now(),
            'name': item_name,
            'tags': tags,
            'ai_generated': True
        }
        
        # 3. Salvare în Firestore
        doc_ref = db.collection('users').document(user_id).collection('wardrobe').document()
        doc_ref.set(doc_data)
        
        print(f"💾 Haina salvată cu URL: {image_url}")
        return image_url

    except Exception as e:
        print(f"❌ Eroare salvare haină: {e}")
        raise e

async def get_user_wardrobe(user_id: str) -> list:
    """
    Descarcă lista de haine.
    """
    try:
        # Citim colecția 'wardrobe', ordonată după dată (cele noi primele)
        # Notă: Dacă nu ai index creat, poți scoate .order_by(...), dar e recomandat
        docs = db.collection('users').document(user_id).collection('wardrobe')\
                 .order_by('created_at', direction=firestore.Query.DESCENDING).stream()
        
        wardrobe = []
        for doc in docs:
            data = doc.to_dict()
            
            # --- FIX-UL ESTE AICI ---
            # Nu mai construim manual un dicționar care exclude URL-ul.
            # Luăm TOATE datele și ne asigurăm că image_url există.
            
            item = data # Luăm tot obiectul
            item['firebase_id'] = doc.id # Păstrăm și ID-ul documentului
            
            # Debugging în consolă ca să vezi ce se întâmplă
            # print(f"Item încărcat: {item.get('name')} -> {item.get('image_url')}")
            
            wardrobe.append(item)
            
        print(f"👗 S-au găsit {len(wardrobe)} iteme pentru userul {user_id}")
        return wardrobe
    except Exception as e:
        print(f"❌ Eroare citire garderobă: {e}")
        # Dacă crapă la sortare (lipsește index), încercăm fără sortare
        try:
            docs = db.collection('users').document(user_id).collection('wardrobe').stream()
            wardrobe = [d.to_dict() for d in docs]
            return wardrobe
        except:
            return []

async def save_outfit_to_firebase(user_id: str, image_bytes: bytes) -> str:
    """ Salvează outfit-ul final generat (User + Haine). """
    try:
        # Generăm un nume unic
        filename = f"outfit_{uuid4()}.png"
        # Calea în Storage
        storage_path = f"users/{user_id}/saved_outfits/{filename}"
        
        # 1. Upload în Storage
        blob = bucket.blob(storage_path)
        blob.upload_from_string(image_bytes, content_type='image/png')
        blob.make_public()
        image_url = blob.public_url
        
        # 2. Salvare referință în Firestore
        db.collection('users').document(user_id).collection('saved_outfits').add({
            'image_url': image_url,
            'storage_path': storage_path,
            'created_at': datetime.now(),
            'name': f"Outfit {datetime.now().strftime('%Y-%m-%d %H:%M')}"
        })
        
        print(f"💾 Outfit salvat: {image_url}")
        return image_url

    except Exception as e:
        print(f"❌ Eroare salvare outfit: {e}")
        raise e
    
async def delete_clothing_from_firebase(user_id: str, garment_id: str):
    """
    Șterge haina complet din Firestore și din Storage.
    """
    try:
        # 1. Obținem documentul din Firestore pentru a afla calea exactă a imaginii în Storage
        doc_ref = db.collection('users').document(user_id).collection('wardrobe').document(garment_id)
        doc = doc_ref.get()

        if not doc.exists:
            print(f"⚠️ Documentul {garment_id} nu există în Firestore.")
            return False

        data = doc.to_dict()
        storage_path = data.get('storage_path') # Luăm calea salvată la upload

        # 2. Ștergem din Storage
        if storage_path:
            blob = bucket.blob(storage_path)
            if blob.exists():
                blob.delete()
                print(f"✅ Imagine ștearsă din Storage: {storage_path}")

        # 3. Ștergem documentul din Firestore
        doc_ref.delete()
        print(f"✅ Document Firestore șters: {garment_id}")
        
        return True
    except Exception as e:
        print(f"❌ Eroare la ștergere Firebase: {e}")
        return False