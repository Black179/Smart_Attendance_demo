from sqlmodel import SQLModel, Field
from datetime import datetime
from typing import Optional

class Student(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    roll: str = Field(unique=True)
    class_id: str
    face_embedding: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)

class Attendance(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    student_id: int = Field(foreign_key="student.id")
    class_id: str
    date: str
    status: str  # "Present", "Absent", "Pending"
    created_at: datetime = Field(default_factory=datetime.utcnow)

class ODRequest(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    student_id: int = Field(foreign_key="student.id")
    reason: str
    file_path: Optional[str] = None
    status: str = "Pending"  # "Pending", "Approved", "Rejected"
    comment: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
