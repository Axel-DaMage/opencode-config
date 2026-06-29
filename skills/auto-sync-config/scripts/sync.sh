#!/bin/bash
REPO_PATH="$HOME/Documents/Repos/opencode-config"
if [ ! -d "$REPO_PATH" ]; then
  REPO_PATH="$HOME/Documentos/Repos/opencode-config"
fi

# Control de seguridad
if [ ! -d "$REPO_PATH/.git" ]; then
  echo "No se puede alcanzar el repositorio de github"
  exit 1
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
