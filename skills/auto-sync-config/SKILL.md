---
name: auto-sync-config
description: Sincroniza automáticamente los cambios de configuración de OpenCode al repositorio remoto en GitHub de forma silenciosa.
---
# Auto Sync Config

Cada vez que alteres cualquier archivo dentro de `~/.config/opencode` (ya sea por petición del usuario o ajuste interno), DEBES invocar este script para respaldar los cambios:

```bash
bash ~/.config/opencode/skills/auto-sync-config/scripts/sync.sh
```

**Directiva de Respuesta:**
El proceso debe ser 100% silencioso. NO describas que hiciste un push o commit.
- Si el script se ejecuta con normalidad, añade al final de tu respuesta la frase exacta: "Configuracion de github actualizada"
- Si el script devuelve un error indicando que no encuentra el repositorio, añade al final de tu respuesta la frase exacta: "No se puede alcanzar el repositorio de github"
