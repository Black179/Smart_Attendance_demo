import json
import math
import os
from typing import List, Optional, Tuple

# Face recognition similarity threshold from environment variable
SIMILARITY_THRESHOLD = float(os.getenv('FACE_SIMILARITY_THRESHOLD', '0.7'))

def cosine_similarity(vec1: List[float], vec2: List[float]) -> float:
    """
    Compute cosine similarity between two vectors using pure Python.
    Returns a value between -1 and 1, where 1 means identical vectors.
    """
    if len(vec1) != len(vec2):
        raise ValueError("Vectors must have the same length")
    
    # Compute dot product
    dot_product = sum(a * b for a, b in zip(vec1, vec2))
    
    # Compute magnitudes
    magnitude1 = math.sqrt(sum(a * a for a in vec1))
    magnitude2 = math.sqrt(sum(b * b for b in vec2))
    
    # Avoid division by zero
    if magnitude1 == 0 or magnitude2 == 0:
        return 0.0
    
    return dot_product / (magnitude1 * magnitude2)

def euclidean_distance(vec1: List[float], vec2: List[float]) -> float:
    """
    Compute Euclidean distance between two vectors.
    Lower values indicate higher similarity.
    """
    if len(vec1) != len(vec2):
        raise ValueError("Vectors must have the same length")
    
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(vec1, vec2)))

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
    Find the best matching embedding from stored embeddings.
    
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
                # Convert threshold for distance-based comparison
                distance_threshold = 2.0 - SIMILARITY_THRESHOLD  # Rough conversion
                if score < best_score and score <= distance_threshold:
                    best_score = score
                    best_match = (student_id, 1.0 - (score / 2.0))  # Convert to similarity
        except ValueError as e:
            print(f"Error processing embedding for student {student_id}: {e}")
            continue
    
    return best_match

def normalize_embedding(embedding: List[float]) -> List[float]:
    """
    Normalize embedding vector to unit length for better cosine similarity computation.
    """
    magnitude = math.sqrt(sum(x * x for x in embedding))
    if magnitude == 0:
        return embedding
    return [x / magnitude for x in embedding]
