# 0002. Reconocimiento en el dispositivo: Vision + matching + Foundation Models restringido

## Estado
Accepted (2026-10-25). Pendiente el spike con fotos reales (ver "Validación pendiente").

## Contexto
La letra de médico es el peor caso para un OCR. Un modelo de lenguaje solo, mirando texto mal leído,
tiende a "completar" con un medicamento plausible pero equivocado: inaceptable en farmacia.
Necesitamos lecturas útiles, con confianza honesta, sin red.

## Opciones consideradas
1. **OCR genérico + diccionario + LLM restringido** (elegida): Vision lee, el dominio busca en el
   diccionario con tolerancia a errores, y Foundation Models solo elige entre esos candidatos.
2. **LLM libre sobre el texto OCR**: más flexible, pero puede inventar medicamentos.
3. **Modelo Core ML propio de escritura médica**: lo más preciso a futuro, pero requiere un dataset
   etiquetado de recetas reales que hoy no existe (y que plantea problemas de privacidad).

## Decisión
Opción 1:
- **OCR**: `RecognizeTextRequest` (`.accurate`, `es-AR`/`es`, corrección de idioma activada,
  `customWords` = nombres del diccionario + palabras aprendidas), con `topCandidates(5)` por renglón.
- **Matching** (dominio puro): normalización (minúsculas, sin acentos, confusiones de OCR como
  `0→o`, `1→l`, `rn→m`), índice de trigramas para preseleccionar y Jaro-Winkler por ventana de
  palabras para puntuar contra nombre genérico y marcas. Las correcciones confirmadas suben el
  puntaje (aprendizaje local). Umbral para proponer un candidato: 0,84. Confianza: alta ≥ 0,93, media ≥ 0,89,
  baja por debajo; si los dos mejores candidatos están a menos de 0,03, baja un nivel (ambigüedad).
  Valores calibrados con `shared/fixtures` y una receta sintética; se recalibran con el spike.
- **Interpretación**: Foundation Models con un `DynamicGenerationSchema` armado por receta donde cada
  renglón es un `anyOf` de los IDs candidatos + `"ninguno"`. El modelo **no puede** devolver un ID que
  no esté en la lista, y el caso de uso igual lo valida. Si el modelo no está disponible
  (`deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady`, idioma no soportado) o falla,
  se usa el resultado del matching. El usuario ve cuál de los dos se usó.

## Consecuencias
- Positivas: funciona en cualquier iPhone con iOS 26; nunca propone algo fuera del diccionario;
  mejora con el uso.
- Negativas: si el medicamento no está en el diccionario, no se sugiere (se puede buscar a mano).
  La calidad depende del OCR de manuscrito de Vision, que no está pensado para letra médica.
- Riesgos: ventana de contexto del modelo (≈4k tokens) → se mandan como máximo 12 renglones y
  5 candidatos por renglón.

## Validación pendiente (spike)
- Medir con 10–20 fotos reales **anonimizadas** el porcentaje de renglones donde el medicamento
  correcto queda en el top‑1 y en el top‑5, con y sin `customWords`.
- Confirmar `supportedRecognitionLanguages` para manuscrito en español en el dispositivo.
- Si el top‑5 queda por debajo del 60 %, evaluar la opción 3 (Core ML propio) en un ADR nuevo.

## Cumplimiento
- Seguridad: entrada del modelo acotada al texto OCR y a nombres del diccionario; sin datos del paciente.
- Calidad: confianza visible y confirmación humana obligatoria.
- Normativa: procesamiento local (Ley 25.326).

## Referencias
- Vision `RecognizeTextRequest`, FoundationModels `LanguageModelSession`, `DynamicGenerationSchema`.
