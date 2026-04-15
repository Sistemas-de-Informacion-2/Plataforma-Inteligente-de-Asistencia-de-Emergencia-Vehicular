import os
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")
genai.configure(api_key=api_key)

models_to_test = [
    "gemini-2.0-flash-lite-001",
    "gemini-2.0-flash-lite",
    "gemini-2.5-flash",
    "gemini-1.5-flash-latest",
    "gemini-1.5-flash",
    "gemini-pro"
]

for m in models_to_test:
    print(f"\nTesting {m}...")
    try:
        model = genai.GenerativeModel(m)
        response = model.generate_content("hello")
        print(f"SUCCESS {m}: {response.text.strip()}")
        break
    except Exception as e:
        print(f"FAILED {m}: {e}")
