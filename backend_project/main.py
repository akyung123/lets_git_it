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
from datetime import datetime
from fastapi.middleware.cors import CORSMiddleware
import shutil
import tempfile

load_dotenv()

app = FastAPI(title="Elderly Care App Backend")

# --- CORS SET UP --- 

# This is the list of "origins" (domains) that are allowed to make requests.
# For development, "*" allows everything, which is the easiest setup.
# For production, you should restrict this to your Flutter app's actual domain.
origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"], # Allows all methods (POST, GET, etc.)
    allow_headers=["*"], # Allows all headers
)

# - END OF CORS SETUP -

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise RuntimeError("GEMINI_API_KEY is not set in env")

genai.configure(api_key=GEMINI_API_KEY)

try:
    # This code assumes that the json file exists within in the project directory.
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
        current_time = datetime.now()
        current_time_str = current_time.strftime("%Y년 %m월 %d일, %A, %p %I:%M")
        prompt = f"""
        다음은 어르신의 요청입니다. 핵심 정보를 분석해주세요.
        요청자는 대한민국의 농촌 지역, 특히 의성군 근처에 있을 가능성이 높습니다.
        현재 날짜는 "{current_time_str}"입니다. "내일"과 같은 상대적인 날짜를 파악하는 데 이 정보를 사용하세요.
        
        반드시 유효한 JSON 객체 형식으로만 응답해야 하며, 다음 키들을 포함해야 합니다: "time", "locationFrom", "locationTo", "method", "task_description".

        - "time" 키에는 예상되는 전체 날짜와 시간을 ISO 8601 형식(예: "2025-06-29T14:00:00")으로 제공해주세요.
        - "method" 키에는 사용자가 "차량"을 필요로 하는지 "걷기"(도보)으로 괜찮은지 판단하여 입력해주세요. 차를 태워달라는 요청이 있으면 "차량"로 간주합니다.
        - method, locationFrom, locationTo, task_description의 값은 한국어로 작성해주세요.
        - 언급되지 않은 값이 있다면, 그 값은 null로 설정해주세요.

        요청: "{transcribed_text}"
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
    
     # Point calculation and Request saved in DB using a Transaction
    try:
        # This is a special decorator that tells Firestore to run the function below as a single, atomic transaction.
        @firestore.transactional
        def create_new_request_in_transaction(transaction, request_data_to_save):
            counter_ref = db.collection('counters').document('request_counter')
            counter_snapshot = counter_ref.get(transaction=transaction)

            # 1. Get the last used ID from our counter document.
            last_id = counter_snapshot.get('lastId')
            new_id_num = last_id + 1

            # 2. Create the new, formatted document ID (e.g., "req011")
            # The :03d part ensures it's always padded with leading zeros to 3 digits.
            new_request_id_str = f"req{new_id_num:03d}"
            
            # 3. Create a reference to the new document in the 'requests' collection with our custom ID.
            new_request_ref = db.collection('requests').document(new_request_id_str)

            # 4. Save the new request data to that document.
            transaction.set(new_request_ref, request_data_to_save)

            # 5. Update the counter document with the new lastId.
            transaction.update(counter_ref, {'lastId': new_id_num})

            # Return the new custom ID so we can use it later.
            return new_request_id_str

        # First, prepare the data that needs to be saved.
        points = 10
        if extracted_info.get("method") == "vehicle":
            points += 5

        request_data = {
            "requesterId": user_id,
            "locationFrom": extracted_info.get("locationFrom"),
            "locationTo": extracted_info.get("locationTo"),
            "time": extracted_info.get("time"),
            "status": "waiting",
            "matchedVolunteerId": None,
            "method": extracted_info.get("method"),
            "createdAt": firestore.SERVER_TIMESTAMP,
            "points": points,
        }

        # Create a transaction object from our database client.
        transaction = db.transaction()
        # Run our transaction function. Firestore handles the retries and safety.
        request_id = create_new_request_in_transaction(transaction, request_data)
        
        print(f"Request {request_id} saved to Firestore.")
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Firestore transaction failed: {str(e)}")

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