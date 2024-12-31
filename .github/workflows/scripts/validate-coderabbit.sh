#!/bin/bash

echo "Step 1: Fetching all PR reviews..."

all_reviews="[]"
page=1

while true; do
  response=$(curl -s -f -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/${GITHUB_REPOSITORY}/pulls/${PR_NUMBER}/reviews?per_page=30&page=$page") || {
    echo "Error: Failed to fetch reviews from GitHub API"
    exit 1
  }

  if [ -z "$response" ] || [ "$response" = "[]" ]; then
    break
  fi

  all_reviews=$(echo "$all_reviews" "$response" | jq -s 'add')
  page=$((page + 1))
done

latest_reviews=$(echo "$all_reviews" | jq -c '[.[]] | group_by(.user.login) | map(max_by(.submitted_at))') || {
  echo "Error: Failed to process reviews JSON"
  exit 1
}

if [ "$latest_reviews" = "null" ] || [ -z "$latest_reviews" ]; then
  echo "Error: Invalid reviews data"
  exit 1
fi

echo "Step 2: Checking approval status of 'coderabbitai[bot]'..."
approval_state=$(echo "$latest_reviews" | jq -r '[.[] | select(.user.login == "coderabbitai[bot]" and .state == "APPROVED")] | length')

if [[ "$approval_state" =~ ^[0-9]+$ ]] && [[ $approval_state -gt 0 ]]; then
  echo "Success: PR approved by CodeRabbit.ai."
else
  echo "Error: PR is not approved by CodeRabbit.ai."
  exit 1
fi
