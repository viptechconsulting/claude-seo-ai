#!/bin/zsh
# Guarda OPENAI_API_KEY en el Llavero de macOS (nunca en texto plano) e instala
# el lanzador `con-openai`, que la inyecta solo en el proceso que ejecutes.
# No modifica settings.json ni ningún archivo de configuración.
set +x
set -u

SERVICIO="OPENAI_API_KEY"
CUENTA="$USER"
BIN_DIR="$HOME/.local/bin"
LANZADOR="$BIN_DIR/con-openai"

# 1) Diálogo nativo con campo oculto, al frente.
CLAVE=$(osascript <<'APPLESCRIPT' 2>/dev/null
tell application "System Events" to activate
set r to display dialog "Pega tu clave de OpenAI (empieza por sk-):" with title "Clave de OpenAI" default answer "" with hidden answer buttons {"Cancelar", "Guardar"} default button "Guardar" cancel button "Cancelar" with icon note
return text returned of r
APPLESCRIPT
) || { echo "Cancelado. No se guardó nada."; exit 1; }

CLAVE="${CLAVE//[[:space:]]/}"

# 2) Validación: prefijo sk- y solo caracteres típicos de una clave.
if [[ "$CLAVE" != sk-* ]] || [[ ! "$CLAVE" =~ '^sk-[A-Za-z0-9_-]+$' ]]; then
  osascript -e 'display alert "Clave no válida" message "Debe empezar por sk- y no contener caracteres extraños. No se guardó nada." as critical' >/dev/null 2>&1
  echo "Clave no válida (no empieza por sk- o tiene caracteres extraños). No se guardó nada."
  exit 1
fi

# 3) Llavero. Se usa `security -i` para que la clave no aparezca en la lista de procesos.
printf 'add-generic-password -a "%s" -s "%s" -U -w "%s"\n' "$CUENTA" "$SERVICIO" "$CLAVE" | security -i >/dev/null 2>&1 \
  || { echo "No se pudo escribir en el Llavero."; exit 1; }

# 4) Lanzador: lee la clave del Llavero y la expone solo al comando que ejecutes.
mkdir -p "$BIN_DIR"
cat > "$LANZADOR" <<'LANZ'
#!/bin/zsh
# Uso: con-openai claude   |   con-openai <cualquier comando que necesite OPENAI_API_KEY>
[[ $# -gt 0 ]] || { echo "Uso: con-openai <comando> [args]"; exit 2; }
KEY=$(security find-generic-password -a "$USER" -s OPENAI_API_KEY -w 2>/dev/null) \
  || { echo "No hay clave en el Llavero. Ejecuta guardar-clave-openai.command"; exit 1; }
OPENAI_API_KEY="$KEY" exec "$@"
LANZ
chmod 700 "$LANZADOR"

# 5) Verificación: solo longitud y prefijo.
GUARDADA=$(security find-generic-password -a "$CUENTA" -s "$SERVICIO" -w 2>/dev/null)
LONG=${#GUARDADA}
[[ "$GUARDADA" == sk-* ]] && PREF="sí" || PREF="no"
unset CLAVE GUARDADA

echo "Caracteres: $LONG | Empieza por sk-: $PREF"
echo "Lanzador instalado en $LANZADOR"
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "Añade ~/.local/bin a tu PATH:  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
fi
