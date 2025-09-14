from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from contextlib import asynccontextmanager
from sqlmodel import Field, Session, SQLModel, create_engine, select
from typing import Optional, List
import os
import shutil
from datetime import datetime, date, timedelta
from pydantic import BaseModel
import json
import jwt
from passlib.context import CryptContext
from face_recognition import parse_embedding, cosine_similarity, find_best_match
import uvicorn

# Database Models
class Student(SQLModel, table=True, extend_existing=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    roll: str = Field(unique=True)
    class_id: str
    face_embedding: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

class Attendance(SQLModel, table=True, extend_existing=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    student_id: int = Field(foreign_key="student.id")
    class_id: str
    date: str
    status: str
    created_at: datetime = Field(default_factory=datetime.utcnow)

class ODRequest(SQLModel, table=True, extend_existing=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    student_id: int = Field(foreign_key="student.id")
    reason: str
    file_path: Optional[str] = None
    status: str = Field(default="Pending")
    comment: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

# JWT Configuration
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    create_db_and_tables()
    seed_data()
    yield
    # Shutdown (if needed)

# Create FastAPI app
app = FastAPI(title="SmartAttendance API", version="1.0.0", lifespan=lifespan)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for public access
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# Database setup
DATABASE_URL = "sqlite:///./db.sqlite3"
engine = create_engine(DATABASE_URL, echo=False)

def get_session():
    with Session(engine) as session:
        yield session

def create_db_and_tables():
    try:
        # Clear existing metadata to avoid conflicts
        SQLModel.metadata.clear()
        SQLModel.metadata.create_all(engine, checkfirst=True)
    except Exception as e:
        print(f"Database creation warning: {e}")
        # Continue anyway as tables might already exist

# Request/Response models
class RecognitionRequest(BaseModel):
    embedding: List[float]
    class_id: str

class RecognitionResponse(BaseModel):
    recognized: bool
    student_id: Optional[int] = None
    student_name: Optional[str] = None
    roll: Optional[str] = None
    similarity_score: Optional[float] = None

# Authentication Models
class LoginRequest(BaseModel):
    role: str  # "student", "teacher", "driver"
    roll: Optional[str] = None  # For students
    username: Optional[str] = None  # For teachers/drivers
    password: Optional[str] = None  # For teachers/drivers

class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    role: str
    user_id: Optional[int] = None
    roll: Optional[str] = None

# Authentication functions
def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        role: str = payload.get("role")
        user_id: int = payload.get("user_id")
        roll: str = payload.get("roll")
        if role is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return {"role": role, "user_id": user_id, "roll": roll}
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

def seed_data():
    """Add sample data for testing"""
    with Session(engine) as session:
        # Check if data already exists
        existing_student = session.exec(select(Student)).first()
        if existing_student:
            return
        
        # Add sample students
        students = [
            Student(name="John Doe", roll="CS001", class_id="CS-A"),
            Student(name="Jane Smith", roll="CS002", class_id="CS-A"),
            Student(name="Bob Johnson", roll="CS003", class_id="CS-B")
        ]
        
        for student in students:
            session.add(student)
        
        session.commit()
        print("Sample data seeded successfully")

@app.get("/")
async def root():
    return {"message": "SmartAttendance API is running"}

@app.get("/healthcheck")
def healthcheck():
    return {"status": "healthy"}

# Authentication endpoint
@app.post("/auth/login", response_model=LoginResponse)
async def login(request: LoginRequest, session: Session = Depends(get_session)):
    if request.role == "student":
        if not request.roll:
            raise HTTPException(status_code=400, detail="Roll number required for students")
        
        # Find student by roll number
        student = session.exec(select(Student).where(Student.roll == request.roll)).first()
        if not student:
            raise HTTPException(status_code=401, detail="Student not found")
        
        # Create JWT token
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"role": "student", "user_id": student.id, "roll": student.roll},
            expires_delta=access_token_expires
        )
        
        return LoginResponse(
            access_token=access_token,
            token_type="bearer",
            role="student",
            user_id=student.id,
            roll=student.roll
        )
    
    elif request.role in ["teacher", "driver"]:
        if not request.username or not request.password:
            raise HTTPException(status_code=400, detail="Username and password required")
        
        # Simple hardcoded credentials for demo (use proper user table in production)
        valid_credentials = {
            "teacher": {"username": "teacher", "password": "teacher123"},
            "driver": {"username": "driver", "password": "driver123"}
        }
        
        if (request.username != valid_credentials[request.role]["username"] or 
            request.password != valid_credentials[request.role]["password"]):
            raise HTTPException(status_code=401, detail="Invalid credentials")
        
        # Create JWT token
        access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        access_token = create_access_token(
            data={"role": request.role, "user_id": 1, "username": request.username},
            expires_delta=access_token_expires
        )
        
        return LoginResponse(
            access_token=access_token,
            token_type="bearer",
            role=request.role,
            user_id=1
        )
    
    else:
        raise HTTPException(status_code=400, detail="Invalid role")

@app.post("/enroll")
async def enroll_student(
    name: str = Form(...),
    roll: str = Form(...),
    class_id: str = Form(...),
    face_embedding: Optional[str] = Form(None),
    session: Session = Depends(get_session)
):
    # Check if student already exists
    existing_student = session.exec(select(Student).where(Student.roll == roll)).first()
    if existing_student:
        raise HTTPException(status_code=400, detail="Student with this roll number already exists")
    
    # Validate face embedding if provided
    if face_embedding:
        try:
            embedding_data = parse_embedding(face_embedding)
            if len(embedding_data) == 0:
                raise ValueError("Empty embedding")
        except ValueError as e:
            raise HTTPException(status_code=400, detail=f"Invalid face embedding: {str(e)}")
    
    # Create new student
    student = Student(
        name=name,
        roll=roll,
        class_id=class_id,
        face_embedding=face_embedding
    )
    
    session.add(student)
    session.commit()
    session.refresh(student)
    
    return {"message": "Student enrolled successfully", "student_id": student.id}

@app.post("/mark_attendance")
async def mark_attendance(
    student_roll: str = Form(...),
    class_id: str = Form(...),
    session: Session = Depends(get_session),
    current_user: dict = Depends(verify_token)
):
    if not student_roll or not class_id:
        raise HTTPException(status_code=400, detail="Roll and class_id are required")
    
    # Find student
    student = session.exec(select(Student).where(Student.roll == student_roll)).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    # Check if attendance already marked for today
    today = date.today().isoformat()
    existing_attendance = session.exec(
        select(Attendance).where(
            Attendance.student_id == student.id,
            Attendance.date == today,
            Attendance.class_id == class_id
        )
    ).first()
    
    if existing_attendance:
        existing_attendance.status = "Present"
        existing_attendance.created_at = datetime.utcnow()
    else:
        attendance = Attendance(
            student_id=student.id,
            class_id=class_id,
            date=today,
            status="Present"
        )
        session.add(attendance)
    
    session.commit()
    return {"message": "Attendance marked successfully"}

@app.get("/class/{class_id}/attendance")
async def get_class_attendance(
    class_id: str,
    session: Session = Depends(get_session),
    current_user: dict = Depends(verify_token)
):
    today = date.today().isoformat()
    
    # Get all students in the class
    students = session.exec(select(Student).where(Student.class_id == class_id)).all()
    
    result = []
    for student in students:
        # Check today's attendance
        attendance = session.exec(
            select(Attendance).where(
                Attendance.student_id == student.id,
                Attendance.date == today,
                Attendance.class_id == class_id
            )
        ).first()
        
        status = attendance.status if attendance else "Absent"
        
        result.append({
            "student_id": student.id,
            "name": student.name,
            "roll": student.roll,
            "status": status
        })
    
    return {"class_id": class_id, "date": today, "attendance": result}

@app.post("/attendance/update")
async def update_attendance(
    data: dict,
    session: Session = Depends(get_session),
    current_user: dict = Depends(verify_token)
):
    student_id = data.get("student_id")
    class_id = data.get("class_id")
    status = data.get("status")
    reason = data.get("reason", "")
    
    if not all([student_id, class_id, status]):
        raise HTTPException(status_code=400, detail="student_id, class_id, and status are required")
    
    today = date.today().isoformat()
    
    # Find existing attendance record
    attendance = session.exec(
        select(Attendance).where(
            Attendance.student_id == student_id,
            Attendance.date == today,
            Attendance.class_id == class_id
        )
    ).first()
    
    if attendance:
        attendance.status = status
        attendance.created_at = datetime.utcnow()
    else:
        attendance = Attendance(
            student_id=student_id,
            class_id=class_id,
            date=today,
            status=status
        )
        session.add(attendance)
    
    session.commit()
    return {"message": "Attendance updated successfully"}

@app.post("/od-request")
async def create_od_request(
    student_roll: str = Form(...),
    reason: str = Form(...),
    file: UploadFile = File(None),
    session: Session = Depends(get_session),
    current_user: dict = Depends(verify_token)
):
    # Find student
    student = session.exec(select(Student).where(Student.roll == student_roll)).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    # Handle file upload if provided
    file_path = None
    if file:
        file_path = f"uploads/od_{student_roll}_{file.filename}"
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
    
    # Create OD request
    od_request = ODRequest(
        student_id=student.id,
        reason=reason,
        file_path=file_path
    )
    
    session.add(od_request)
    session.commit()
    session.refresh(od_request)
    
    return {"message": "OD request submitted successfully", "request_id": od_request.id}

@app.post("/recognize", response_model=RecognitionResponse)
async def recognize_face(
    request: RecognitionRequest,
    session: Session = Depends(get_session)
):
    """
    Recognize a face by comparing embedding against stored student embeddings.
    Returns the best match if similarity is above threshold.
    """
    try:
        # Get all students with face embeddings in the specified class
        students = session.exec(
            select(Student).where(
                Student.class_id == request.class_id,
                Student.face_embedding.is_not(None)
            )
        ).all()
        
        if not students:
            return RecognitionResponse(recognized=False)
        
        # Prepare stored embeddings for comparison
        stored_embeddings = []
        for student in students:
            if student.face_embedding:
                stored_embeddings.append((student.id, student.face_embedding))
        
        if not stored_embeddings:
            return RecognitionResponse(recognized=False)
        
        # Find best match
        best_match = find_best_match(request.embedding, stored_embeddings)
        
        if best_match is None:
            return RecognitionResponse(recognized=False)
        
        student_id, similarity_score = best_match
        
        # Get student details
        matched_student = session.get(Student, student_id)
        if not matched_student:
            return RecognitionResponse(recognized=False)
        
        return RecognitionResponse(
            student_id=matched_student.id,
            student_name=matched_student.name,
            roll=matched_student.roll,
            similarity_score=similarity_score,
            recognized=True
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Recognition error: {str(e)}")

@app.get("/od-requests")
async def get_od_requests(
    session: Session = Depends(get_session),
    current_user: dict = Depends(verify_token)
):
    requests = session.exec(
        select(ODRequest, Student).join(Student).where(ODRequest.status == "Pending")
    ).all()
    
    result = []
    for od_request, student in requests:
        result.append({
            "id": od_request.id,
            "student_name": student.name,
            "student_roll": student.roll,
            "reason": od_request.reason,
            "file_path": od_request.file_path,
            "status": od_request.status,
            "created_at": od_request.created_at
        })
    
    return {"od_requests": result}

@app.post("/od-approve")
async def approve_od_request(
    data: dict,
    session: Session = Depends(get_session),
    current_user: dict = Depends(verify_token)
):
    od_id = data.get("od_id")
    status = data.get("status")
    comment = data.get("comment", "")
    
    if not od_id or not status:
        raise HTTPException(status_code=400, detail="od_id and status are required")
    
    if status not in ["Approved", "Rejected"]:
        raise HTTPException(status_code=400, detail="Status must be 'Approved' or 'Rejected'")
    
    # Find OD request
    od_request = session.exec(select(ODRequest).where(ODRequest.id == od_id)).first()
    if not od_request:
        raise HTTPException(status_code=404, detail="OD request not found")
    
    od_request.status = status
    od_request.comment = comment
    
    session.commit()
    return {"message": f"OD request {status.lower()} successfully"}

@app.post("/heartbeat")
async def receive_heartbeat(
    data: dict,
    session: Session = Depends(get_session)
):
    roll = data.get("roll")
    class_id = data.get("class_id")
    timestamp = data.get("timestamp")
    
    if not all([roll, class_id, timestamp]):
        raise HTTPException(status_code=400, detail="roll, class_id, and timestamp are required")
    
    # Find student
    student = session.exec(select(Student).where(Student.roll == roll)).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    # Update or create heartbeat record (using attendance table for simplicity)
    # In a real system, you might want a separate heartbeat/presence table
    today = date.today().isoformat()
    
    # Check if there's already a heartbeat record for today
    heartbeat = session.exec(
        select(Attendance).where(
            Attendance.student_id == student.id,
            Attendance.date == today,
            Attendance.class_id == class_id
        )
    ).first()
    
    if heartbeat:
        # Update existing record with new timestamp
        heartbeat.created_at = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
    else:
        # Create new heartbeat record
        heartbeat = Attendance(
            student_id=student.id,
            class_id=class_id,
            date=today,
            status="Present",  # BLE presence indicates Present
            created_at=datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        )
        session.add(heartbeat)
    
    session.commit()
    return {"message": "Heartbeat received", "student": student.name, "last_seen": timestamp}

if __name__ == "__main__":
    import os
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
