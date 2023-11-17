#!/usr/bin/env bash
# @file backup_figma.sh
# Export Figma files to local directory
# @author Alister Lewis-Bowen <alister@lewis-bowen.org>

[[ -n $DEBUG ]] && {
    export PS4='+($(basename ${BASH_SOURCE[0]}):${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -x
}
set -eou pipefail

# shellcheck disable=SC1091
source backup_figma_config.sh

# @ref https://www.figma.com/developers/api#access-tokens
# shellcheck disable=SC2034
FIGMA_TOKEN=$(cat "$HOME/.config/figma_token")
FIGMA_API_HEADER="X-FIGMA-TOKEN: $FIGMA_TOKEN"
FIGMA_API_URL="https://api.figma.com/v1"

FILES=0

for i in "${!FIGMA_TEAMS[@]}"; do
    echo -e "🗄️ Projects for Team '${FIGMA_TEAMS[$i]}'"
    project_data=$(curl -sH "$FIGMA_API_HEADER" "${FIGMA_API_URL}/teams/${FIGMA_TEAM_IDS[$i]}/projects" | jq -r '.projects[] | "\(.name) \(.id)"')
    while read -r project; do
        project_name=$(echo "$project" | awk '{$NF="";print $0}')
        project_id=$(echo "$project" | awk '{print $NF}')
        echo -e "  🗂️ Files for '$project_name'"
        file_data=$(curl -sH "$FIGMA_API_HEADER" "${FIGMA_API_URL}/projects/${project_id}/files" | jq -r '.files[] | "\(.name) \(.key)"')
        while read -r file; do
            file_name=$(echo "$file" | awk '{$NF="";print $0}')
            # file_key=$(echo "$file" | awk '{print $NF}')
            echo -e "      📂 Exporting '$file_name'"
            # filename="${FIGMA_TEAMS[$i]// /-}.${project_name// /-}.${file_name// /-}.svg"
            # curl -sH "$FIGMA_API_HEADER" "${FIGMA_API_URL}/images/${file_key}?format=svg" > "$filename"
            # curl -sH "$FIGMA_API_HEADER" "${FIGMA_API_URL}/images/${file_key}"
            FILES=$((FILES+1))
        done <<< "$file_data"
    done <<< "$project_data"
done
echo "Exported $FILES files"