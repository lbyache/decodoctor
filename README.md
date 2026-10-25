# DecoDoctor

Ayuda a leer recetas médicas manuscritas. Sacás una foto, la app lee el texto **en el teléfono**
(sin internet), lo compara con un diccionario de medicamentos y propone qué dice cada renglón:
medicamento, concentración y posología, con un nivel de confianza. El empleado confirma, corrige o
deriva la receta al farmacéutico. Las correcciones se aprenden localmente.

> DecoDoctor es una ayuda de lectura. **No reemplaza la validación del farmacéutico** ni autoriza
> ninguna dispensa. No es un dispositivo médico ni está validado clínicamente (ver [NOTICE.md](NOTICE.md)).

## Cómo funciona

1. **Foto**: escáner de documentos de VisionKit (recorta y endereza) o una imagen de la galería.
2. **OCR**: Vision (`RecognizeTextRequest`, español) devuelve hasta 5 lecturas posibles por renglón.
3. **Matching**: cada lectura se compara con el diccionario tolerando errores típicos de OCR y de
   letra (índice de trigramas + Jaro-Winkler). Las correcciones previas suben el puntaje.
4. **Interpretación**: si el iPhone tiene Apple Intelligence, el modelo de Foundation Models elige
   entre los candidatos usando el contexto de la receta. Si no, se usa solo el matching.
5. **Revisión**: renglones resaltados sobre la foto, candidatos ordenados, confianza alta/media/baja.

Todo el procesamiento es local. Más detalle en [docs/arch/pipeline.md](docs/arch/pipeline.md).

## Requisitos

- Xcode 26, iOS 26 (iPhone). Foundation Models requiere un iPhone compatible con Apple Intelligence;
  sin él, la app funciona igual con matching solamente.
- Sin dependencias de terceros.

## Estructura

```
ios/                  App iOS (proyecto Xcode + paquete DecoKit con una capa por target)
shared/dictionary/    Diccionario de medicamentos (JSON) y script de importación ANMAT
shared/fixtures/      Casos dorados compartidos entre iOS y Android
shared/spec/          Especificación del dominio para replicar en Kotlin
android/              Plan de paridad para Android
docs/arch/            Pipeline y decisiones de arquitectura (ADRs)
```

Comandos de build y tests en [AGENTS.md](AGENTS.md).

## Estado

MVP en desarrollo. El diccionario actual es una **semilla manual** de medicamentos frecuentes;
falta importar el listado de ANMAT (ver [TODO.md](TODO.md) y el ADR 0003).

## Contribuir

Issues y pull requests son bienvenidos. Antes de proponer un cambio grande, mirá los ADRs en
`docs/arch/decisions/`. **Nunca subas fotos de recetas reales** ni datos de pacientes: para
ejemplos, usá recetas inventadas.

## Licencia

[MIT](LICENSE). Avisos médicos, de marcas y de datos en [NOTICE.md](NOTICE.md).
