# AI-Powered Smart Wardrobe with Virtual Try-On

**Author:** Horoba Andreea  
**Repository:** https://github.com/AndreeaHoroba/-Licenta-VirtualTryOn

---

## About the project

This is a cross-platform mobile app (Android) built as a smart wardrobe assistant powered by AI. The user takes a photo of themselves, the app generates a body silhouette, and they can virtually try on clothes from their digital wardrobe to see how different outfits look without physically wearing them. The app also includes an AI stylist chatbot, a perfume recommendation engine based on Machine Learning, an AI garment generator using Stable Diffusion, and an outfit calendar with a 7-day weather forecast.

---

## Project structure

```
Licenta-VirtualTryOn/
├── backend/                    # Python REST API (FastAPI)
│   ├── app.py                  # Main endpoints
│   ├── ai_modules/             # AI components (segmentation, try-on, tagging, stylist)
│   ├── models/                 # Trained YOLO models
│   ├── data/                   # Perfume recommendation dataset & trained model
│   └── cloud_gpu_service/      # Stable Diffusion server (runs on Vast.ai GPU)
└── frontend/                   # Flutter mobile app
    └── lib/                    # Screens and UI logic
```

---

## Backend — build & installation

### Requirements

- Python 3.10 or newer
- [Ollama](https://ollama.com) installed and running

### Steps

```bash
cd backend

# Create a virtual environment
python -m venv venv

# Activate it
venv\Scripts\activate        # Windows
source venv/bin/activate     # macOS / Linux

# Install dependencies
pip install -r requirements.txt
```

### Configuration

1. Copy the environment file:
```bash
cp .env.example .env
```

2. Open `.env` and fill in your keys:
   - `FIREBASE_API_KEY` — found in Firebase Console > Project Settings
   - `FIREBASE_CREDENTIALS_PATH` — path to `serviceAccountKey.json` (download from Firebase Console > Service Accounts)
   - `FIREBASE_BUCKET` — your Firebase Storage bucket name
   - `REMOVE_BG_API_KEY` — get one at [remove.bg](https://www.remove.bg/api)
   - `REPLICATE_API_TOKEN` — get one at [replicate.com](https://replicate.com/account/api-tokens)

3. Place `serviceAccountKey.json` inside the `backend/` folder.

4. Pull the required AI models:
```bash
ollama pull llama3.1
ollama pull llava
```

---

## Frontend — build & installation

### Requirements

- Flutter SDK 3.11 or newer
- Android Studio (for Android) or Xcode (for iOS)

### Steps

```bash
cd frontend
flutter pub get
```

### Firebase setup

Download the Firebase config files from Firebase Console and place them here:
- Android: `frontend/android/app/google-services.json`
- iOS: `frontend/ios/Runner/GoogleService-Info.plist`

---

## Running the application

### 1. Start Ollama
```bash
ollama serve
```

### 2. Start the backend
```bash
cd backend
venv\Scripts\activate        # Windows
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

### 3. Expose the backend to the internet (needed for mobile access)
```bash
ngrok http 8000
```

Copy the ngrok URL and update `backendUrl` in these Flutter files:
- `frontend/lib/home_screen.dart`
- `frontend/lib/wardrobe_screen.dart`
- `frontend/lib/calendar_screen.dart`

### 4. Run the Flutter app
```bash
cd frontend
flutter run
```

---

## Tech stack

| Component | Technology |
|---|---|
| Backend | Python, FastAPI, Uvicorn |
| Frontend | Flutter (Dart) |
| Auth & Database | Firebase Auth, Firestore, Storage |
| Body segmentation | MediaPipe Selfie Segmentation |
| Clothing segmentation | remove.bg API |
| Object detection | YOLOv8 (custom trained models) |
| Virtual try-on | Replicate — IDM-VTON model |
| AI Stylist chatbot | Llama 3.1 via Ollama |
| Visual analysis | LLaVA via Ollama |
| AI garment generation | Stable Diffusion v1.5 (Vast.ai GPU) |
| Perfume recommendation | Random Forest (scikit-learn) |
| Weather forecast | Open-Meteo API |
