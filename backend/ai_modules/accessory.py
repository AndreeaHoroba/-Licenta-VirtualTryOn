import io
from PIL import Image
import rembg

def add_accessory_to_corner(base_bytes: bytes, acc_bytes: bytes) -> bytes:
    try:
        base_img = Image.open(io.BytesIO(base_bytes)).convert("RGBA")

        print("Cleaning accessory background image...")
        acc_bytes_clean = rembg.remove(acc_bytes)
        
        acc_img = Image.open(io.BytesIO(acc_bytes_clean)).convert("RGBA")

        # Calcul dimensiuni
        base_w, base_h = base_img.size
        acc_w_original, acc_h_original = acc_img.size

        # Redimensionare (35% din latimea pozei mari)
        acc_w_new = int(base_w * 0.35)
        raport = acc_w_new / acc_w_original
        acc_h_new = int(acc_h_original * raport)

        try:
            metoda_resize = Image.Resampling.LANCZOS
        except AttributeError:
            metoda_resize = Image.LANCZOS

        acc_img_resized = acc_img.resize((acc_w_new, acc_h_new), metoda_resize)

        #Pozitia în coltul din dreapta jos
        x_offset = base_w - acc_w_new - 20
        y_offset = base_h - acc_h_new - 20

        #  Lipim geanta decupata
        base_img.paste(acc_img_resized, (x_offset, y_offset), acc_img_resized)

        #  Save
        final_img = base_img.convert("RGB")
        buffer = io.BytesIO()
        final_img.save(buffer, format="PNG")
        
        return buffer.getvalue()

    except Exception as e:
        print(f"ERROR ACCESSORY {e}")
        return base_bytes