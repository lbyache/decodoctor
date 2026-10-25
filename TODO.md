# TODO — DecoDoctor

## En progreso

- [ ] Spike con recetas reales: juntar 10–20 fotos **anonimizadas** (fuera del repo) y medir top‑1 / top‑5 por renglón, con y sin `customWords` (ADR 0002).

## Por hacer

- [ ] Descargar el listado de medicamentos de ANMAT (datos.gob.ar), confirmar licencia y columnas, y regenerar `medicamentos.json` con `build_from_anmat.py` (ADR 0003).
- [ ] Recalibrar umbrales de `ConfidencePolicy` y `MedicationIndex.candidateThreshold` con los datos del spike.
- [ ] Posología: leer la concentración sin unidad pegada al nombre ("Ibupirac 600" → 600 mg) usando `Medication.strengths`.
- [ ] Probar en iPhone real: escáner de VisionKit y Foundation Models en el dispositivo.
- [ ] Ícono de la app.
- [ ] Linter y formatter (swift-format) y CI (`swift test` + build).
- [ ] LICENSE (elegir licencia).
- [ ] Tests de ViewModels (`ReviewViewModel`: atajo de confianza alta, guardado con renglones sin decidir).
- [ ] Android: módulo `domain` en Kotlin que pase `shared/fixtures` (ver `android/README.md`).

## Hecho

- [x] ADRs 0001–0003, pipeline y spec del dominio para Android.
- [x] Dominio: matching tolerante a errores, posología, confianza, casos de uso; casos dorados compartidos.
- [x] Data: diccionario semilla (80 medicamentos), historial y correcciones en SwiftData sin CloudKit.
- [x] Platform: Vision (`RecognizeTextRequest`) y Foundation Models con esquema dinámico restringido.
- [x] UI: escanear / elegir foto, revisión con resaltado y confianza, búsqueda manual, historial, ajustes, Face ID opcional, borrado automático.
- [x] Verificado en simulador con una receta sintética en letra manuscrita.
