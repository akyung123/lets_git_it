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
from google.cloud.firestore_v1.base_query import FieldFilter
import shutil
import tempfile
import uuid

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
GOOGLE_PROJECT_ID = None
db = None
genai_is_configured = False

# CORRECT INITIALIZATION FOR CLOUD RUN DEPLOYMENT
try:
    # 1. Configure Gemini
    gemini_api_key = os.getenv("GEMINI_API_KEY")
    if not gemini_api_key:
        raise RuntimeError("CRITICAL ERROR: GEMINI_API_KEY secret was not loaded.")
    genai.configure(api_key=gemini_api_key)
    genai_is_configured = True
    print("Gemini SDK configured successfully.")

    # 2. Initialize Firebase
    # On Cloud Run, this automatically finds the credentials
    # provided by the --set-secrets flag. No file path is needed.
    firebase_admin.initialize_app()
    db = firestore.client()
    GOOGLE_PROJECT_ID = db.project
    print(f"Firebase Admin SDK initialized successfully for project: {GOOGLE_PROJECT_ID}")

except Exception as e:
    print(f"A critical error occurred during startup initialization: {e}")

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

@firestore.transactional
def delete_last_request_in_transaction(transaction):
    """
    Atomically deletes the most recent request and decrements the request counter.
    """
    counter_ref = db.collection('counters').document('request_counter')
    counter_snapshot = counter_ref.get(transaction=transaction)

    if not counter_snapshot.exists:
        raise ValueError("Counter document 'request_counter' not found.")

    last_id = counter_snapshot.get('lastId')

    # Edge case: If the counter is already at 0, there's nothing to delete.
    if last_id <= 0:
        raise ValueError("No requests exist to be deleted (counter is at 0).")

    # Construct the ID of the document to be deleted (e.g., "req012")
    request_id_to_delete = f"req{last_id:03d}"
    request_ref_to_delete = db.collection('requests').document(request_id_to_delete)
    
    # Check if the request document actually exists before trying to delete
    request_doc = request_ref_to_delete.get(transaction=transaction)
    if not request_doc.exists:
        # This indicates a data inconsistency. It's safer to stop and report this.
        # We will also decrement the counter to fix the inconsistency.
        transaction.update(counter_ref, {'lastId': last_id - 1})
        raise ValueError(f"Inconsistency found: Request '{request_id_to_delete}' did not exist, but counter was at {last_id}. The counter has been corrected.")

    # Perform the deletion and the counter decrement
    transaction.delete(request_ref_to_delete)
    transaction.update(counter_ref, {'lastId': last_id - 1})

    # Return the ID of the deleted request for a success message
    return request_id_to_delete

def calculate_request_points(task_info: dict) -> int:
    """
    Calculates the points rewarded based on the context behind the request.
    """
    points = 10
    if task_info.get("method") == "차량":
        points += 5
    if task_info.get("method") == "도보":
        points += 10
    # etc there can be many more ways to calculate the point based on info extracted
    return points

@app.post("/request/voice")
async def process_voice_request(
    user_id: str,
    audio_file: UploadFile = File(...)
):
    if not db or not genai_is_configured:
        raise HTTPException(status_code=503, detail="A backend service is not configured check server logs.")
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
        recognizer_name = f"projects/{GOOGLE_PROJECT_ID}/locations/global/recognizers/_"

        config = {
            "explicit_decoding_config": {
                "encoding": "LINEAR16",
                "sample_rate_hertz": 16000,
                "audio_channel_count": 1,
            },
            "language_codes": ["ko-KR"], 
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
    
    # -- New Logic: Validating completness --
    required_fields = ["time", "locationFrom", "locationTo", "method"]
    missing_fields = [field for field in required_fields if not extracted_info.get(field)]

    if not missing_fields:
        # If nothing is missing do everything like normal
        if not db:
            raise HTTPException(status_code=500, detail="Firestore client not available.")

        # Point calculation and Request saved in DB using a Transaction
        try:
            # First, prepare the data that needs to be saved.
            points = calculate_request_points(extracted_info)

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

            try:
                # This part remains the same: get all volunteer tokens
                volunteers_ref = db.collection('users').where(filter=FieldFilter('role', '==', 'volunteer')).stream()
                registration_tokens = []
                for volunteer in volunteers_ref:
                    volunteer_data = volunteer.to_dict()
                    if volunteer_data.get('fcmToken'):
                        registration_tokens.append(volunteer_data['fcmToken'])

                # This is the new logic
                if registration_tokens:
                    print(f"Found {len(registration_tokens)} volunteers. Sending notifications individually.")
                    success_count = 0
                    failure_count = 0

                    # Loop through each token and send a message
                    for token in registration_tokens:
                        # We put the send logic in its own try/except block.
                        # This ensures that if one token is bad, it won't crash the whole loop.
                        try:
                            message = messaging.Message(
                                notification=messaging.Notification(
                                    title="새로운 도움 요청!", # "New Help Request!"
                                    body=f"새로운 요청이 접수되었습니다: {transcribed_text[:50]}..." # "A new request has been received..."
                                ),
                                data={
                                    'requestId': request_id,
                                    'click_action': 'FLUTTER_NOTIFICATION_CLICK'
                                },
                                token=token, # Use the individual token here
                            )
                            # Use the send() function that we proved works
                            messaging.send(message)
                            success_count += 1
                        except Exception as e:
                            failure_count += 1
                            # Log the error for the specific failing token
                            print(f"Failed to send to one token. Error: {e}")
                    
                    print(f"FCM sending complete. Successes: {success_count}, Failures: {failure_count}")

            except Exception as e:
                # This outer block catches larger errors, like failing to get the volunteers list
                print(f"A critical error occurred during the FCM process: {str(e)}")

            return {
                "status": "success",
                "request_id": request_id,
                "message": "Request processed, saved, and notifications sent."
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Firestore transaction failed: {str(e)}")
    else:
        # -- INFO is missing: Create a pending request --
        if not db:
            raise HTTPException(status_code=500, detail="Firestore client not available.")
        
        try:
            pending_id = str(uuid.uuid4())
            pending_request_ref = db.collection('pending_requests').document(pending_id)
            # Store the partial data with an expiry mechanism
            # We'll use a `createdAt` timestamp. A Cloud Function or client-side logic can handle cleanup.
            pending_data = {
                "requesterId": user_id,
                "partialInfo": extracted_info,
                "missingFields": missing_fields,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "originalTranscript": transcribed_text,
            }
            pending_request_ref.set(pending_data)

            # Generate a user-friendly prompt asking for the missing information
            prompt_map = {
                "time": "언제 도움이 필요하신가요?",
                "locationFrom": "어디에서 출발하시나요?",
                "locationTo": "어디로 가시나요?",
                "method": "차량이 필요한가요, 아니면 걸어서 가도 괜찮은가요?"
            }
            # Create a clear question for the frontend to use
            clarification_prompt_text = " ".join([prompt_map[field] for field in missing_fields])
            
            print(f"Incomplete request. Pending ID: {pending_id}. Asking for: {missing_fields}")

            # Return a specific response to the frontend
            return {
                "status": "incomplete",
                "message": "More information is needed.",
                "pending_request_id": pending_id,
                "missing_fields": missing_fields,
                "clarification_prompt_text": clarification_prompt_text
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to create pending request: {str(e)}")
        
@app.post("/request/voice/continue")
async def continue_voice_request(
    user_id: str,
    pending_request_id: str,
    audio_file: UploadFile = File(...)
):
    if not db or not genai_is_configured:
        raise HTTPException(status_code=503, detail="A backend service is not configured check server logs.")
    # --- 1. Get the pending request data from Firestore ---
    pending_ref = db.collection('pending_requests').document(pending_request_id)
    pending_doc = pending_ref.get()

    if not pending_doc.exists:
        raise HTTPException(status_code=404, detail="Pending request not found or has expired.")
    
    pending_data = pending_doc.to_dict()
    partial_info = pending_data.get("partialInfo", {})
    original_transcript = pending_data.get("originalTranscript", "")

    # You could add time-based expiration logic here if needed
    # For example, check pending_data.get("createdAt") against the current time.

    # --- 2. Transcribe the new audio file ---
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
            raise HTTPException(status_code=400, detail="Received an empty follow-up audio file.")

        client = SpeechClient()
        recognizer_name = f"projects/{GOOGLE_PROJECT_ID}/locations/global/recognizers/_"
        config = {
            "explicit_decoding_config": {
                "encoding": "LINEAR16",
                "sample_rate_hertz": 16000,
                "audio_channel_count": 1,
            },
            "language_codes": ["ko-KR"],
            "model": "latest_short",
        }
        request = RecognizeRequest(
            recognizer=recognizer_name, 
            config=config, 
            content=content,
        )

        response = client.recognize(request=request)
        
        if not response.results:
            # It's better to ask again than to fail here
            # Let's return the previous state and ask the user to repeat
            prompt_map = { "time": "언제 도움이 필요하신가요?", "locationFrom": "어디에서 출발하시나요?", "locationTo": "어디로 가시나요?", "method": "차량이 필요한가요, 아니면 걸어서 가도 괜찮은가요?"}
            clarification_prompt_text = " ".join([prompt_map[field] for field in pending_data.get("missingFields", [])])
            return {
                "status": "incomplete",
                "message": "죄송합니다, 잘 알아듣지 못했어요. 다시 한번 말씀해주시겠어요?",
                "pending_request_id": pending_request_id,
                "missing_fields": pending_data.get("missingFields", []),
                "clarification_prompt_text": f"죄송합니다, 잘 알아듣지 못했어요. {clarification_prompt_text}"
            }
            
        new_transcribed_text = response.results[0].alternatives[0].transcript
        print(f"New Transcribed Text: {new_transcribed_text}")

    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"An unexpected error occurred during follow-up Speech-to-Text: {str(e)}")
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)

    # --- 3. Combine old and new information with Gemini ---
    try:
        current_time = datetime.now()
        current_time_str = current_time.strftime("%Y년 %m월 %d일, %A, %p %I:%M")
        
        # This prompt gives Gemini the full context
        prompt = f"""
        다음은 사용자와의 대화 내용입니다. 기존 정보를 바탕으로 새로운 정보를 통합하여 JSON 객체를 완성해주세요.
        현재 날짜는 "{current_time_str}"입니다.
        
        기존 요청 내용: "{original_transcript}"
        지금까지 수집된 정보: {json.dumps(partial_info, ensure_ascii=False)}
        사용자의 추가 응답: "{new_transcribed_text}"
        
        위 정보를 모두 종합하여 다음 JSON 객체를 완성해주세요.
        반드시 유효한 JSON 객체 형식으로만 응답해야 하며, 다음 키들을 포함해야 합니다: "time", "locationFrom", "locationTo", "method", "task_description".
        - 언급되지 않은 값이 있다면, 그 값은 null로 설정해주세요.
        """
        model = genai.GenerativeModel('gemini-1.5-flash-latest')
        gemini_response = await model.generate_content_async(prompt)
        
        cleaned_response_text = gemini_response.text.strip().lstrip("```json").rstrip("```")
        updated_info = json.loads(cleaned_response_text)
        print(f"Gemini Updated Info: {updated_info}")

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Gemini update analysis failed: {str(e)}")

    # --- 4. Re-validate the combined information ---
    required_fields = ["time", "locationFrom", "locationTo", "method"]
    missing_fields = [field for field in required_fields if not updated_info.get(field)]

    if not missing_fields:
        # --- COMPLETE: Save to DB and delete pending request ---
        try:
            # You already have the transactional function defined in the global scope
            # so we can reuse it directly.
            
            # Prepare the final request data from the 'updated_info'
            points = calculate_request_points(updated_info)

            final_request_data = {
                "requesterId": user_id,
                "locationFrom": updated_info.get("locationFrom"),
                "locationTo": updated_info.get("locationTo"),
                "time": updated_info.get("time"),
                "status": "waiting",
                "matchedVolunteerId": None,
                "method": updated_info.get("method"),
                "createdAt": firestore.SERVER_TIMESTAMP,
                "points": points,
            }

            transaction = db.transaction()
            # The function `create_new_request_in_transaction` is defined at the top-level
            # of our file, so we can call it here.
            request_id = create_new_request_in_transaction(transaction, final_request_data)
            
            print(f"Request {request_id} finalized.")
            
            # (Optional but good to have) Also send the final FCM notification here
            try:
                # This is the same FCM logic from the first endpoint
                volunteers_ref = db.collection('users').where('role', '==', 'volunteer').stream()
                registration_tokens = []
                for volunteer in volunteers_ref:
                    volunteer_data = volunteer.to_dict()
                    if volunteer_data.get('fcmToken'):
                        registration_tokens.append(volunteer_data['fcmToken'])
                if registration_tokens:
                    # Note: We can use the combined transcript for a better notification
                    full_transcript = f"{original_transcript}. {new_transcribed_text}"
                    message = messaging.MulticastMessage(
                        notification=messaging.Notification(
                            title="New Help Request!",
                            body=f"A new request is available: {full_transcript[:50]}..."
                        ),
                        data={ 'requestId': request_id, 'click_action': 'FLUTTER_NOTIFICATION_CLICK' },
                        tokens=registration_tokens,
                    )
                    response = messaging.send_multicast(message)
                    print(f'{response.success_count} messages were sent successfully')
            except Exception as e:
                print(f"An error occurred sending FCM notifications on finalized request: {str(e)}")
            
            pending_ref.delete()
            print(f"Pending request {pending_request_id} deleted")
            return {
                "status": "success",
                "request_id": request_id,
                "message": "Request successfully finalized and saved."
            }
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Firestore finalization transaction failed: {str(e)}")
    else:
        # --- STILL INCOMPLETE: Update the pending request and ask again ---
        pending_ref.update({
            "partialInfo": updated_info,
            "missingFields": missing_fields
        })
        
        prompt_map = { # You can reuse the map from before
            "time": "언제 도움이 필요하신가요?",
            "locationFrom": "어디에서 출발하시나요?",
            "locationTo": "어디로 가시나요?",
            "method": "차량이 필요한가요, 아니면 걸어서 가도 괜찮은가요?"
        }
        clarification_prompt_text = " ".join([prompt_map[field] for field in missing_fields])
        
        return {
            "status": "incomplete",
            "message": "More information is still needed.",
            "pending_request_id": pending_request_id,
            "missing_fields": missing_fields,
            "clarification_prompt_text": clarification_prompt_text
        }
    
@app.delete("/request/last", tags=["Admin"])
async def delete_last_request():
    """
    Deletes the most recently created request and decrements the global counter.
    This provides a safe way to undo the last request submission.
    """
    if not db:
        raise HTTPException(status_code=500, detail="Firestore client not available.")

    try:
        # Create a transaction object and run our function within it.
        transaction = db.transaction()
        deleted_request_id = delete_last_request_in_transaction(transaction)
        
        return {
            "status": "success",
            "message": f"Successfully deleted last request '{deleted_request_id}' and decremented counter.",
        }
    except ValueError as e:
        # This catches the specific, predictable errors we raised in the transaction.
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        # This catches any other unexpected errors from Firestore.
        raise HTTPException(status_code=500, detail=f"An unexpected Firestore error occurred: {str(e)}")