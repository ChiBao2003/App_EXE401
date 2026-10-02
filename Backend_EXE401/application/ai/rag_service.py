"""
application/ai/rag_service.py
Service for Retrieval-Augmented Generation (RAG) using ChromaDB and Google Gemini Embeddings.
"""
import os
import logging
import httpx
import uuid
import chromadb
from typing import List, Dict, Any

logger = logging.getLogger("rag_service")

# Gemini Embedding Endpoint
GEMINI_EMBEDDING_URL = "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent"

from google import genai

class RAGService:
    def __init__(self, api_key: str = "", persist_directory: str = "storage/chroma"):
        self.api_key = api_key or os.getenv("GEMINI_API_KEY", "")
        if self.api_key:
            self.genai_client = genai.Client(api_key=self.api_key)
        else:
            self.genai_client = None

        # Initialize ChromaDB Persistent Client
        try:
            self.chroma_client = chromadb.PersistentClient(path=persist_directory)
            self.collection = self.chroma_client.get_or_create_collection(name="user_productivity_knowledge")
            logger.info(f"ChromaDB initialized at {persist_directory}")
        except Exception as e:
            logger.error(f"Failed to initialize ChromaDB: {e}")
            self.chroma_client = None
            self.collection = None

    async def _get_embedding(self, text: str) -> List[float]:
        """Call Gemini API to generate embeddings for the text."""
        if not self.genai_client:
            logger.warning("No API key for embedding. Skipping.")
            return []

        try:
            # Using new Google GenAI SDK for embeddings
            result = self.genai_client.models.embed_content(
                model='gemini-embedding-001',
                contents=text,
            )
            return result.embeddings[0].values
        except Exception as e:
            logger.error(f"Error generating embedding: {e}")
            return []

    def _chunk_text(self, text: str, chunk_size: int = 500, overlap: int = 50) -> List[str]:
        """Simple text chunker by character length."""
        chunks = []
        start = 0
        text_length = len(text)
        while start < text_length:
            end = start + chunk_size
            chunks.append(text[start:end])
            start = end - overlap
        return chunks

    async def index_document(self, user_id: str, document_text: str, source: str = "general"):
        """Chunk document, embed, and store in ChromaDB."""
        if not self.collection:
            return

        chunks = self._chunk_text(document_text)
        
        for i, chunk in enumerate(chunks):
            embedding = await self._get_embedding(chunk)
            if not embedding:
                continue
                
            doc_id = f"{user_id}_{uuid.uuid4().hex}"
            
            try:
                self.collection.add(
                    ids=[doc_id],
                    embeddings=[embedding],
                    documents=[chunk],
                    metadatas=[{"user_id": user_id, "source": source, "chunk_index": i}]
                )
            except Exception as e:
                logger.error(f"Failed to add chunk to ChromaDB: {e}")

    async def search_context(self, user_id: str, query: str, top_k: int = 3) -> str:
        """Search ChromaDB for relevant context based on semantic query."""
        if not self.collection:
            return ""

        query_embedding = await self._get_embedding(query)
        if not query_embedding:
            return ""

        try:
            results = self.collection.query(
                query_embeddings=[query_embedding],
                n_results=top_k,
                where={"user_id": user_id}  # Only search documents belonging to this user
            )
            
            # Extract documents from results
            documents = results.get("documents", [[]])[0]
            
            if documents:
                context_str = "\n---\n".join(documents)
                return f"TÀI LIỆU LỊCH SỬ THAM KHẢO TỪ HỆ THỐNG RAG:\n{context_str}"
            return ""
            
        except Exception as e:
            logger.error(f"ChromaDB search error: {e}")
            return ""
