# 0003. Diccionario de medicamentos: ANMAT como fuente, JSON compartido, índice en memoria

## Estado
Accepted (2026-10-25). Hoy se usa una semilla manual; la importación de ANMAT está pendiente.

## Contexto
El matching necesita una lista de medicamentos (droga genérica y marcas comerciales) que funcione
sin red, que se pueda compartir con Android y cuya licencia permita empaquetarla.

## Opciones consideradas
1. **Listado público de ANMAT** (datos abiertos) convertido a JSON propio. Gratis; hay que confirmar
   licencia, columnas y frecuencia de actualización.
2. **Vademécum comercial** (Alfabeta, Kairos): más completo, pago y con licencia restrictiva.
3. **Lista manual**: rápida para arrancar, incompleta.

Formato:
- a. SQLite con FTS5 (trigram): búsqueda rápida, pero FTS5 trigram encuentra **subcadenas exactas**;
  no tolera "amoxicilna" por "amoxicilina", que es justamente el caso de uso.
- b. **JSON + índice de trigramas en memoria en el dominio**: tolera errores, es portable a Kotlin y
  alcanza para decenas de miles de entradas.

## Decisión
Fuente: ANMAT (opción 1), con una **semilla manual** de medicamentos frecuentes mientras tanto
(opción 3 como puente). Formato: JSON (opción b). Esto cambia lo que decía el plan inicial (SQLite
FTS5) por la razón de arriba.

Esquema de `medicamentos.json`:

```json
{
  "version": "semilla-2026-10-25",
  "source": "Semilla manual (provisoria hasta importar ANMAT)",
  "medications": [
    { "id": "amoxicilina", "generic": "Amoxicilina", "brands": ["Amoxidal"],
      "strengths": ["500 mg", "875 mg"], "forms": ["comprimidos", "suspensión"] }
  ]
}
```

Una entrada = una droga (o asociación). La concentración y la posología se leen del texto con el
parser del dominio, no se modelan como entradas distintas.

`shared/dictionary/build_from_anmat.py` (solo biblioteca estándar) convierte el CSV de ANMAT a este
formato agrupando por droga.

## Consecuencias
- Positivas: el mismo archivo sirve a iOS y Android; tolerancia a errores en el dominio, testeable.
- Negativas: el diccionario completo se carga en memoria al iniciar (estimado < 5 MB).
- Riesgos: licencia/columnas del dataset de ANMAT sin confirmar → se verifica antes de empaquetarlo.

## Cumplimiento
- Licencias: no se incluyen datos de vademécums comerciales. Las marcas se usan solo como texto
  de referencia para reconocerlas.

## Referencias
- datos.gob.ar — Vademécum / listado de medicamentos de ANMAT (a confirmar en el spike).
