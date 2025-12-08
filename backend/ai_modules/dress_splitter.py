import io
from PIL import Image


def split_dress_intelligently(dress_bytes: bytes, split_ratio: float = 0.45, overlap_px: int = 25):
    """
    Splits a cropped dress into two parts (Top and Bottom/Skirt) with an overlapping area,
    in order to send them sequentially to the IDM-VTON model.
    """
    try:
        img = Image.open(io.BytesIO(dress_bytes)).convert("RGBA")

        alpha_channel = img.split()[-1]
        bbox = alpha_channel.getbbox()

        if not bbox:
            print("Error: The image appears to be completely empty or transparent.")
            return None, None

        img_cropped = img.crop(bbox)
        width, height = img_cropped.size

        cut_y = int(height * split_ratio)

        box_top = (0, 0, width, min(height, cut_y + overlap_px))
        box_bottom = (0, max(0, cut_y - overlap_px), width, height)

        top_part = img_cropped.crop(box_top)
        bottom_part = img_cropped.crop(box_bottom)

        top_buffer = io.BytesIO()
        top_part.save(top_buffer, format="PNG")

        bottom_buffer = io.BytesIO()
        bottom_part.save(bottom_buffer, format="PNG")

        print(
            f"Dress split successfully! Original size: {height}px -> Top: {box_top[3]}px, Bottom: {height - box_bottom[1]}px")

        return top_buffer.getvalue(), bottom_buffer.getvalue()

    except Exception as e:
        print(f"Fatal error while splitting the dress: {e}")
        return None, None