import pandas as pd
import random
import os

STYLES = ['Casual', 'Elegant', 'Sport', 'Bohemian', 'Business', 'Streetwear', 'Grunge', 'Evening']
COLORS = ['Red', 'Blue', 'Black', 'White', 'Pastel', 'Green', 'Yellow', 'Gold', 'Silver', 'Pink']
TEXTURES = ['Cotton', 'Silk', 'Leather', 'Denim', 'Wool', 'Velvet', 'Linen', 'Synthetics']

def get_scent_family(style, color, texture):
    # Reguli Specifice (Prioritate mare)
    if style == 'Sport': return 'Citrus'
    if texture == 'Leather' or style == 'Grunge': return 'Leather'
    if style == 'Evening' and color in ['Black', 'Gold']: return 'Oriental'
    if style == 'Bohemian': return 'Woody'
    if style == 'Streetwear': return 'Aromatic'
    
    # Reguli bazate pe Culoare
    if color == 'Blue' or color == 'White': return 'Aquatic'
    if color == 'Pink' or color == 'Pastel': return 'Fruity'
    if color == 'Red': return 'Spicy'
    if color == 'Green': return 'Chypre'
    
    # Reguli bazate pe Textură
    if texture == 'Silk': return 'Floral'
    if texture == 'Velvet': return 'Gourmand'
    if texture == 'Wool': return 'Woody'
    if texture == 'Linen': return 'Citrus'
    
    # Default
    return 'Floral'

print("Generating extended dataset..")
data_rows = []

for _ in range(5000):
    s = random.choice(STYLES)
    c = random.choice(COLORS)
    t = random.choice(TEXTURES)
    
    target_family = get_scent_family(s, c, t)
    
    data_rows.append({
        'Style': s,
        'Color': c,
        'Texture': t,
        'Recommended_Family': target_family
    })

output_path = '../data/training_dataset.csv'
os.makedirs(os.path.dirname(output_path), exist_ok=True)

df = pd.DataFrame(data_rows)
df.to_csv(output_path, index=False)

print(f"Success! {output_path} (5000 lines)")
print(df.sample(5))