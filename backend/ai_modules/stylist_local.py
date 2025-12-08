import ollama


def ask_local_stylist(user_question: str, wardrobe_data: list, weather_context: str = "Unknown weather",
                      current_outfit: str = "Nothing selected") -> str:
    """
    Stylist V4 (Llama 3.1): Knows the weather forecast, what the user is wearing on the screen, and applies strict fashion logic.
    """

    inventory = {
        "TOPS": [],
        "BOTTOMS": [],
        "DRESSES": [],
        "SHOES": [],
        "OUTERWEAR": [],
        "OTHERS": []
    }

    wardrobe_text = ""
    if not wardrobe_data:
        wardrobe_text = "(The wardrobe is empty)"
    else:
        for item in wardrobe_data:
            name = item.get('name', 'Unknown item')
            desc_val = item.get('description', '')
            if len(desc_val) > len(name):
                name = desc_val

            raw_cat = item.get('category', 'OTHER').upper()

            target_cat = "OTHERS"
            if raw_cat in ['TOP', 'T-SHIRT', 'SHIRT', 'BLOUSE', 'HOODIE']:
                target_cat = "TOPS"
            elif raw_cat in ['PANTS', 'JEANS', 'SHORTS', 'SKIRT', 'TROUSERS']:
                target_cat = "BOTTOMS"
            elif raw_cat in ['DRESS', 'GOWN']:
                target_cat = "DRESSES"
            elif raw_cat in ['SHOES', 'SNEAKERS', 'BOOTS', 'HEELS']:
                target_cat = "SHOES"
            elif raw_cat in ['JACKET', 'COAT', 'BLAZER', 'OUTERWEAR']:
                target_cat = "OUTERWEAR"

            details = []
            if 'color' in item: details.append(item['color'])
            if 'style' in item: details.append(item['style'])

            desc_str = f"- {name}"
            if details:
                desc_str += f" [{', '.join(details)}]"

            inventory[target_cat].append(desc_str)

        for cat, items in inventory.items():
            if items:
                wardrobe_text += f"\n CATEGORY {cat}:\n" + "\n".join(items)

    prompt = f"""
    You are an elite AI Personal Stylist. You answer ONLY in ENGLISH.

     CURRENT WEATHER AND FORECAST:
    {weather_context}
    (Rule: If the user does not specify a particular day in the question, STRICTLY refer to TODAY / the first day in the list. Do not talk about tomorrow unless asked).

     WHAT THE CLIENT IS WEARING NOW (On screen):
    {current_outfit}

     AVAILABLE WARDROBE (Sorted by categories):
    {wardrobe_text}

     CLIENT'S QUESTION: "{user_question}"

     YOUR STYLING ALGORITHM (Follow steps 1-3 in order, with maximum strictness):

    STEP 1: CORE ANALYSIS (What essential piece is missing?)
    - Look closely at "WHAT THE CLIENT IS WEARING NOW". 
    - If the client is ONLY wearing a Bottom (e.g. Pants, Skirt, Jeans), their upper body is bare. You MUST recommend a TOP (T-shirt, Shirt, Sweater). IT IS STRICTLY FORBIDDEN to recommend a DRESS over pants!
    - If they are ONLY wearing a Top, you MUST recommend a BOTTOM (Pants/Skirt).
    - If they are wearing a Dress, the core is complete. Do not add tops or pants.

    STEP 2: PIECE SELECTION (From the Wardrobe or Imagination)
    - Search for the missing piece (established in Step 1) in the "AVAILABLE WARDROBE". 
    - If you find a suitable garment there, use it. 
    - If you DO NOT have anything suitable in the wardrobe (or the wardrobe is empty), IT IS PERFECTLY FINE TO INVENT. Theoretically recommend what they should buy or wear (e.g.: "You don't have a t-shirt in your wardrobe, so I suggest adding a simple white cotton top..."). Do not force wrong clothes (like the dress) just because they are in the closet!

    STEP 3: WEATHER AND ACCESSORIES
    - Adapt the outfit to the identified weather. If it is raining/cold, add a Jacket (Outerwear). If it is warm, leave the outfit simple. Also choose a logical pair of footwear.

    RESPONSE FORMAT (Be brief, elegant, and to the point):
    -  **Missing Piece (Outfit Completion):** [What TOP or BOTTOM did you choose to cover the body? Mention it here, from the wardrobe or invented by you]
    - ️ **Weather Adaptation:** [Explain the connection to the weather for today, or the requested day]
    -  **Accessories and Footwear:** [What shoes and potential jacket would fit]
    -  **Style Logic:** [Why these colors/textures look good together]
    """

    print(" Llama 3.1 is thinking about the complex context (Temp: 0.2)...")

    try:
        response = ollama.chat(
            model='llama3.1',
            messages=[{'role': 'user', 'content': prompt}],
            options={'temperature': 0.2}
        )
        return response['message']['content']

    except Exception as e:
        print(f" Ollama Error: {e}")
        return "Error processing the response. Please check if Ollama is running in the background."