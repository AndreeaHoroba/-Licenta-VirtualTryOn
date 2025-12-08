import cv2
import mediapipe as mp
import numpy as np

mp_pose = mp.solutions.pose
pose = mp_pose.Pose(
    static_image_mode=True, 
    model_complexity=1, 
    min_detection_confidence=0.5
)


def validate_image_quality(image_bytes: bytes) -> dict:
    """
    checks if there is a person in the photo.
    """

    try:
        nparr = np.frombuffer(image_bytes, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        if image is None:
            return {"valid": False, "error": "The file is not a valid image."}
    except Exception:
        return {"valid": False, "error": "Error processing the image."}


    # 3. Detectare Pose  om
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    results = pose.process(image_rgb)

    if not results.pose_landmarks:
        return {
            "valid": False,
            "error": "No person detected in the frame."
        }


    return {"valid": True, "error": None}