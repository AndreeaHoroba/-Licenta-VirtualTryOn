# Virtual Try-On & AI Stylist — Aplicatie mobila

**Autor:** Horoba Andreea  
**Repository:** https://github.com/AndreeaHoroba/-Licenta-VirtualTryOn

---

## Descriere

Aplicatie mobila cross-platform (Android/iOS) pentru proba virtuala a hainelor cu ajutorul inteligentei artificiale. Utilizatorul isi creeaza un avatar din propria fotografie, isi construieste o garderoba digitala si poate vedea cum arata hainele pe corpul sau fara sa le probeze fizic. Aplicatia include un stilist AI (Llama 3.1), recomandare de parfumuri bazata pe Machine Learning si un planificator de outfit-uri cu prognoza meteo.

---

## Structura proiectului

```
Licenta-VirtualTryOn/
├── backend/          # Server Python (FastAPI)
│   ├── app.py        # Endpoint-urile principale
│   ├── ai_modules/   # Module AI (segmentare, try-on, tagging, stilist)
│   ├── models/       # Modele YOLO antrenate
│   ├── data/         # Date pentru recomandare parfumuri
│   └── cloud_gpu_service/  # Server Stable Diffusion (Vast.ai)
└── frontend/         # Aplicatie Flutter
    └── lib/          # Ecranele aplicatiei
```

---

## Pasi build Backend

### Cerinte
- Python 3.10+
- [Ollama](https://ollama.com) instalat si pornit

### Instalare

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# macOS/Linux
source venv/bin/activate

pip install -r requirements.txt
```

### Configurare

1. Copiaza fisierul de configurare:
```bash
cp .env.example .env
```

2. Completeaza `.env` cu valorile tale:
   - `FIREBASE_API_KEY` — din Firebase Console > Project Settings
   - `FIREBASE_CREDENTIALS_PATH` — calea catre `serviceAccountKey.json` (descarcabil din Firebase Console > Service Accounts)
   - `FIREBASE_BUCKET` — numele bucket-ului din Firebase Storage
   - `REMOVE_BG_API_KEY` — din [remove.bg](https://www.remove.bg/api)
   - `REPLICATE_API_TOKEN` — din [replicate.com](https://replicate.com/account/api-tokens)

3. Pune fisierul `serviceAccountKey.json` in folderul `backend/`

4. Descarca modelele Ollama necesare:
```bash
ollama pull llama3.1
ollama pull llava
```

---

## Pasi build Frontend

### Cerinte
- Flutter SDK 3.11+
- Android Studio sau Xcode (pentru emulator/device)

### Instalare

```bash
cd frontend
flutter pub get
```

### Configurare Firebase

Proiectul foloseste Firebase. Fisierele de configurare (`google-services.json` pentru Android, `GoogleService-Info.plist` pentru iOS) trebuie descarcate din Firebase Console si plasate in:
- Android: `frontend/android/app/google-services.json`
- iOS: `frontend/ios/Runner/GoogleService-Info.plist`

---

## Pornirea aplicatiei

### 1. Porneste Ollama
```bash
ollama serve
```

### 2. Porneste backend-ul
```bash
cd backend
venv\Scripts\activate   # Windows
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

### 3. Expune backend-ul pe internet (pentru acces de pe telefon)
```bash
ngrok http 8000
```

Copiaza URL-ul generat de ngrok si actualizeaza `backendUrl` in fisierele Flutter:
- `frontend/lib/home_screen.dart`
- `frontend/lib/wardrobe_screen.dart`
- `frontend/lib/calendar_screen.dart`

### 4. Porneste aplicatia Flutter
```bash
cd frontend
flutter run
```

---

## Tehnologii folosite

| Componenta | Tehnologie |
|---|---|
| Backend | Python, FastAPI, Uvicorn |
| Frontend | Flutter (Dart) |
| Autentificare & DB | Firebase Auth, Firestore, Storage |
| Segmentare corp | MediaPipe Selfie Segmentation |
| Segmentare haine | remove.bg API |
| Detectie obiecte | YOLOv8 (modele custom antrenate) |
| Virtual Try-On | Replicate — IDM-VTON |
| Stilist AI | Llama 3.1 via Ollama |
| Analiza vizuala | LLaVA via Ollama |
| Generare haine AI | Stable Diffusion v1.5 (Vast.ai GPU) |
| Recomandare parfumuri | Random Forest (scikit-learn) |
| Prognoza meteo | Open-Meteo API |
