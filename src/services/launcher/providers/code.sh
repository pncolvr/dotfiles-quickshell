#!/usr/bin/env bash

WORKSPACE=$(dirname "${BASH_SOURCE[0]:-0}")/_common
source "$WORKSPACE"/utils.sh

PROJECTS_JSON="${XDG_CACHE_HOME:-$HOME/.cache}/code_projects_${USER}.json"

function pick() {
  bash "$PICKER_LAUNCHER" --dmenu -sort -p ""
}

function pick_path() {
  local ignored_category="$1"
  local project_name project_list
  project_list=$(get_project_names "$ignored_category")
  project_name=$(printf "%s\n" "$project_list" | sort | tr '[:upper:]' '[:lower:]' | pick)
  [ -z "$project_name" ] && exit 0
  grep -Fxqi "$project_name" <<< "$project_list" || exit
  local workspaces
  workspaces=$(get_workspaces "$project_name")
  if [ "$workspaces" = "[]" ]; then
    get_project_path "$project_name"
  else
    local workspace_names
    local workspace_name
    workspace_names=$(jq -r '[.[] | .name] | sort | .[]' <<< "${workspaces[@]}")

    if [[ -z "$workspace_names" ]]; then
      get_project_path "$project_name"
      return
    fi

    workspace_name=$(printf "%s\nOpen folder\n" "${workspace_names[@]}" | pick)
    if [ "$workspace_name" = "Open folder" ]; then
      get_project_path "$project_name"
    else
      jq -r --arg workspace_name "$workspace_name" \
        '.[] | select(.name==$workspace_name) | .path' <<< "${workspaces[@]}"
    fi
  fi
}

function get_project_category_by_path() {
  local path="$1"
  jq -r --arg path "$path" \
    '.[] | select(.rootPath == $path) | .category' "$PROJECTS_JSON"
}

function get_project_names() {
  local ignored_category="${1:-}"

  if [[ -z "$ignored_category" ]]; then
    jq -r '.[] | .name' "$PROJECTS_JSON"
    return
  fi

  jq -r --arg ignored_category "$ignored_category" \
    '.[] | select(.category != $ignored_category) | .name' "$PROJECTS_JSON"
}

function get_workspaces() {
  get_project_property "$1" "workspaces"
}

function get_project_path() {
  get_project_property "$1" "rootPath"
}

function get_project_property() {
  local project_name="$1"
  local property="$2"
  jq -r --arg project_name "$project_name" --arg property "$property" \
    '.[] | select((.name | ascii_downcase) == ($project_name | ascii_downcase)) | .[$property]' "$PROJECTS_JSON"
}

function get_friendly_name() {
  local path="$1"
  if [ -d "$path" ]; then
      basename "$path"
  else
      echo "$path" | xargs realpath | xargs dirname | xargs basename
  fi
}

function get_window_address() {
  hyprctl clients -j | \
   jq -r --arg title "$1" \
    '[.[] | select(.class=="code" and (.title | startswith($title)))] | .[0].address // ""'
}

function focus_window() {
  hyprctl dispatch 'hl.dsp.focus({ window = "address:'$1'" })'
}

function open_editor() {
  local path="$1"
  local profile="${2^}"
  hyprctl dispatch 'hl.dsp.focus({ window = "class:code" })'
  code "$1" --profile "$profile" & disown
}

function main() {
  local ignored_category
  ignored_category=$(get_ignored_category)
  local path
  local friendly_name
  local window_address
  path=$(pick_path "$ignored_category")

  [[ -z "$path" ]] && exit 0
  friendly_name=$(get_friendly_name "$path")
  window_address=$(get_window_address "$friendly_name")

  if [[ -n "$window_address" ]]; then
    focus_window "$window_address"
  else
    local category
    category=$(get_project_category_by_path "$path")
    open_editor "$path" "$category"
  fi
}

main "$@"
