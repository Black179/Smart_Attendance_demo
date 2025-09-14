# Use Python for backend
FROM python:3.11

# Set working directory
WORKDIR /app

# Copy backend code
COPY backend/ ./backend/

# Install backend dependencies
RUN pip install --no-cache-dir -r backend/requirements.txt

# Expose backend port
EXPOSE 8000

# Run FastAPI app
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
