import os
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")
genai.configure(api_key=api_key)

models_to_test = [
    "gemini-2.5-flash",
    "gemini-3.5-flash",
    "gemini-3.1-flash-lite",
]

for m in models_to_test:
    print(f"\nTesting {m}...")
    try:
        model = genai.GenerativeModel(m)
        response = model.generate_content("hello")
        print(f"SUCCESS {m}: {response.text.strip()}")
        #break
    except Exception as e:
        print(f"FAILED {m}: {e}")
