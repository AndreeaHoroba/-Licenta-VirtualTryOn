import requests
import asyncio
import os
from dotenv import load_dotenv

load_dotenv()
REMOVE_BG_API_KEY = os.getenv("REMOVE_BG_API_KEY")

async def segment_clothing_ai(image_bytes: bytes) -> bytes:
    """
    Trimite imaginea către API-ul remove.bg și returnează PNG-ul transparent.
    """
    
    api_url = "https://api.remove.bg/v1.0/removebg"
    
    try:
        await asyncio.sleep(0.1)

        response = requests.post(
            api_url,
            files={'image_file': image_bytes},
            data={'size': 'auto'},
            headers={'X-Api-Key': REMOVE_BG_API_KEY},
        )

        if response.status_code == 200:
            return response.content
        else:
            print(f"Error API remove.bg: {response.status_code} - {response.text}")
            raise Exception(f"External error: {response.status_code}")

    except Exception as e:
        print(f"Error at API extern call{e}")
        raise e