# backend/app/services/ia_service.py
import os
import json
from abc import ABC, abstractmethod
from faster_whisper import WhisperModel
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

# 1. MOTOR DE TRANSCRIPCIÓN LOCAL
class TranscriptionService:
    def __init__(self):
        # Configuramos para CPU con int8 para máxima eficiencia en tu Intel i7
        self.model = WhisperModel("small", device="cpu", compute_type="int8")

    def transcribir(self, ruta_audio: str) -> str:
        if not ruta_audio or not os.path.exists(ruta_audio):
            return ""
        try:
            segments, info = self.model.transcribe(ruta_audio, beam_size=5, language="es")
            texto_completo = " ".join([segment.text for segment in segments])
            return texto_completo.strip()
        except Exception as e:
            print(f"Error en Whisper: {e}")
            return "[Error al transcribir audio]"

# 2. PATRÓN ESTRATEGIA PARA IA (LLMs)
class AIProvider(ABC):
    """Clase base para cualquier proveedor de Inteligencia Artificial."""
    @abstractmethod
    def analizar_incidente(self, texto_transcrito: str, descripcion: str, ruta_imagen: str = None) -> dict:
        pass

class GeminiProvider(AIProvider):
    """Implementación específica para Google Gemini 1.5 Flash."""
    def __init__(self):
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("Falta GEMINI_API_KEY en el entorno.")
        genai.configure(api_key=api_key)
        
        # Forzamos la salida en formato JSON
        self.model = genai.GenerativeModel(
            "gemini-2.5-flash",
            generation_config={"response_mime_type": "application/json"}
        )

    def analizar_incidente(self, texto_transcrito: str, descripcion: str, ruta_imagen: str = None) -> dict:
        prompt = f"""
        Eres un perito mecánico automotriz experto en emergencias vehiculares en Bolivia.

        Tu tarea es analizar un incidente basándote en:
        1. Descripción escrita del usuario
        2. Transcripción de audio
        3. Imagen (si está disponible)

        --- DATOS DEL INCIDENTE ---
        Descripción: "{descripcion if descripcion else 'Ninguna'}"
        Audio: "{texto_transcrito if texto_transcrito else 'Ninguno'}"

        --- INSTRUCCIONES ---
        Analiza cuidadosamente toda la información disponible.

        Clasifica el problema en UNA de estas categorías:
        - BATERIA (problemas eléctricos, no arranca)
        - LLANTA (pinchazo, desgaste)
        - MOTOR (sobrecalentamiento, fallas mecánicas)
        - CHOQUE (accidente, daños visibles)
        - COMBUSTIBLE (sin gasolina, fuga)
        - FRENOS (problemas al frenar)
        - TRANSMISION (cambios, caja)
        - CERRAJERO (llaves, bloqueo)
        - ELECTRICO (luces, sistema eléctrico general)
        - OTRO (si no encaja en ninguna)

        Define la PRIORIDAD según el riesgo:
        - ALTA: riesgo inmediato (accidente, humo, fuego, vehículo detenido en carretera peligrosa)
        - MEDIA: problema serio pero no crítico inmediato
        - BAJA: problema leve o no urgente

        Define el NIVEL DE GRAVEDAD del daño al vehículo:
        - CRITICO: Pérdida total o daños masivos que impiden la inmovilidad de por vida
        - GRAVE: Daño estructural importante (ej: motor, choque fuerte)
        - MEDIO: Problemas que detienen la marcha pero son solucionables fácilmente (ej: neumático, batería)
        - LEVE: Raspón, daño estético menor

        Genera un RESUMEN CLARO DEL PROBLEMA:
        - Máximo 4 líneas
        - Debe ser fácil de entender para el cliente
        - Debe dar suficiente contexto para el mecánico
        - Explica qué está pasando

        Evalúa la CONFIANZA (0.0 a 1.0):
        - 0.0 - 0.4 → información insuficiente o ambigua
        - 0.5 - 0.7 → diagnóstico probable pero no seguro
        - 0.8 - 1.0 → diagnóstico claro y consistente

        --- REGLAS ESTRICTAS ---
        - NO inventes información
        - SI NO ESTÁS SEGURO → usa categoria "OTRO" y baja confianza

        --- FORMATO DE RESPUESTA (OBLIGATORIO JSON) ---
        Responde SOLO con este JSON válido:

        {{
            "categoria": "...",
            "prioridad": "...",
            "nivel_gravedad": "LEVE" | "MEDIO" | "GRAVE" | "CRITICO",
            "resumen": "...",
            "confianza": 0.0
        }}
        """

        contenidos = [prompt]

        if ruta_imagen and os.path.exists(ruta_imagen):
            try:
                imagen_file = genai.upload_file(ruta_imagen)
                contenidos.append(imagen_file)
            except Exception as e:
                print(f"Error subiendo imagen: {e}")

        try:
            response = self.model.generate_content(contenidos)
            texto = response.text.strip()
            if texto.startswith("```"):
                texto = texto.replace("```json", "").replace("```", "").strip()
            resultado = json.loads(texto)
        
            return {
                "categoria": resultado.get("categoria", "OTRO"),
                "prioridad": resultado.get("prioridad", "MEDIA"),
                "nivel_gravedad": resultado.get("nivel_gravedad", "MEDIO"),
                "resumen": resultado.get("resumen", "Sin información suficiente"),
                "confianza": float(resultado.get("confianza", 0.0))
        }
        except Exception as e:
            print(f"Error en Gemini API: {e}")
            return {
                "categoria": "OTRO",
                "prioridad": "MEDIA",
                "nivel_gravedad": "MEDIO",
                "resumen": "No se pudo analizar el incidente.",
                "confianza": 0.0
            }


# 3. EL ORQUESTADOR PRINCIPAL
class AsistenteEmergencia:
    def __init__(self, ai_provider: AIProvider):
        self.transcriptor = TranscriptionService()
        self.ai = ai_provider

    def procesar_sos(self, descripcion: str, ruta_audio: str = None, ruta_imagen: str = None) -> dict:
        print("Iniciando procesamiento híbrido SOS...")
        
        texto_audio = ""
        if ruta_audio:
            print("1. Transcribiendo audio localmente con Whisper...")
            texto_audio = self.transcriptor.transcribir(ruta_audio)
            print(f"Texto extraído: {texto_audio}")

        print("2. Enviando contexto al LLM para diagnóstico...")
        diagnostico = self.ai.analizar_incidente(texto_audio, descripcion, ruta_imagen)
        
        print("=== RESULTADO DEL ANÁLISIS ===")
        print(json.dumps(diagnostico, indent=2, ensure_ascii=False))
        
        return diagnostico

# Variable global para importar fácilmente en tu router/endpoint
# Aquí inyectas la dependencia. Si mañana usas OpenAI, cambias esto a OpenAIProvider()
asistente_ia = AsistenteEmergencia(ai_provider=GeminiProvider())