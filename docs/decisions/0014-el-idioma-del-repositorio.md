# 0014 — El idioma del repositorio

- Fecha: 2 de septiembre de 2026
- Estado: aceptada el 2 de septiembre de 2026
- Relacionada con: [`PLAN-1.0.md`](../../PLAN-1.0.md), fase `A.3`

## Contexto

Omarchy y su comunidad hablan en inglés. El panel ya es bilingüe, con
selector y `auto` desde el locale. El repositorio, en cambio, nació en
español: las decisiones, el `CHANGELOG`, `SECURITY`, las notas de
publicación, los mensajes de commit y, hasta el 1 de septiembre, el README.

El 1 de septiembre el README se rehízo en inglés, y `test_docs.py` lo vigila.
Eso ya es una decisión tomada de hecho para la puerta de entrada; lo que
faltaba era escribirla y decidir hasta dónde llega.

## Decisión propuesta

**En inglés, lo que lee quien llega de fuera.** Lo que lee quien ya está
dentro se queda en español.

| Documento | Idioma | Por qué |
|---|---|---|
| `README.md` | inglés | Es lo primero que ve cualquiera y lo que decide si instala |
| `SECURITY.md` | inglés | Quien encuentra un problema de seguridad no debería tener que traducir cómo contarlo |
| `CHANGELOG.md` y `docs/RELEASE-NOTES-*.md` | inglés a partir de la 1.0 | Son lo que se enlaza al anunciar una versión. Lo anterior a la 1.0 se queda como está: reescribir historia no la mejora |
| Mensajes de commit | inglés a partir de la 1.0 | Mismo motivo; y el historial anterior no se toca |
| `docs/decisions/` | **español** | Su valor está en el matiz del argumento, y traducirlo lo pierde. Son notas de diseño, no documentación de uso |
| `SPEC.md`, `PLAN-*.md`, `docs/notes/` | **español** | Son el cuaderno de trabajo, no la puerta |
| Comentarios en el código | español | Explican el porqué a quien mantiene, que hoy es una persona; se cambia si cambia eso |
| Cadenas de la interfaz | las dos | Ya lo son, con el inglés como catálogo de referencia |

El README dice en una línea que las decisiones están en español y por qué,
para que nadie lo tome por descuido.

## Lo que se descartó

- **Todo en inglés.** Traducir trece decisiones argumentadas para una
  audiencia que, hoy, no existe. Se puede hacer más tarde si alguien las pide;
  no antes.
- **Todo en español.** Deja fuera a la comunidad a la que el plugin se va a
  proponer, que es la única forma de que lo instale alguien más que su autor.
- **Bilingüe todo.** Dos copias de cada documento son dos documentos que se
  desincronizan. El catálogo de la interfaz ya cuesta mantener alineado, y
  ahí hay un test; aquí no lo habría.

## Consecuencias

- `SECURITY.md` está en inglés desde el mismo día.
- El primer `CHANGELOG` en inglés es el de la 1.0; la sección «Sin publicar»
  actual se traduce al cerrarla.
- `test_docs.py` comprueba que el README y `SECURITY.md` están en inglés.
