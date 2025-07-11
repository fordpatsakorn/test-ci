#!/usr/bin/env bash


declare -A type_priority
json_file="$ACTION_PATH/priority.json"
if [[ ! -f "$json_file" ]]; then
  echo "Priority config not found: $json_file"
  exit 1
fi

priority_labels=("patch" "minor" "major")

declare -A priority_index=(
  ["patch"]=0
  ["minor"]=1
  ["major"]=2
)

for level in "${!priority_index[@]}"; do
  keywords=$(jq -r --arg level "$level" '.[$level][]' "$json_file")
  for keyword in $keywords; do
    type_priority["$keyword"]=${priority_index["$level"]}
  done
done

highest_priority=-1

for commit in $(git log $(git describe --tags --abbrev=0)..HEAD --pretty=format:"%H");
do
  response=$(curl -sL \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/fordpatsakorn/test-auto-versioning/commits/$commit/pulls")
  ref=$(echo "$response" | jq -r '.[0].head.ref // empty')
  if [ -n "$ref" ]; then
    # Extract the commit type (before the first '/')
    commit_type=$(echo "$ref" | awk -F'/' '{print $1}')

    priority=${type_priority[$commit_type]}
    if [[ -n $priority ]]; then
      if (( $priority > highest_priority )); then
        highest_priority=$priority
      fi
    fi
  fi
done

if (( highest_priority > -1 )); then
  echo "${priority_labels[highest_priority]}"
else
  echo "none"
fi
