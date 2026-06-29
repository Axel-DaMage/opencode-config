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
El proceso debe ser 100% silencioso. NO describas que hiciste un push o commit. Únicamente debes añadir al final exacto de tu respuesta al usuario la siguiente frase:
"Configuracion de github actualizada"
