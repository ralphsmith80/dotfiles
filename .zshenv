export VOLTA_HOME="$HOME/.volta"
# Cursor/VS Code + Volta: shims can resolve argv0 to the IDE AppImage (volta-cli/volta#2031).
# Workspace terminal.integrated.env is not always applied (agent terminal, some profiles), so detect
# the IDE from env that child shells inherit: VSCODE_IPC_HOOK, CURSOR_TRACE_ID, VSCODE_INJECTION, etc.
# Opt out: export VOLTA_DISABLE_CURSOR_FIX=1
_VOLTA_USE_REAL=0
if [[ -z "${VOLTA_DISABLE_CURSOR_FIX:-}" ]]; then
	if [[ -n "${VOLTA_USE_REAL_BINARIES:-}" || -n "${VSCODE_INJECTION:-}" || -n "${CURSOR_TRACE_ID:-}" || -n "${VSCODE_IPC_HOOK:-}" || "${TERM_PROGRAM:-}" == "vscode" ]]; then
		_VOLTA_USE_REAL=1
	fi
fi
if [[ "$_VOLTA_USE_REAL" -eq 1 ]]; then
	_NODE_VER=$(grep -o '"runtime": "[^"]*"' "$VOLTA_HOME/tools/user/platform.json" 2>/dev/null | head -1 | cut -d'"' -f4)
	[[ -z "$_NODE_VER" || "$_NODE_VER" == "null" ]] && _NODE_VER="24.12.0"
	_VOLTA_NODE_BIN="${VOLTA_HOME}/tools/image/node/${_NODE_VER}/bin"
	_VOLTA_PNPM_BIN="${VOLTA_HOME}/tools/image/packages/pnpm/bin"
	if [[ -x "${_VOLTA_NODE_BIN}/node" ]]; then
		export PATH="${_VOLTA_NODE_BIN}:${_VOLTA_PNPM_BIN}:${VOLTA_HOME}/bin:${PATH}"
	else
		export PATH="${VOLTA_HOME}/bin:${PATH}"
	fi
	unset _NODE_VER _VOLTA_NODE_BIN _VOLTA_PNPM_BIN
else
	export PATH="${VOLTA_HOME}/bin:${PATH}"
fi
unset _VOLTA_USE_REAL
