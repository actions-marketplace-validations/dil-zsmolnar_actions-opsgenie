#!/usr/bin/env bash

# Get parameters
ALIAS=${1}
MESSAGE=${2}
PRIORITY=${3}
OPSGENIE_API_KEY=${4}
USE_EU_INSTANCE=${5:-}
RESPONDERS=${6:-}    # Optional responders (comma-separated, format: id:UUID:type OR name:TeamName:type OR username:Email:type)
TAGS=${7:-}  # Optional tags (comma-separated)

# Make sure a message was defined
if [[ -z "${MESSAGE}" ]]; then
    echo "ERROR: No alert message was set while attempting to generate OpsGenie alert"
    exit 1;
fi

# Make sure an alias was defined
if [[ -z "${ALIAS}" ]]; then
    echo "ERROR: No alert alias was set while attempting to generate OpsGenie alert"
    exit 2;
fi

# Make sure an acceptable priority level was defined
if [[ "P1" != "${PRIORITY}" ]] && [[ "P2" != "${PRIORITY}" ]] && [[ "P3" != "${PRIORITY}" ]] && [[ "P4" != "${PRIORITY}" ]] && [[ "P5" != "${PRIORITY}" ]]; then
    echo "ERROR: An invalid alert priority level (${PRIORITY}) was set, it must be one of the valid OpsGenie alert levels (P1-P5)"
    exit 3;
fi

# Convert tags from comma-separated to JSON array (if provided)
TAGS_JSON=""
if [[ -n "${TAGS}" ]]; then
    IFS=',' read -ra TAGS_ARRAY <<< "$TAGS"
    TAGS_JSON=$(printf '"%s",' "${TAGS_ARRAY[@]}")
    TAGS_JSON="[${TAGS_JSON%,}]" # Remove trailing comma and wrap in brackets
fi

# Convert responders from comma-separated string to JSON array (if provided)
RESPONDERS_JSON=""
if [[ -n "${RESPONDERS}" ]]; then
    IFS=',' read -ra RESPONDER_ARRAY <<< "$RESPONDERS"
    for RESPONDER in "${RESPONDER_ARRAY[@]}"; do
        IDENTIFIER="${RESPONDER%%:*}"  # Extract "id", "name", or "username"
        VALUE="${RESPONDER#*:}"        # Remove the first part (e.g., "id:4513b7ea-3b91-438f-b7e4-e3e54af9147c" -> "4513b7ea-3b91-438f-b7e4-e3e54af9147c:type")
        VALUE_NAME="${VALUE%%:*}"       # Extract the actual value
        TYPE="${VALUE##*:}"             # Extract the type

        if [[ "$IDENTIFIER" == "id" ]]; then
            RESPONDERS_JSON+="{\"id\": \"${VALUE_NAME}\", \"type\": \"${TYPE}\"},"
        elif [[ "$IDENTIFIER" == "name" ]]; then
            RESPONDERS_JSON+="{\"name\": \"${VALUE_NAME}\", \"type\": \"${TYPE}\"},"
        elif [[ "$IDENTIFIER" == "username" ]]; then
            RESPONDERS_JSON+="{\"username\": \"${VALUE_NAME}\", \"type\": \"${TYPE}\"},"
        fi
    done
    RESPONDERS_JSON="[${RESPONDERS_JSON%,}]" # Remove trailing comma and wrap in brackets
fi

echo "Alias: ${ALIAS}"
echo "Message: ${MESSAGE}"
echo "Priority: ${PRIORITY}"
if [[ -n "${TAGS_JSON}" ]]; then
    echo "Tags: ${TAGS_JSON}"
fi
if [[ -n "${RESPONDERS_JSON}" ]]; then
    echo "Responders: ${RESPONDERS_JSON}"
fi

HOST="api.opsgenie.com"
if [[ -n "${USE_EU_INSTANCE}" ]]; then
  HOST="api.eu.opsgenie.com"
fi

# Construct the JSON payload
JSON_PAYLOAD="{
    \"entity\": \"github-actions\",
    \"source\": \"${GITHUB_REPOSITORY}\",
    \"details\": {
        \"github_repository\": \"${GITHUB_REPOSITORY}\",
        \"github_ref\": \"${GITHUB_REF}\",
        \"github_workflow\": \"${GITHUB_WORKFLOW}\",
        \"github_action\": \"${GITHUB_ACTION}\",
        \"github_event_name\": \"${GITHUB_EVENT_NAME}\",
        \"github_event_path\": \"${GITHUB_EVENT_PATH}\",
        \"github_actor\": \"${GITHUB_ACTOR}\",
        \"github_sha\": \"${GITHUB_SHA}\"
    },
    \"alias\": \"${ALIAS}\",
    \"message\": \"${MESSAGE}\",
    \"priority\": \"${PRIORITY}\""

# Append tags only if they exist
if [[ -n "${TAGS_JSON}" ]]; then
    JSON_PAYLOAD+=", \"tags\": ${TAGS_JSON}"
fi

# Append responders only if they exist
if [[ -n "${RESPONDERS_JSON}" ]]; then
    JSON_PAYLOAD+=", \"responders\": ${RESPONDERS_JSON}"
fi

# Close JSON
JSON_PAYLOAD+="}"

# Send alert via curl request to OpsGenie API
RESPONSE=$(curl -s \
    -o /dev/null \
    -w "\n%{http_code}" \
    -X POST "https://${HOST}/v2/alerts" \
    -H "Host: ${HOST}" \
    -H "Authorization: GenieKey ${OPSGENIE_API_KEY}" \
    -H "User-Agent: EonxGitops/1.0.0" \
    -H "cache-control: no-cache" \
    -H "Content-Type: application/json" \
    -d "${JSON_PAYLOAD}")

# Extract status code (last line of the response)
STATUS_CODE=$(echo "${RESPONSE}" | tail -n1)

# Extract response body (all except last line)
RESPONSE_BODY=$(echo "${RESPONSE}" | sed '$d')

# Validate status code
if [[ "${STATUS_CODE}" != "200" ]] && [[ "${STATUS_CODE}" != "201" ]] && [[ "${STATUS_CODE}" != "202" ]]; then
  echo "ERROR: HTTP response code ${STATUS_CODE} received, expected 200, 201, or 202"
  echo "Response body: ${RESPONSE_BODY}"
  exit 1
fi
