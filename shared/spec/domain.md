# Especificación del dominio (para replicar en Kotlin)

Fuente de verdad: `ios/Packages/DecoKit/Sources/DecoDomain`. Android implementa lo mismo en un
módulo `domain` en Kotlin puro y corre los casos dorados de `shared/fixtures`.

## Entidades

| Entidad | Campos | Notas |
|---|---|---|
| `Medication` | id, generic, brands[], strengths[], forms[] | Una droga o asociación. Viene de `medicamentos.json`. |
| `TextCandidate` | text, confidence | Una lectura posible del OCR. |
| `NormalizedBox` | x, y, width, height (0…1) | Origen **arriba a la izquierda**. |
| `RecognizedLine` | candidates[] (mejor primero), box? | Un renglón del OCR. |
| `Dosage` | strength?, dose?, everyHours?, days?, boxes? | `summary`: "500 mg · 1 comprimido cada 8 h · 7 días · 2 cajas". |
| `MedicationCandidate` | medication, score, matchedName, isLearned | |
| `Confidence` | low / medium / high | |
| `PrescriptionLine` | id, recognized, candidates[] (sugerencia primero), dosage, confidence? | |
| `PrescriptionReading` | id, createdAt, imageData, medicationLines[], otherLines[], interpretedBy | interpretedBy: onDeviceModel / matchingOnly |
| `LineDecision` | confirmed(medication, dosage) / notAMedication / referToPharmacist | |
| `PrescriptionRecord` | id, createdAt, status, items[], referredTexts[], imageData? | status: confirmed / referredToPharmacist |

## Puertos

- `TextRecognizer.recognizeLines(imageData, customWords) → [RecognizedLine]` (arriba → abajo).
- `MedicationDictionary.allMedications() → [Medication]`.
- `PrescriptionInterpreter.unavailabilityReason() → String?` y
  `chooseMedications(lines) → {lineId: medicationId | null}` (solo IDs de los candidatos).
- `CorrectionStore`: `learnedMedications(key) → {medId: count}`, `recordCorrection(key, medId)`, `learnedKeys(limit)`.
- `HistoryRepository`: save, allRecords, delete(id), deleteRecords(olderThan) → cantidad.
- `Clock.now()`.

## Matching (`MedicationIndex`)

1. **Normalización** (`TextNormalizer`): minúsculas, sin acentos; palabras de nombre = tokens con
   letras, descartando números, unidades y palabras de posología (lista `stopwords`). Dentro de una
   palabra: `0→o`, `1→l`, `5→s`, `4→a`. Variante extra con `rn→m`.
2. **Preselección**: trigramas de `"  " + palabras + " "`; pasan los nombres con ≥ 2 trigramas en
   común (máx. 250).
3. **Puntaje** por nombre (genérico o marca): ventanas de palabras consecutivas del mismo largo que
   el nombre (o todo el renglón si es más corto). Si el nombre tiene varias palabras y la ventana
   también: promedio palabra a palabra ponderado por largo, aceptando abreviatura por prefijo
   (≥ 2 letras) con 0,92. Si no: Jaro-Winkler de las cadenas unidas. Ventanas de < 4 letras o con
   relación de largo fuera de 0,6–1,6 se ignoran.
   `score = sim × (0,9 + 0,05 × palabrasUsadas/palabrasRenglón + 0,05 × palabrasUsadas/palabrasNombre)`.
4. Lecturas alternativas del OCR: −0,01 por posición. Se queda el mejor puntaje por medicamento.
   Umbral 0,84, máximo 5 candidatos. Desempate por id.
5. **Aprendizaje**: clave = palabras de nombre unidas por espacio. Si la clave tiene correcciones,
   ese medicamento entra con `min(0,99, 0,95 + 0,01 × veces)` y `isLearned`.

## Confianza (`ConfidencePolicy`)

alta ≥ 0,93; media ≥ 0,89; si no, baja. Si el segundo candidato está a < 0,03, baja un nivel.
Si el modelo eligió un candidato que no era el primero: como máximo media (y el empate la baja).
Si el modelo dijo "ninguno": baja un nivel.

## Posología (`DosageParser`)

Sobre el texto normalizado; un `l`/`i` suelto delante de una unidad se lee como `1`.
- Concentración: `número (mg|mcg|g|ml|ui|%)` → "500 mg", "100.000 UI".
- Dosis: `(n | n/n | un/una | medio/media) + unidad` → "1 comprimido", "1/2 comprimido", "20 gotas".
- Frecuencia: `N veces por día` → 24/N; `c/N hs` o `cada N horas` (acepta rango `4-6`, toma el
  primero); `por día` → 24.
- Días: `(x|por|durante) N días`. Cajas: `N° N` / `nro N`.
- Si el renglón siguiente no tiene medicamento, completa los campos vacíos con su posología.

## Casos de uso

- `ReadPrescription(image)`: OCR (vocabulario = aprendidas + diccionario) → candidatos + aprendizaje
  → posología → intérprete (máx. 12 renglones; si no está disponible o falla, matching solo).
- `ConfirmReading(reading, decisions, keepImage)`: exige decisión para todos los renglones; guarda
  y registra una corrección por cada lectura OCR distinta de los renglones confirmados.
- `PurgeExpiredHistory(retentionDays)`: rango 1–90, por defecto 30.
- `SearchMedications(query)`: ≥ 3 caracteres, umbral 0,7, máximo 10.
