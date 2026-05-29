# backend/app/services/ia_service.py
import os
import json
from abc import ABC, abstractmethod
from faster_whisper import WhisperModel
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

# ══════════════════════════════════════════════════════════════
# CATÁLOGO PLANO DE SERVICIOS DE EMERGENCIA VEHICULAR
# ──────────────────────────────────────────────────────────────
# Esta lista es la ÚNICA fuente de verdad. La IA debe mapear
# cada emergencia a uno o más de estos nombres EXACTOS.
# ══════════════════════════════════════════════════════════════
CATALOGO_SERVICIOS = [
    "Remolque con Grúa de Plataforma",
    "Servicio de Rescate / Salvamento (Winch)",
    "Provisión de Combustible de Emergencia",
    "Paso de Corriente (Puente)",
    "Reemplazo de Batería a Domicilio",
    "Revisión de Alternador y Sistema Eléctrico",
    "Cambio por Llanta de Repuesto",
    "Reparación de Pinchazo (Parche/Tarugo)",
    "Calibración e Inflado Móvil",
    "Asistencia por Sobrecalentamiento",
    "Diagnóstico de Fallas de Encendido",
    "Contención de Fugas de Fluidos",
    "Desatasco de Ruedas por Colisión",
    "Apertura de Vehículo (Cerrajería)",
    "Escaneo Computarizado (OBD2)",
]


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
    def analizar_incidente(
        self,
        texto_transcrito: str,
        descripcion: str,
        rutas_imagenes: list[str] | None = None,
    ) -> dict:
        pass


class GeminiProvider(AIProvider):
    """Implementación específica para Google Gemini 2.5 Flash."""
    def __init__(self):
        api_key = os.getenv("GEMINI_API_KEY")
        if not api_key:
            raise ValueError("Falta GEMINI_API_KEY en el entorno.")
        genai.configure(api_key=api_key)

        # Forzamos la salida en formato JSON
        self.model = genai.GenerativeModel(
            "gemini-3.5-flash",
            generation_config={"response_mime_type": "application/json"}
        )

    def analizar_incidente(
        self,
        texto_transcrito: str,
        descripcion: str,
        rutas_imagenes: list[str] | None = None,
    ) -> dict:
        # ── Construir la sección del catálogo para el prompt ─────
        catalogo_formateado = "\n".join(
            f"  - {nombre}" for nombre in CATALOGO_SERVICIOS
        )

        prompt = f"""
        Eres un perito mecánico automotriz experto en emergencias vehiculares en Bolivia.

        Tu tarea es analizar un incidente vehicular siguiendo un razonamiento
        paso a paso (Chain of Thought) y luego mapear el problema a los
        servicios exactos que lo solucionan.

        ══════════════════════════════════════════
        DATOS DEL INCIDENTE
        ══════════════════════════════════════════
        Descripción del usuario: "{descripcion if descripcion else 'Ninguna'}"
        Transcripción de audio:  "{texto_transcrito if texto_transcrito else 'Ninguno'}"
        Imágenes adjuntas:       {"Sí" if rutas_imagenes else "No"}

        ══════════════════════════════════════════
        CATÁLOGO OFICIAL DE SERVICIOS
        ══════════════════════════════════════════
        Los ÚNICOS servicios que existen en nuestra plataforma son los
        siguientes. NO inventes ni modifiques ningún nombre:

{catalogo_formateado}

        ══════════════════════════════════════════
        INSTRUCCIONES — FLUJO DE RAZONAMIENTO
        ══════════════════════════════════════════
        Sigue estrictamente estos tres pasos:

        PASO 1 — ANÁLISIS:
        Observa las imágenes (si las hay), lee la descripción y la
        transcripción de audio. Identifica visualmente los daños, síntomas
        o condiciones del vehículo.

        PASO 2 — EXPLICACIÓN (resumen_tecnico):
        Redacta un resumen técnico de máximo 5 líneas explicando:
          • Qué está fallando probablemente en el vehículo.
          • Cuál es la causa más probable.
          • Qué riesgo implica para el conductor.
        Este resumen debe ser comprensible para el cliente y útil para el
        mecánico que atenderá la emergencia.

        PASO 3 — MAPEO DE SERVICIOS (servicios):
        Basándote EXCLUSIVAMENTE en tu análisis del Paso 2, selecciona
        de la lista del CATÁLOGO OFICIAL los servicios que solucionan el
        problema detectado. Puedes seleccionar uno o varios.

        ══════════════════════════════════════════
        REGLAS ESTRICTAS
        ══════════════════════════════════════════
        1. NO inventes nombres de servicios. SOLO puedes usar los nombres
           EXACTOS del catálogo oficial listado arriba.
        2. Si el problema descrito no corresponde a NINGÚN servicio del
           catálogo, devuelve la lista de "servicios" VACÍA: [].
        3. NO inventes información ni especules sin evidencia.
        4. Si la información es muy ambigua, incluye los servicios más
           probables y refleja la incertidumbre en el resumen técnico.

        Define la PRIORIDAD según el riesgo:
        - ALTA: riesgo inmediato (accidente, humo, fuego, vehículo detenido en carretera peligrosa)
        - MEDIA: problema serio pero no crítico inmediato
        - BAJA: problema leve o no urgente

        Define el NIVEL DE GRAVEDAD del daño al vehículo:
        - CRITICO: Pérdida total o daños masivos
        - GRAVE: Daño estructural importante (ej: motor, choque fuerte)
        - MEDIO: Problemas que detienen la marcha pero son solucionables (ej: neumático, batería)
        - LEVE: Raspón, daño estético menor

        Evalúa la CONFIANZA (0.0 a 1.0):
        - 0.0 - 0.4 → información insuficiente o ambigua
        - 0.5 - 0.7 → diagnóstico probable pero no seguro
        - 0.8 - 1.0 → diagnóstico claro y consistente

        ══════════════════════════════════════════
        FORMATO DE RESPUESTA (OBLIGATORIO JSON)
        ══════════════════════════════════════════
        Responde SOLO con este JSON válido:

        {{
            "resumen_tecnico": "...",
            "servicios": ["Nombre Exacto 1", "Nombre Exacto 2"],
            "prioridad": "ALTA" | "MEDIA" | "BAJA",
            "nivel_gravedad": "LEVE" | "MEDIO" | "GRAVE" | "CRITICO",
            "confianza": 0.0
        }}
        """

        contenidos = [prompt]

        # ── Adjuntar TODAS las imágenes disponibles ──────────────
        if rutas_imagenes:
            for ruta in rutas_imagenes:
                if ruta and os.path.exists(ruta):
                    try:
                        imagen_file = genai.upload_file(ruta)
                        contenidos.append(imagen_file)
                    except Exception as e:
                        print(f"Error subiendo imagen '{ruta}': {e}")

        try:
            response = self.model.generate_content(contenidos)
            texto = response.text.strip()
            if texto.startswith("```"):
                texto = texto.replace("```json", "").replace("```", "").strip()
            resultado = json.loads(texto)

            # ── Validar que los servicios devueltos estén en el catálogo ──
            servicios_raw = resultado.get("servicios", [])
            servicios_validados = [
                s for s in servicios_raw if s in CATALOGO_SERVICIOS
            ]

            return {
                "servicios": servicios_validados,
                "prioridad": resultado.get("prioridad", "MEDIA"),
                "nivel_gravedad": resultado.get("nivel_gravedad", "MEDIO"),
                "resumen": resultado.get("resumen_tecnico", "Sin información suficiente"),
                "confianza": float(resultado.get("confianza", 0.0)),
            }
        except Exception as e:
            print(f"Error en Gemini API: {e}")
            return {
                "servicios": [],
                "prioridad": "MEDIA",
                "nivel_gravedad": "MEDIO",
                "resumen": "No se pudo analizar el incidente.",
                "confianza": 0.0,
            }


# 3. EL ORQUESTADOR PRINCIPAL
class AsistenteEmergencia:
    def __init__(self, ai_provider: AIProvider):
        self.transcriptor = TranscriptionService()
        self.ai = ai_provider

    def procesar_sos(
        self,
        descripcion: str,
        ruta_audio: str = None,
        rutas_imagenes: list[str] | None = None,
    ) -> dict:
        texto_audio = ""
        if ruta_audio:
            texto_audio = self.transcriptor.transcribir(ruta_audio)
        diagnostico = self.ai.analizar_incidente(texto_audio, descripcion, rutas_imagenes)
        return diagnostico

# Variable global para importar fácilmente en tu router/endpoint
# Aquí inyectas la dependencia. Si mañana usas OpenAI, cambias esto a OpenAIProvider()
asistente_ia = AsistenteEmergencia(ai_provider=GeminiProvider())