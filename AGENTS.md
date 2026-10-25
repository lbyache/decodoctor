# AGENTS.md — DecoDoctor

App para descifrar recetas médicas manuscritas: foto → lectura en el dispositivo → medicamentos
sugeridos con nivel de confianza → confirmación humana. Público principal: empleados de farmacia.
iOS primero (Swift/SwiftUI); Android nativo después, con las mismas capas.
Si tu workspace tiene un `AGENTS.md` global, este archivo gana sobre él.

## Commands

```bash
# Tests de dominio y datos (rápido, sin simulador; corre en macOS)
cd ios/Packages/DecoKit && swift test

# Build de la app para simulador
xcodebuild -project ios/DecoDoctor.xcodeproj -scheme DecoDoctor \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath .build/DerivedData build

# Tests en el simulador (esquema del paquete: el esquema de la app no ve los tests del paquete local)
cd ios/Packages/DecoKit && xcodebuild -scheme DecoKit-Package \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath ../../../.build/DerivedData-pkg test

# Regenerar el diccionario desde el CSV de ANMAT y copiarlo al paquete
python3 -I shared/dictionary/build_from_anmat.py <csv> shared/dictionary/medicamentos.json
cp shared/dictionary/medicamentos.json ios/Packages/DecoKit/Sources/DecoData/Resources/
```

Lint: todavía no hay SwiftLint ni swift-format (pendiente en `TODO.md`).
Antes de dar por terminada una tarea que toque `.swift`, correr el subagente `verificador-swift`.

## Architecture

Clean architecture + MVVM. Un paquete local (`ios/Packages/DecoKit`) con un target por capa;
el compilador hace cumplir la regla de dependencias:

- `DecoDomain`: Swift puro (solo Foundation). Entidades, puertos, casos de uso y el motor de
  matching (normalización, índice de trigramas, Jaro-Winkler, parser de posología). Portable a Kotlin.
- `DecoData`: diccionario JSON incluido en el bundle; historial y correcciones en SwiftData
  (`cloudKitDatabase: .none`). Los `@Model` no salen de esta capa.
- `DecoPlatform`: adaptadores de Apple: Vision (`RecognizeTextRequest`) y Foundation Models
  (esquema dinámico que solo deja elegir entre candidatos).
- `DecoPresentation`: SwiftUI + ViewModels `@Observable @MainActor`. Depende solo de Domain.
- App (`ios/App/`): composition root (`AppContainer`). Único lugar que conoce todas las capas.

Pipeline y equivalencias Android en `docs/arch/pipeline.md`. Decisiones en `docs/arch/decisions/`.

## Reglas específicas

- **La IA sugiere, nunca decide.** Toda lectura pasa por confirmación humana y el aviso de
  "lo valida un profesional" no se quita. El modelo solo puede elegir IDs que ya propuso el matching
  (`ReadPrescription` descarta cualquier otro).
- **Sin red.** La app no hace pedidos de red ni lleva analytics: la receta es dato de salud
  (Ley 25.326). Nada de iCloud/CloudKit. El entitlement `default-data-protection` se mantiene.
- **Diccionario compartido:** la fuente es `shared/dictionary/medicamentos.json`; la copia en
  `DecoData/Resources` tiene que ser idéntica (lo verifica `DictionarySyncTests`).
- **Casos dorados:** `shared/fixtures/*.json` los corre iOS (`GoldenFixtureTests`) y los va a correr
  Android. Si cambia el matching, se actualizan los fixtures, no se los saltea.
- **Fotos de recetas reales:** nunca al repo. Para pruebas, solo imágenes anonimizadas fuera del repo.
