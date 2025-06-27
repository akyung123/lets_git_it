# main.py

# Create a fastAPI "app" instance
import pathlib
from dotenv import load_dotenv
from fastapi import FastAPI, UploadFile, File, HTTPException
import os
import google.generativeai as genai
from google.cloud.speech_v2 import SpeechClient
from google.cloud.speech_v2.types import RecognizeRequest
import firebase_admin
from firebase_admin import credentials, firestore, messaging
import json
from fastapi.concurrency import run_in_threadpool

import shutil
import tempfile

load_dotenv()

app = FastAPI(title="Elderly Care App Backend")

# IMPORTANT: Configure your credentials
# This code assumes that the json file exists within in the project directory.

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise RuntimeError("GEMINI_API_KEY is not set in env")

genai.configure(api_key=GEMINI_API_KEY)

try:
    key_filename = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "")
    print(f"--- DIAGNOSTIC: Attempting to load credentials from filename: '{key_filename}' ---")
    
    BASE_DIR = pathlib.Path(__file__).resolve().parent
    CREDENTIALS_PATH = BASE_DIR / key_filename
    
    if not CREDENTIALS_PATH.exists():
        raise RuntimeError(f"Credential file '{key_filename}' not found at calculated path: {CREDENTIALS_PATH}")
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = str(CREDENTIALS_PATH)
    
    with open(CREDENTIALS_PATH, 'r') as f:
        GOOGLE_PROJECT_ID = json.load(f).get("project_id")
    if not GOOGLE_PROJECT_ID:
        raise RuntimeError("Could not determine Google Cloud Project ID from credentials")

    cred =  credentials.Certificate(str(CREDENTIALS_PATH))
    
    # Initialize with the Project ID for robustness
    firebase_admin.initialize_app(cred, {
        'projectId': GOOGLE_PROJECT_ID,
    })
    
    db = firestore.client()

    print("Firebase Admin SDK initialized successfully.")

except Exception as e:
    print(f"Error initializing Firebase Admin SDK: {e}")
    db = None
    GOOGLE_PROJECT_ID = None

def calculate_request_points(task_info: dict) -> int:
    """
    Calculates the points rewarded based on the context behind the request.
    """
    points = 10
    if task_info.get("transportation_needed"):
        points += 5
    return points

@app.post("/request/voice")
async def process_voice_request(
    user_id: str,
    audio_file: UploadFile = File(...)
):
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
            shutil.copyfileobj(audio_file.file, tmp)
            tmp_path = tmp.name
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to process uploaded file: {e}")
    finally:
        await audio_file.close()

    try:
        with open(tmp_path, 'rb') as f:
            content = f.read()

        if not content:
            raise HTTPException(status_code=400, detail="Received an empty audio file.")

        client = SpeechClient()
        # Using the default global recognizer which worked on your original project
        recognizer_name = f"projects/{GOOGLE_PROJECT_ID}/locations/global/recognizers/_"

        # Using the final, correct explicit config for the v2 API
        config = {
            "explicit_decoding_config": {
                "encoding": "LINEAR16",
                "sample_rate_hertz": 16000,
                "audio_channel_count": 1,
            },
            "language_codes": ["ko-KR"],  # Set back to Korean for your app
            "model": "latest_short",
        }

        request = RecognizeRequest(
            recognizer=recognizer_name, 
            config=config, 
            content=content,
        )

        response = client.recognize(request=request)
        
        if not response.results:
            raise HTTPException(status_code=400, detail="Google transcribed nothing. The audio may be silent or unclear.")
            
        transcribed_text = response.results[0].alternatives[0].transcript
        print(f"Transcribed Text: {transcribed_text}")

    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred during Speech-to-Text: {str(e)}")
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)


    # Extract information via Gemini
    try:
        prompt = f"""
        Analyze the following request from an elderly person and extract the key information.
        The user making the request is likely in Rural South Korea.
        Respond ONLY with a valid JSON object with the following keys: "time", "locationFrom", "locationTo", "transportation_needed", "task_description".
        If a value is not mentioned, set it to null.

        Request: "{transcribed_text}"
        """
        # Using the corrected model name and function call
        model = genai.GenerativeModel('gemini-1.5-flash-latest')
        gemini_response = await model.generate_content_async(prompt)

        cleaned_response_text = gemini_response.text.strip().lstrip("```json").rstrip("```")
        extracted_info = json.loads(cleaned_response_text)
        print(f"Gemini Extracted Info: {extracted_info}")

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gemini analysis failed: {str(e)}")
    
    if not db:
        raise HTTPException(status_code=500, detail="Firestore client not available.")
    
    # Point calculation and Request saved in DB
    try:
        points = calculate_request_points(extracted_info)

        request_data = {
            "requesterId": user_id,
            "status": "pending",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "transcribedText": transcribed_text,
            "taskDetails": extracted_info,
            "points": points,
            "responderId": None,
            "reviewId": None,
        }
        request_collection = db.collection('requests')
        new_request_ref = request_collection.document()
        await run_in_threadpool(new_request_ref.set, request_data)

        request_id = new_request_ref.id
        print(f"Request {request_id} saved to Firestore.")
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Firestore operation failed: {str(e)}")
    
    # FCM Notification Module
    try:
        volunteers_ref = db.collection('users').where('role', '==', 'volunteer').stream()
        registration_tokens = []
        for volunteer in volunteers_ref:
            volunteer_data = volunteer.to_dict()
            if volunteer_data.get('fcmToken'):
                registration_tokens.append(volunteer_data['fcmToken'])
        if registration_tokens:
            message = messaging.MulticastMessage(
                notification=messaging.Notification(
                    title="New Help Request!",
                    body=f"A new request is available: {transcribed_text[:50]}..."
                ),
                data={
                    'requestId': request_id,
                    'click_action': 'FLUTTER_NOTIFICATION_CLICK'
                },
                tokens=registration_tokens,
            )
            response = messaging.send_multicast(message)
            print(f'{response.success_count} messages were sent successfully')
    
    except Exception as e:
        print(f"An error occurred sending FCM notifications: {str(e)}")

    return {
        "status": "success",
        "request_id": request_id,
        "message": "Request processed, saved, and notifications sent."
    }