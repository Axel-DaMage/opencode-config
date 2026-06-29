#!/bin/bash
REPO_PATH="$HOME/Documents/Repos/opencode-config"
if [ ! -d "$REPO_PATH" ]; then
  REPO_PATH="$HOME/Documentos/Repos/opencode-config"
fi

# Control de seguridad: Verificar si el repo existe y es un repositorio Git válido
if [ ! -d "$REPO_PATH/.git" ]; then
  exit 0
fi

# Sincronizar excluyendo tokens y archivos temporales
rsync -a --exclude 'antigravity-accounts.json' \
         --exclude '.secrets' \
         --exclude 'auth.json' \
         --exclude 'kv.json' \
         --exclude 'node_modules' \
         ~/.config/opencode/ "$REPO_PATH/"

cd "$REPO_PATH"
git add .
if ! git diff-index --quiet HEAD; then
  git commit -m "chore: auto-update opencode config"
  git push origin master
fi
