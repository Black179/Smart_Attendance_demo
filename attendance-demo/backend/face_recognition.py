import json
import os
import base64
import io
from typing import List, Optional, Tuple
from deepface import DeepFace
import numpy as np
from PIL import Image
import cv2

# Face recognition similarity threshold from environment variable
SIMILARITY_THRESHOLD = float(os.getenv('FACE_SIMILARITY_THRESHOLD', '0.6'))

def extract_face_embedding(image_data: str, model_name: str = "VGG-Face") -> List[float]:
    """
    Extract face embedding from base64 encoded image using DeepFace.
    
    Args:
        image_data: Base64 encoded image string
        model_name: DeepFace model to use (VGG-Face, Facenet, OpenFace, etc.)
    
    Returns:
        List of floats representing the face embedding
    """
    try:
        # Decode base64 image
        image_bytes = base64.b64decode(image_data)
        image = Image.open(io.BytesIO(image_bytes))
        
        # Convert PIL image to numpy array
        img_array = np.array(image)
        
        # Convert RGB to BGR for OpenCV compatibility
        if len(img_array.shape) == 3 and img_array.shape[2] == 3:
            img_array = cv2.cvtColor(img_array, cv2.COLOR_RGB2BGR)
        
        # Extract embedding using DeepFace
        embedding = DeepFace.represent(img_array, model_name=model_name, enforce_detection=False)
        
        # DeepFace.represent returns a list of dictionaries, get the first embedding
        if isinstance(embedding, list) and len(embedding) > 0:
            return embedding[0]["embedding"]
        else:
            return embedding["embedding"]
            
    except Exception as e:
        raise ValueError(f"Failed to extract face embedding: {str(e)}")

def cosine_similarity(vec1: List[float], vec2: List[float]) -> float:
    """
    Compute cosine similarity between two vectors.
    Returns a value between -1 and 1, where 1 means identical vectors.
    """
    if len(vec1) != len(vec2):
        raise ValueError("Vectors must have the same length")
    
    vec1 = np.array(vec1)
    vec2 = np.array(vec2)
    
    # Compute cosine similarity
    dot_product = np.dot(vec1, vec2)
    norm_vec1 = np.linalg.norm(vec1)
    norm_vec2 = np.linalg.norm(vec2)
    
    if norm_vec1 == 0 or norm_vec2 == 0:
        return 0.0
    
    return dot_product / (norm_vec1 * norm_vec2)

def euclidean_distance(vec1: List[float], vec2: List[float]) -> float:
    """
    Compute Euclidean distance between two vectors.
    Lower values indicate higher similarity.
    """
    if len(vec1) != len(vec2):
        raise ValueError("Vectors must have the same length")
    
    vec1 = np.array(vec1)
    vec2 = np.array(vec2)
    
    return np.linalg.norm(vec1 - vec2)

def parse_embedding(embedding_str: str) -> List[float]:
    """
    Parse face embedding from JSON string to list of floats.
    """
    try:
        return json.loads(embedding_str)
    except (json.JSONDecodeError, TypeError):
        raise ValueError("Invalid embedding format")

def find_best_match(
    query_embedding: List[float], 
    stored_embeddings: List[Tuple[int, str]], 
    use_cosine: bool = True
) -> Optional[Tuple[int, float]]:
    """
    Find the best matching embedding from stored embeddings using DeepFace.
    
    Args:
        query_embedding: The embedding to match against
        stored_embeddings: List of (student_id, embedding_json) tuples
        use_cosine: Whether to use cosine similarity (True) or Euclidean distance (False)
    
    Returns:
        Tuple of (student_id, similarity_score) if match found above threshold, None otherwise
    """
    best_match = None
    best_score = -1 if use_cosine else float('inf')
    
    for student_id, embedding_str in stored_embeddings:
        try:
            stored_embedding = parse_embedding(embedding_str)
            
            if use_cosine:
                score = cosine_similarity(query_embedding, stored_embedding)
                if score > best_score and score >= SIMILARITY_THRESHOLD:
                    best_score = score
                    best_match = (student_id, score)
            else:
                score = euclidean_distance(query_embedding, stored_embedding)
                # For Euclidean distance, lower is better
                # Convert to similarity score (higher is better)
                similarity_score = 1.0 / (1.0 + score)
                if similarity_score > best_score and similarity_score >= SIMILARITY_THRESHOLD:
                    best_score = similarity_score
                    best_match = (student_id, similarity_score)
        except ValueError as e:
            print(f"Error processing embedding for student {student_id}: {e}")
            continue
    
    return best_match

def compare_faces_deepface(img1_path: str, img2_path: str, model_name: str = "VGG-Face") -> float:
    """
    Compare two face images using DeepFace and return similarity score.
    
    Args:
        img1_path: Path to first image
        img2_path: Path to second image
        model_name: DeepFace model to use
    
    Returns:
        Similarity score between 0 and 1
    """
    try:
        result = DeepFace.verify(img1_path, img2_path, model_name=model_name, enforce_detection=False)
        # DeepFace.verify returns distance, convert to similarity
        distance = result["distance"]
        # Convert distance to similarity (lower distance = higher similarity)
        similarity = 1.0 / (1.0 + distance)
        return similarity
    except Exception as e:
        print(f"Error comparing faces: {e}")
        return 0.0

def normalize_embedding(embedding: List[float]) -> List[float]:
    """
    Normalize embedding vector to unit length for better cosine similarity computation.
    """
    embedding = np.array(embedding)
    norm = np.linalg.norm(embedding)
    if norm == 0:
        return embedding.tolist()
    return (embedding / norm).tolist()
