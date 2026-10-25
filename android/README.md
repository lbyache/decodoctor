# DecoDoctor para Android (plan de paridad)

Todavía no hay código. La app Android replica las capas de iOS (ADR 0001) con Kotlin y Jetpack Compose.

## Módulos

| Módulo | Equivale a | Contenido |
|---|---|---|
| `domain` (Kotlin puro, JVM) | `DecoDomain` | Entidades, puertos, matching, posología, casos de uso. Spec: `shared/spec/domain.md`. |
| `data` | `DecoData` | `medicamentos.json` desde assets (el mismo archivo de `shared/dictionary`), Room para historial y correcciones. |
| `platform` | `DecoPlatform` | ML Kit Text Recognition v2 (OCR), ML Kit GenAI Prompt API / Gemini Nano (intérprete). |
| `app` | `DecoPresentation` + App | Compose, ViewModels, ML Kit Document Scanner, BiometricPrompt, inyección manual. |

## Reglas que se mantienen

- Sin permiso de internet en el manifiesto (`android.permission.INTERNET` ausente).
- El intérprete devuelve JSON que se valida contra los IDs candidatos; cualquier otro valor se descarta.
- Los tests del módulo `domain` leen `shared/fixtures/*.json` y tienen que pasar igual que en iOS.
- `allowBackup="false"` y datos en almacenamiento interno de la app.

## Primeros pasos

1. Proyecto Gradle con los cuatro módulos y `domain` sin dependencias de Android.
2. Portar `TextNormalizer`, `JaroWinkler`, `MedicationIndex`, `DosageParser`, `ConfidencePolicy`
   y hacer pasar los casos dorados.
3. Recién después, plataforma y UI.
