#!/bin/zsh
# Pide la contraseña de aplicación de WordPress (oculta), la guarda en el Llavero
# y registra el MCP de Elementor en Claude Code SIN escribir la contraseña en ningún archivo.
# ~/.claude.json solo contendrá la referencia ${WP_ELEMENTOR_BASIC_AUTH}; el valor se lee
# del Llavero al lanzar `claude` (función en ~/.zshrc, con copia de seguridad previa).
set +x
set -u

NOMBRE="palegreen-ibis-818513-hostingersite-com-elementor"
URL="https://palegreen-ibis-818513.hostingersite.com/wp-json/elementor/mcp/"
USUARIO="admin"
SERVICIO="WP_ELEMENTOR_BASIC_AUTH"
ZSHRC="$HOME/.zshrc"
MARCA_INI="# >>> claude-openai-key >>>"
MARCA_FIN="# <<< claude-openai-key <<<"

read -s -r "PASS?Pega la contraseña de aplicación NUEVA de WordPress (oculta) y pulsa Enter: "
echo
PASS="${PASS//[[:space:]]/}"
if (( ${#PASS} < 20 )); then
  echo "La contraseña parece demasiado corta (WordPress genera 24 caracteres). No se guardó nada."
  unset PASS; exit 1
fi

# Basic auth en base64, sin pasar la contraseña como argumento de ningún comando externo.
AUTH=$(printf '%s' "$USUARIO:$PASS" | base64 | tr -d '\n')
unset PASS

printf 'add-generic-password -a "%s" -s "%s" -U -w "%s"\n' "$USER" "$SERVICIO" "$AUTH" | security -i >/dev/null 2>&1 \
  || { echo "No se pudo escribir en el Llavero."; unset AUTH; exit 1; }
unset AUTH

# Reescribe el bloque de ~/.zshrc para que la función claude lea las dos claves del Llavero.
touch "$ZSHRC"
cp "$ZSHRC" "$ZSHRC.bak-$(date +%Y%m%d%H%M%S)"
if grep -qF "$MARCA_INI" "$ZSHRC"; then
  sed -i '' "/$MARCA_INI/,/$MARCA_FIN/d" "$ZSHRC"
fi
cat >> "$ZSHRC" <<'BLOQUE'
# >>> claude-openai-key >>>
claude() {
  local k w
  k=$(security find-generic-password -a "$USER" -s OPENAI_API_KEY -w 2>/dev/null)
  w=$(security find-generic-password -a "$USER" -s WP_ELEMENTOR_BASIC_AUTH -w 2>/dev/null)
  OPENAI_API_KEY="$k" WP_ELEMENTOR_BASIC_AUTH="$w" command claude "$@"
}
# <<< claude-openai-key <<<
BLOQUE
source "$ZSHRC" 2>/dev/null

# Registra el MCP (ámbito usuario) con referencia a la variable, no al valor.
command claude mcp remove "$NOMBRE" -s user >/dev/null 2>&1
command claude mcp add-json -s user "$NOMBRE" \
  '{"type":"http","url":"'"$URL"'","headers":{"Authorization":"Basic ${WP_ELEMENTOR_BASIC_AUTH}"}}' \
  || { echo "No se pudo registrar el MCP."; exit 1; }

echo "Guardado en el Llavero y MCP registrado: $NOMBRE"
echo "Abre una pestaña nueva de Terminal y ejecuta: claude mcp list"
