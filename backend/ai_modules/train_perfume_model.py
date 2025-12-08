import pandas as pd
import pickle
import os
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import OneHotEncoder
from sklearn.pipeline import Pipeline

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATASET_PATH = os.path.join(BASE_DIR, 'data', 'training_dataset.csv')
MODEL_PATH = os.path.join(BASE_DIR, 'data', 'perfume_model.pkl')

print(f" Reading data from.. {DATASET_PATH}")

if not os.path.exists(DATASET_PATH):
    print(" Error: Cannot find training_dataset.csv.Run first generate_dataset.py!")
    exit()

df = pd.read_csv(DATASET_PATH)

X = df[['Style', 'Color', 'Texture']]
y = df['Recommended_Family']

#Construim Pipeline ul
model_pipeline = Pipeline([
    ('encoder', OneHotEncoder(handle_unknown='ignore')), 
    ('classifier', RandomForestClassifier(n_estimators=100)) 
])

#Antrenam modelul
print(" Started training model...")
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
model_pipeline.fit(X_train, y_train)

# Verificam cat de deștept e
accuracy = model_pipeline.score(X_test, y_test)
print(f" Model trained! Accuracy: {accuracy * 100:.2f}%")
from sklearn.metrics import classification_report, confusion_matrix
import seaborn as sns
import matplotlib.pyplot as plt

# 1. Obținem predicțiile pe setul de test
y_pred = model_pipeline.predict(X_test)

# 2. Printăm raportul de clasificare (conține Precision, Recall, F1-Score)
print("\n--- RAPORT DE CLASIFICARE ---")
print(classification_report(y_test, y_pred))

# 3. Opțional: Matricea de confuzie (comisia va fi impresionată)
cm = confusion_matrix(y_test, y_pred)
print("\nMatricea de confuzie:\n", cm)
# Save
with open(MODEL_PATH, 'wb') as f:
    pickle.dump(model_pipeline, f)
    
print(f" Model saved in {MODEL_PATH}")