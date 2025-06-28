# Dockerfile

# Use a slim, official Python image for a smaller container size
FROM python:3.11-slim

# Set environment variables for best practices
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Set the working directory inside the container
WORKDIR /app

# Copy only the requirements file first to leverage Docker's build cache
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy your application code into the container.
# This will copy the 'backend_project' folder into '/app'.
COPY ./backend_project ./backend_project

# Expose the port your app will run on
EXPOSE 8080

# Define the command to run your app.
# This correctly points to the 'app' object inside 'backend_project/main.py'.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--threads", "8", "--timeout", "0", "-k", "uvicorn.workers.UvicornWorker", "backend_project.main:app"]