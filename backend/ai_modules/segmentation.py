import mediapipe as mp
import numpy as np
from PIL import Image
from io import BytesIO

MP_SELFIE_SEGMENTATION = mp.solutions.selfie_segmentation


def segment_and_pose(image_bytes: bytes) -> bytes:
    """
    Realizeaza segmentarea corpului — returneaza PNG RGBA cu fundal transparent.
    """
    pil_image = Image.open(BytesIO(image_bytes)).convert("RGB")
    image = np.array(pil_image)
    image_h, image_w, _ = image.shape

    with MP_SELFIE_SEGMENTATION.SelfieSegmentation(model_selection=1) as selfie_segmentation:
        segment_results = selfie_segmentation.process(image)

    mask = segment_results.segmentation_mask
    binary_mask = (mask > 0.1).astype('uint8') * 255

    segmented_image = np.zeros((image_h, image_w, 4), dtype=np.uint8)
    segmented_image[:, :, :3] = image
    segmented_image[:, :, 3] = binary_mask

    pil_output = Image.fromarray(segmented_image, 'RGBA')
    byte_io = BytesIO()
    pil_output.save(byte_io, format='PNG')

    return byte_io.getvalue()