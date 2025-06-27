# lets_git_it

## 🛠️ Setup Instructions

1. Clone the repository

git clone https://github.com/akyung123/lets_git_it.git lets_git_it

cd lets_git_it

2. Install dependencies

pip install -r requirements.txt

3. Setting up .env file

Use the example provided using .env.example to setup your env file so that
your GEMINI API key and the path for the credentials json file is accurately set up

you can use this function to copy the example to create the .env file
cp .env.example .env

4. Get the json credential file inside the project-backend folder

go inside the backend-project and put the json credential file inside

if you don't want the credential json inside the folder, then you can specify the path where it is stored
inside the .env file and change the path set as an example.

5. Download ffmpeg for the complete dependency

Install ffmpeg: pydub requires a program called ffmpeg to work. You must install this on your computer.

- On macOS (using Homebrew):

brew install ffmpeg

- On Windows: Download the executable from the official FFmpeg site and add it to your system's PATH.

- On Linux (Debian/Ubuntu):

sudo apt update && sudo apt install ffmpeg

5. Run the server inside the backend-project directory

cd backend-project

uvicorn main:app --reload

