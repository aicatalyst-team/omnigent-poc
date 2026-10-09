#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="${WORKSPACE:-omnigent}"
clean=false

while (($#)); do
  case "$1" in
    --clean)
      clean=true
      ;;
    -h|--help)
      printf 'Usage: %s [--clean]\n' "${0##*/}"
      printf '  --clean  Delete existing providers for these profile types, then delete the profiles.\n'
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\nUsage: %s [--clean]\n' "$1" "${0##*/}" >&2
      exit 2
      ;;
  esac
  shift
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
profiles_dir="${script_dir}/../profiles"

# Read each credential's env_vars alternatives from its profile and select the
# first one available in this process's environment. Do this before making any
# OpenShell changes.
profile_credentials=()
missing_env_groups=()

read_profile_credentials() {
  local profile_file=$1
  local groups group env_var selected
  local -a env_candidates

  profile_credentials=()
  missing_env_groups=()

  groups=$(awk '
    /^credentials:[[:space:]]*$/ { in_credentials = 1; next }
    in_credentials && /^[^[:space:]#][^:]*:/ { in_credentials = 0 }
    in_credentials && /^[[:space:]]+env_vars:[[:space:]]*\[/ {
      line = $0
      sub(/^[^[]*\[/, "", line)
      sub(/\].*$/, "", line)
      print line
    }
  ' "$profile_file")

  [[ -n $groups ]] || return 0

  while IFS= read -r group; do
    selected=
    IFS=, read -r -a env_candidates <<< "$group"
    for env_var in "${env_candidates[@]}"; do
      env_var="${env_var//[[:space:]]/}"
      if [[ ! $env_var =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        printf 'Invalid environment variable name in %s: %s\n' "$profile_file" "$env_var" >&2
        exit 1
      fi
      if [[ -n ${!env_var:-} ]]; then
        selected=$env_var
        break
      fi
    done

    if [[ -n $selected ]]; then
      profile_credentials+=("$selected")
    else
      missing_env_groups+=("$group")
    fi
  done <<< "$groups"
}

profiles=()
all_profiles=()
skipped_profiles=()

shopt -s nullglob
profile_files=("${profiles_dir}"/*.yaml)
for profile_file in "${profile_files[@]}"; do
  profile=${profile_file##*/}
  profile=${profile%.yaml}
  all_profiles+=("$profile")
  read_profile_credentials "$profile_file"

  if ((${#missing_env_groups[@]})); then
    skipped_profiles+=("${profile} (missing one of: ${missing_env_groups[*]})")
  else
    profiles+=("$profile")
  fi
done

if ((${#skipped_profiles[@]})); then
  printf 'Skipping profiles without credentials:\n'
  printf '  - %s\n' "${skipped_profiles[@]}"
fi

if ((${#profiles[@]})) && [[ -z ${USER:-} ]]; then
  printf 'USER is not set; cannot synthesize provider names.\n' >&2
  exit 1
fi

if [[ $clean == false ]] && ((${#profiles[@]} == 0)); then
  printf 'No profiles have all their required credentials; there are no profiles to load.\n'
  exit 0
fi

if ((${#all_profiles[@]} == 0)); then
  printf 'No profile files found in %s.\n' "$profiles_dir"
  exit 0
fi

if ! command -v openshell >/dev/null 2>&1; then
  printf 'openshell was not found on PATH. Install it and run this script again.\n' >&2
  exit 1
fi

if $clean; then
  if ! command -v python3 >/dev/null 2>&1; then
    printf 'python3 is required to clean existing OpenShell resources.\n' >&2
    exit 1
  fi

  printf 'Finding providers for profile types in workspace %s...\n' "$WORKSPACE"
  if ! providers_to_delete=$(python3 -c '
import json
import subprocess
import sys

workspace = sys.argv[1]
profile_types = set(sys.argv[2:])
page_token = ""

while True:
    command = [
        "openshell", "--workspace", workspace, "provider", "list",
        "--output", "json", "--page-size", "100",
    ]
    if page_token:
        command.extend(["--page-token", page_token])
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode:
        sys.stderr.write(result.stderr)
        sys.exit(result.returncode)
    page = json.loads(result.stdout)
    for provider in page.get("providers", []):
        if provider.get("type") in profile_types:
            print(provider["name"])
    page_token = page.get("next_page_token", "")
    if not page_token:
        break
' "$WORKSPACE" "${all_profiles[@]}"); then
    printf 'Failed to list providers for cleanup.\n' >&2
    exit 1
  fi

  if [[ -n $providers_to_delete ]]; then
    while IFS= read -r provider_name; do
      [[ -n $provider_name ]] || continue
      printf 'Deleting provider %s from workspace %s...\n' "$provider_name" "$WORKSPACE"
      openshell --workspace "$WORKSPACE" provider delete "$provider_name"
    done <<< "$providers_to_delete"
  else
    printf 'No providers to delete in workspace %s.\n' "$WORKSPACE"
  fi

  printf 'Finding profiles in workspace %s...\n' "$WORKSPACE"
  if ! existing_profiles=$(openshell --workspace "$WORKSPACE" profile list --output json); then
    printf 'Failed to list profiles for cleanup.\n' >&2
    exit 1
  fi
  if ! profiles_to_delete=$(python3 -c '
import json
import sys

profile_ids = set(sys.argv[1:])
for profile in json.load(sys.stdin):
    if profile.get("id") in profile_ids:
        print(profile["id"])
' "${all_profiles[@]}" <<< "$existing_profiles"); then
    printf 'Failed to parse profile list for cleanup.\n' >&2
    exit 1
  fi

  if [[ -n $profiles_to_delete ]]; then
    mapfile -t profile_ids <<< "$profiles_to_delete"
    printf 'Deleting profiles from workspace %s: %s\n' "$WORKSPACE" "${profile_ids[*]}"
    openshell --workspace "$WORKSPACE" profile delete "${profile_ids[@]}"
  else
    printf 'No profiles to delete in workspace %s.\n' "$WORKSPACE"
  fi
fi

if ((${#profiles[@]} == 0)); then
  printf 'No profiles have all their required credentials; cleanup in workspace %s is complete and there are no profiles to load.\n' "$WORKSPACE"
  exit 0
fi

printf 'Linting provider profiles for workspace %s...\n' "$WORKSPACE"
profiles_to_import=()
for profile in "${profiles[@]}"; do
  if lint_output=$(openshell --workspace "$WORKSPACE" profile lint -f "${profiles_dir}/${profile}.yaml" 2>&1); then
    [[ -z $lint_output ]] || printf '%s\n' "$lint_output"
    profiles_to_import+=("$profile")
  elif [[ $lint_output =~ [Aa]lready[[:space:]]+(exists|imported) ]]; then
    printf 'Warning: profile %s already exists in workspace %s; skipping its lint and import.\n' "$profile" "$WORKSPACE" >&2
  else
    printf '%s\n' "$lint_output" >&2
    exit 1
  fi
done

printf 'Importing provider profiles into workspace %s...\n' "$WORKSPACE"
for profile in "${profiles_to_import[@]}"; do
  openshell --workspace "$WORKSPACE" profile import -f "${profiles_dir}/${profile}.yaml"
done

printf 'Creating providers in workspace %s...\n' "$WORKSPACE"
for index in "${!profiles[@]}"; do
  profile=${profiles[$index]}
  provider_name="${USER}-${profile}"
  read_profile_credentials "${profiles_dir}/${profile}.yaml"
  provider_args=(--name "$provider_name" --type "$profile")
  for credential in "${profile_credentials[@]}"; do
    provider_args+=(--credential "$credential")
  done
  if create_output=$(openshell --workspace "$WORKSPACE" provider create "${provider_args[@]}" 2>&1); then
    [[ -z $create_output ]] || printf '%s\n' "$create_output"
  elif [[ $create_output =~ [Aa]lready[[:space:]]+exists ]]; then
    printf 'Provider %s already exists in workspace %s; skipping creation.\n' "$provider_name" "$WORKSPACE" >&2
  else
    printf '%s\n' "$create_output" >&2
    exit 1
  fi
done

printf 'Profiles in workspace %s:\n' "$WORKSPACE"
openshell --workspace "$WORKSPACE" profile list
printf 'Providers in workspace %s:\n' "$WORKSPACE"
openshell --workspace "$WORKSPACE" provider list
