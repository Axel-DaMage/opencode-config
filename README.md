# OpenCode Configuration

![OpenCode](https://img.shields.io/badge/OpenCode-v1.15%2B-blue?style=for-the-badge)
![Java](https://img.shields.io/badge/Java-Optimized-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white)
![Quarkus](https://img.shields.io/badge/Quarkus-Ready-4695EB?style=for-the-badge&logo=quarkus&logoColor=white)
![Cloud Native](https://img.shields.io/badge/Cloud_Native-AWS_%7C_GCP-232F3E?style=for-the-badge&logo=amazonwebservices&logoColor=white)
![Security](https://img.shields.io/badge/Security-Hardened-green?style=for-the-badge&logo=shield&logoColor=white)

Configuración avanzada y balanceada para OpenCode, ajustada para desarrollo backend, DevOps y arquitecturas Cloud-Native (AWS/GCP).

## Capacidades Base

- **74+ Agent Skills:** Instrucciones modulares para Java, Quarkus, Terraform, Kubernetes, Docker, diseño de APIs y QA.
- **Servidores MCP:** 
  - `Context7`: Documentación viva y actualizada.
  - `gh_grep`: Búsqueda nativa de código en repositorios.
  - `Sequential Thinking`: Razonamiento lógico extendido para problemas complejos.
  - `Playwright`: Automatización de navegadores.
- **Seguridad Activa:**
  - Prevención de fuga de credenciales (`envsitter`, `log-sanitizer`).
  - Prohibición estricta de commits o push sin autorización previa.
  - Aislamiento absoluto en el directorio de trabajo asignado.
- **Rendimiento:**
  - Límite de compactación de contexto a 64K tokens para mantener baja latencia.
  - Gestión de memoria manual (`opencode-mem`).

## Estructura del Repositorio

| Archivo o Directorio | Propósito |
|----------------------|-----------|
| `AGENTS.md` | Directivas maestras, límites de sistema y puntos de control obligatorios. |
| `opencode.json` | Configuración de modelos (NVIDIA, Google), plugins y servidores MCP. |
| `tui.json` | Atajos de teclado y parámetros de la interfaz de terminal. |
| `/skills/` | Base de conocimientos y habilidades cargables bajo demanda. |
| `/commands/` | Flujos de trabajo estructurados (descubrimiento, planificación, ejecución). |

---
*Respaldado y sincronizado de forma controlada.*
