#!/bin/zsh
# Doble clic (abre Terminal) o ./guardar-clave-openai.command
# 1) Pide la clave de OpenAI con los caracteres ocultos.
# 2) Valida el prefijo sk- y la guarda en el Llavero de macOS.
# 3) Añade a ~/.zshrc (con copia de seguridad) una función `claude` que lee la clave
#    del Llavero al arrancar y la expone solo a Claude Code y sus integraciones.
# La clave nunca se escribe en archivos, logs ni argumentos de comandos.
set +x
set -u

SERVICIO="OPENAI_API_KEY"
CUENTA="$USER"
ZSHRC="$HOME/.zshrc"
MARCA_INI="# >>> claude-openai-key >>>"
MARCA_FIN="# <<< claude-openai-key <<<"

echo "Clave de OpenAI (se guarda en el Llavero de macOS)."
read -s -r "CLAVE?Pega tu clave (no se verá lo que escribes) y pulsa Enter: "
echo
CLAVE="${CLAVE//[[:space:]]/}"

if [[ "$CLAVE" != sk-* ]] || [[ ! "$CLAVE" =~ '^sk-[A-Za-z0-9_-]+$' ]]; then
  echo "Clave no válida: debe empezar por sk- y no tener caracteres extraños. No se guardó nada."
  unset CLAVE; exit 1
fi

# Llavero: `security -i` evita que la clave aparezca en la lista de procesos.
printf 'add-generic-password -a "%s" -s "%s" -U -w "%s"\n' "$CUENTA" "$SERVICIO" "$CLAVE" | security -i >/dev/null 2>&1 \
  || { echo "No se pudo escribir en el Llavero."; unset CLAVE; exit 1; }
unset CLAVE

# ~/.zshrc: copia de seguridad y bloque idempotente SIN la clave (solo la lee del Llavero).
touch "$ZSHRC"
if ! grep -qF "$MARCA_INI" "$ZSHRC"; then
  cp "$ZSHRC" "$ZSHRC.bak-$(date +%Y%m%d%H%M%S)"
  cat >> "$ZSHRC" <<'BLOQUE'

# >>> claude-openai-key >>>
claude() {
  local k
  k=$(security find-generic-password -a "$USER" -s OPENAI_API_KEY -w 2>/dev/null)
  OPENAI_API_KEY="$k" command claude "$@"
}
# <<< claude-openai-key <<<
BLOQUE
  echo "Función claude añadida a ~/.zshrc (copia de seguridad creada)."
else
  echo "~/.zshrc ya tenía el bloque; no se modificó."
fi

# Verificación: solo longitud y prefijo.
GUARDADA=$(security find-generic-password -a "$CUENTA" -s "$SERVICIO" -w 2>/dev/null)
LONG=${#GUARDADA}
[[ "$GUARDADA" == sk-* ]] && PREF="sí" || PREF="no"
unset GUARDADA
echo "Caracteres: $LONG | Empieza por sk-: $PREF"
echo "Abre una pestaña nueva de Terminal o ejecuta: source ~/.zshrc"
