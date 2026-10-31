# Kuber — bash dressing: a corp-terminal prompt + a login banner.
#
# Sourced from ~/.bashrc (which is NOT in the repo):
#     [[ -f ~/.config/bash/kuber.bash ]] && . ~/.config/bash/kuber.bash
#
# Interactive shells only. Set KUBER_BANNER=0 in the environment to suppress
# the banner (the prompt stays). Remove the source line in ~/.bashrc to drop
# the whole thing.

case $- in *i*) ;; *) return ;; esac   # interactive only

# ---- palette (mirrors hypr/colors.lua) -----------------------------------
#   ink e8e8ec · ink-dim 7d7d87 · faint 35353d · accent c81e2c
_p_ink='\[\e[38;2;232;232;236m\]'
_p_dim='\[\e[38;2;125;125;135m\]'
_p_fnt='\[\e[38;2;53;53;61m\]'
_p_acc='\[\e[38;2;200;30;44m\]'
_p_rst='\[\e[0m\]'
_b_ink=$'\e[38;2;232;232;236m'
_b_dim=$'\e[38;2;125;125;135m'
_b_fnt=$'\e[38;2;53;53;61m'
_b_acc=$'\e[38;2;200;30;44m'
_b_rst=$'\e[0m'

# ---- prompt -------------------------------------------------------------
#   ┌─ user@host · ~/path · a1b2c3d*            ✕ N
#   └▸
_kb_prompt() {
  local code=$?

  local rev='' hash
  hash=$(git rev-parse --short=7 HEAD 2>/dev/null) || hash=''
  if [[ -n $hash ]]; then
    local dirty=''
    git diff --quiet --ignore-submodules HEAD 2>/dev/null || dirty='*'
    rev=" ${_p_fnt}·${_p_rst} ${_p_dim}${hash}${_p_acc}${dirty}${_p_rst}"
  fi

  local err=''
  (( code )) && err="   ${_p_acc}✕ ${_p_dim}${code}${_p_rst}"

  PS1="${_p_fnt}┌─${_p_rst} ${_p_dim}\\u${_p_fnt}@${_p_dim}\\h${_p_rst} ${_p_fnt}·${_p_rst} ${_p_ink}\\w${_p_rst}${rev}${err}"$'\n'"${_p_fnt}└${_p_acc}▸${_p_rst} "
}
PROMPT_COMMAND=_kb_prompt

# ---- login banner ----------------------------------------------------
_kb_banner() {
  [[ ${KUBER_BANNER:-1} == 0 ]] && return
  [[ -t 1 ]] || return
  case $(ps -o comm= -p "${PPID:-0}" 2>/dev/null) in
    *sh|zsh|fish|nu|xonsh) return ;;
  esac

  local rule; printf -v rule '%s╶%s╸%s' "$_b_fnt" "$(printf '─%.0s' {1..54})" "$_b_rst"
  local kern host date
  kern=$(uname -r); host=$(uname -n)
  printf -v date '%(%Y-%m-%d %H:%M)T' -1

  printf '\n %s\n' "$rule"
  printf ' %sK U B E R%s  %s·%s SESSION%19s%sCORP-01%s\n' \
    "$_b_ink" "$_b_rst" "$_b_acc" "$_b_rst" '' "$_b_acc" "$_b_rst"
  printf ' %shost%s   %-20s %skernel%s  %s\n' "$_b_dim" "$_b_rst" "$host" "$_b_dim" "$_b_rst" "$kern"
  printf ' %suser%s   %-20s %sclock%s   %s\n'  "$_b_dim" "$_b_rst" "$USER" "$_b_dim" "$_b_rst" "$date"
  printf ' %s\n\n' "$rule"
}
_kb_banner
