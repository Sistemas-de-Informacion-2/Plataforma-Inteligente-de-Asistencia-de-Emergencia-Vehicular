# backend/app/services/ia_service.py
"""
Servicio: Inteligencia Artificial (Mock).

Simula los módulos de IA que en producción se conectarían a modelos reales.
Cada método retorna datos mock realistas que encajan con DiagnosticoIACreate.

Módulos simulados:
  1. Procesamiento de audio  → transcripción + extracción de palabras clave
  2. Clasificación de imagen → categoría del problema + gravedad
  3. Generación de resumen   → ficha estructurada del incidente
"""

import random
from typing import Any

from app.models.diagnostico_ia import NivelGravedad, Prioridad


#  Catálogos de problemas simulados
CLASIFICACIONES = {
    "bateria": {
        "problema_detectado": "Problema de batería — Vehículo no enciende, posible batería descargada o terminales sulfatados",
        "nivel_gravedad": NivelGravedad.MEDIO,
        "prioridad": Prioridad.MEDIA,
        "costo_estimado_ia": 150.0,
        "palabras_clave": ["batería", "no enciende", "no arranca", "muerta", "descargada", "luces apagadas"],
        "servicio_requerido": "Auxilio eléctrico",
    },
    "llanta": {
        "problema_detectado": "Pinchazo de llanta — Neumático desinflado o reventado, requiere cambio o reparación in situ",
        "nivel_gravedad": NivelGravedad.LEVE,
        "prioridad": Prioridad.MEDIA,
        "costo_estimado_ia": 80.0,
        "palabras_clave": ["llanta", "neumático", "pinchazo", "ponchadura", "desinflado", "rueda"],
        "servicio_requerido": "Cambio de llanta",
    },
    "motor": {
        "problema_detectado": "Falla de motor — Sobrecalentamiento o falla mecánica, se recomienda no intentar encender",
        "nivel_gravedad": NivelGravedad.GRAVE,
        "prioridad": Prioridad.ALTA,
        "costo_estimado_ia": 500.0,
        "palabras_clave": ["motor", "humo", "sobrecalentamiento", "temperatura", "aceite", "ruido"],
        "servicio_requerido": "Mecánica general",
    },
    "choque": {
        "problema_detectado": "Accidente vehicular — Daño por colisión, posible necesidad de grúa y servicio de carrocería",
        "nivel_gravedad": NivelGravedad.CRITICO,
        "prioridad": Prioridad.URGENTE,
        "costo_estimado_ia": 1200.0,
        "palabras_clave": ["choque", "accidente", "colisión", "golpe", "impacto", "abolladura"],
        "servicio_requerido": "Grúa y carrocería",
    },
    "llave": {
        "problema_detectado": "Problema con llaves — Llave perdida o quedó dentro del vehículo, requiere cerrajero automotriz",
        "nivel_gravedad": NivelGravedad.LEVE,
        "prioridad": Prioridad.BAJA,
        "costo_estimado_ia": 100.0,
        "palabras_clave": ["llave", "cerradura", "encerrada", "perdí", "dentro", "trancado"],
        "servicio_requerido": "Cerrajería automotriz",
    },
    "combustible": {
        "problema_detectado": "Sin combustible — Vehículo se quedó sin gasolina/diésel, requiere suministro de emergencia",
        "nivel_gravedad": NivelGravedad.LEVE,
        "prioridad": Prioridad.BAJA,
        "costo_estimado_ia": 60.0,
        "palabras_clave": ["gasolina", "combustible", "diésel", "tanque vacío", "sin nafta"],
        "servicio_requerido": "Suministro de combustible",
    },
    "desconocido": {
        "problema_detectado": "Problema no identificado — La información proporcionada no es suficiente para una clasificación precisa",
        "nivel_gravedad": NivelGravedad.MEDIO,
        "prioridad": Prioridad.MEDIA,
        "costo_estimado_ia": None,
        "palabras_clave": [],
        "servicio_requerido": "Diagnóstico general",
    },
}


class IAService:
    """
    Servicio de IA mock. No requiere sesión de BD.
    En producción, estos métodos llamarían a APIs de ML (Whisper, YOLO, GPT, etc.)
    """

    # ── 1. Procesamiento de Audio ─────────────────────────────

    async def procesar_audio(self, audio_url: str) -> dict[str, Any]:
        """
        Simula la transcripción de audio y extracción de información.

        En producción: Whisper API → transcripción → NLP para extraer keywords.

        Returns:
            {
                "transcripcion": str,
                "palabras_clave": list[str],
                "categoria_detectada": str
            }
        """
        # Simular transcripciones realistas
        transcripciones_mock = [
            {
                "transcripcion": "Hola, mi auto no enciende, creo que se me descargó la batería. "
                                  "Estoy en un estacionamiento y las luces no prenden.",
                "palabras_clave": ["no enciende", "batería", "descargada", "luces"],
                "categoria_detectada": "bateria",
            },
            {
                "transcripcion": "Se me ponchó una llanta en la carretera, estoy en el arcén. "
                                  "El neumático trasero derecho está completamente desinflado.",
                "palabras_clave": ["llanta", "ponchó", "neumático", "desinflado"],
                "categoria_detectada": "llanta",
            },
            {
                "transcripcion": "Mi carro está echando humo del motor, la temperatura subió mucho. "
                                  "Tuve que parar porque se estaba sobrecalentando.",
                "palabras_clave": ["humo", "motor", "temperatura", "sobrecalentamiento"],
                "categoria_detectada": "motor",
            },
            {
                "transcripcion": "Me chocaron por atrás en un semáforo. El otro carro se fue. "
                                  "Tengo el parachoques y la cajuela dañados.",
                "palabras_clave": ["choque", "parachoques", "dañado", "accidente"],
                "categoria_detectada": "choque",
            },
            {
                "transcripcion": "Dejé las llaves dentro del carro y se cerró solo. "
                                  "No puedo abrir las puertas, necesito un cerrajero.",
                "palabras_clave": ["llaves", "dentro", "cerró", "cerrajero"],
                "categoria_detectada": "llave",
            },
        ]

        return random.choice(transcripciones_mock)

    # ── 2. Clasificación de Imagen ────────────────────────────

    async def clasificar_imagen(self, imagen_url: str) -> dict[str, Any]:
        """
        Simula la clasificación de una imagen del vehículo/incidente.

        En producción: modelo de visión artificial (YOLO/ResNet/CLIP)
        que detecta daños visibles y clasifica el tipo de problema.

        Returns:
            {
                "categoria": str,
                "confianza": float,
                "danos_detectados": list[str],
                "descripcion_visual": str
            }
        """
        clasificaciones_mock = [
            {
                "categoria": "bateria",
                "confianza": 0.87,
                "danos_detectados": ["tablero apagado", "luces indicadoras off"],
                "descripcion_visual": "Se observa el tablero del vehículo completamente apagado, "
                                      "indicadores de batería visibles. Posible descarga completa.",
            },
            {
                "categoria": "llanta",
                "confianza": 0.95,
                "danos_detectados": ["neumático desinflado", "posible pinchazo lateral"],
                "descripcion_visual": "Neumático trasero visiblemente desinflado con el vehículo "
                                      "inclinado. Se detecta posible objeto punzante en la banda de rodadura.",
            },
            {
                "categoria": "motor",
                "confianza": 0.78,
                "danos_detectados": ["humo visible", "fuga de líquido"],
                "descripcion_visual": "Se observa humo blanco saliendo del compartimento del motor. "
                                      "Posible fuga de refrigerante o sobrecalentamiento.",
            },
            {
                "categoria": "choque",
                "confianza": 0.92,
                "danos_detectados": [
                    "parachoques deformado",
                    "faro roto",
                    "pintura dañada",
                ],
                "descripcion_visual": "Daño frontal significativo: parachoques desplazado, faro "
                                      "izquierdo fracturado y deformación en el capó.",
            },
        ]

        return random.choice(clasificaciones_mock)

    # ── 3. Generación de Diagnóstico/Resumen ──────────────────

    async def generar_resumen_diagnostico(
        self,
        *,
        descripcion_usuario: str | None = None,
        resultado_audio: dict[str, Any] | None = None,
        resultado_imagen: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """
        Combina la información de todas las fuentes (texto, audio, imagen)
        para generar un diagnóstico estructurado.

        En producción: un LLM (GPT/Gemini) que sintetiza toda la información.

        Returns:
            Diccionario compatible con DiagnosticoIACreate:
            {
                "problema_detectado": str,
                "nivel_gravedad": NivelGravedad,
                "prioridad": Prioridad,
                "costo_estimado_ia": float | None,
            }
        """
        # Determinar la categoría con mejor evidencia disponible
        categoria = self._determinar_categoria(
            descripcion_usuario, resultado_audio, resultado_imagen
        )

        # Obtener datos de la clasificación
        datos = CLASIFICACIONES.get(categoria, CLASIFICACIONES["desconocido"])

        # Enriquecer el problema detectado con datos específicos
        problema = datos["problema_detectado"]

        if resultado_imagen:
            danos = resultado_imagen.get("danos_detectados", [])
            if danos:
                problema += f". Daños visibles: {', '.join(danos)}"

        if resultado_audio and resultado_audio.get("transcripcion"):
            problema += f". Relato del usuario: '{resultado_audio['transcripcion'][:100]}...'"

        # Agregar variación realista al costo
        costo = datos["costo_estimado_ia"]
        if costo is not None:
            variacion = random.uniform(-0.15, 0.25)  # ±15-25% variación
            costo = round(costo * (1 + variacion), 2)

        return {
            "problema_detectado": problema,
            "nivel_gravedad": datos["nivel_gravedad"],
            "prioridad": datos["prioridad"],
            "costo_estimado_ia": costo,
            # Metadata extra para el servicio de asignación
            "_categoria": categoria,
            "_servicio_requerido": datos["servicio_requerido"],
        }

    #  Métodos internos
    def _determinar_categoria(
        self,
        descripcion: str | None,
        resultado_audio: dict | None,
        resultado_imagen: dict | None,
    ) -> str:
        """
        Determina la categoría del problema usando prioridad:
        1. Imagen (más confiable)
        2. Audio (transcripción)
        3. Texto (descripción del usuario)
        4. Desconocido (fallback)
        """
        # 1. Priorizar resultado de imagen por su confianza
        if resultado_imagen and resultado_imagen.get("confianza", 0) > 0.7:
            cat = resultado_imagen.get("categoria")
            if cat in CLASIFICACIONES:
                return cat

        # 2. Usar la categoría detectada del audio
        if resultado_audio:
            cat = resultado_audio.get("categoria_detectada")
            if cat in CLASIFICACIONES:
                return cat

        # 3. Buscar palabras clave en la descripción del usuario
        if descripcion:
            desc_lower = descripcion.lower()
            for categoria, datos in CLASIFICACIONES.items():
                if categoria == "desconocido":
                    continue
                for keyword in datos["palabras_clave"]:
                    if keyword.lower() in desc_lower:
                        return categoria

        # 4. Fallback
        return "desconocido"
