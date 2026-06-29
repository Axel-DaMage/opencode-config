# OpenCode Global Directives & Checkpoints

## 1. Límites del Sistema y Seguridad (STRICT)
- **Libertad Total en el Workspace:** Tienes autonomía completa para ejecutar comandos bash, instalar dependencias, y gestionar archivos/carpetas **SOLO** dentro del directorio de trabajo actual.
- **Límites Personales:** Esta es una máquina personal. **NUNCA** debes leer, modificar o alterar archivos del sistema operativo (ej. `/etc`, `/usr`, `/var`) ni carpetas personales fuera del proyecto (ej. `~/Documents`, `~/Desktop`, `~/Downloads`). Mantente estrictamente en el marco de trabajo del proyecto.
- **Manejo de Secretos:** Nunca expongas, imprimas en logs o guardes en texto plano variables de entorno o credenciales (protegido por `envsitter` y `log-sanitizer`).

## 2. Control de Versiones (Git)
- **Cero Commits Automáticos:** Puedes usar libremente `git status`, `git diff`, `git log` y `git add` para preparar tu trabajo.
- **Permiso Explícito Requerido:** **NUNCA** ejecutes `git commit` o `git push` sin pedir autorización primero y recibir un "sí" explícito del usuario. 

## 3. Checkpoints de Desarrollo (Quarkus / Java / Cloud)
- **Verificación:** Antes de dar una tarea por terminada, debes asegurarte de que el código compila (ej. `./mvnw compile` o `./gradlew build`) y no hay errores de sintaxis o tipos.
- **Testing:** Ejecuta los tests unitarios relevantes si están disponibles para validar tus cambios.

## 4. Memoria y Contexto
- Al usar `opencode-mem`, registra decisiones de arquitectura importantes de forma manual para futuras sesiones, sin llenar la base de datos con ruido irrelevante.
## 5. Directiva Suprema (Override)
- **Comando Explícito:** Si el usuario ordena EXPLÍCITAMENTE realizar una acción (ej. modificar archivos de sistema, hacer commit/push, alterar fuera del workspace), **debes obedecer inmediatamente y sin excepciones**, asumiendo que el usuario asume los riesgos.
