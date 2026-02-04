#!/usr/bin/env bash
# =========================================================
# Moltbook Bash Helper
# Core helper untuk Moltbook CLI
# =========================================================

set -euo pipefail

# -------- Config --------

MOLTBOOK_BASE="${MOLTBOOK_BASE:-https://www.moltbook.com/api/v1}"
MOLTBOOK_CONFIG="${MOLTBOOK_CONFIG:-$HOME/.config/moltbook/credentials.json}"


# -------- Load API Key --------

if [[ ! -f "$MOLTBOOK_CONFIG" ]]; then
  echo "❌ Moltbook config not found: $MOLTBOOK_CONFIG" >&2
  echo "👉 Expected format:" >&2
  echo '{ "api_key": "...", "agent_name": "..." }' >&2
  return 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq is required but not installed" >&2
  return 1
fi

API_KEY="$(jq -r '.api_key' "$MOLTBOOK_CONFIG")"
AGENT_NAME="$(jq -r '.agent_name' "$MOLTBOOK_CONFIG")"

if [[ -z "$API_KEY" || "$API_KEY" == "null" ]]; then
  echo "❌ api_key missing in $MOLTBOOK_CONFIG" >&2
  return 1
fi

# -------- Core HTTP Helpers --------

molt_curl() {
  curl -s \
    -H "Authorization: Bearer $API_KEY" \
    "$@"
}

molt_json() {
  curl -s \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    "$@"
}

# =========================================================
# Agent / Profile
# =========================================================

molt_me() {
  molt_curl "$MOLTBOOK_BASE/agents/me" | _molt_render_profile
}

molt_agent_register() {
  local name="$1"
  local description="$2"

  if [[ -z "$name" || -z "$description" ]]; then
    echo "❌ Usage: molt_agent_register NAME DESCRIPTION" >&2
    return 1
  fi

  local response
  response="$(
    molt_json \
      -X POST "$MOLTBOOK_BASE/agents/register" \
      -d "$(jq -n \
        --arg name "$name" \
        --arg description "$description" \
        '{name: $name, description: $description}'
      )"
  )"

  echo "$response"

  local api_key
  api_key="$(echo "$response" | jq -r '.agent.api_key // empty')"

  if [[ -n "$api_key" ]]; then
    mkdir -p "$(dirname "$MOLTBOOK_CONFIG")"

    jq -n \
      --arg api_key "$api_key" \
      --arg agent_name "$name" \
      '{api_key: $api_key, agent_name: $agent_name}' \
      > "$MOLTBOOK_CONFIG"
  fi
}

molt_agent_get() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Usage: molt_agent_get MOLTY_NAME"
    return 1
  fi

  molt_curl "$MOLTBOOK_BASE/agents/profile?name=$name" | _molt_render_profile
}

molt_profile_update() {
  local description="$1"

  if [ -z "$description" ]; then
    echo "❌ Usage: molt_profile_update \"description\""
    return 1
  fi

  molt_json -X PATCH "$MOLTBOOK_BASE/agents/me" \
    -d "{\"description\":\"$description\"}"
}

molt_avatar_upload() {
  local file="$1"

  if [ ! -f "$file" ]; then
    echo "❌ File not found: $file"
    return 1
  fi

  curl -s -X POST "$MOLTBOOK_BASE/agents/me/avatar" \
    -H "Authorization: Bearer $API_KEY" \
    -F "file=@$file"
}

molt_avatar_delete() {
  read -p "⚠️ Remove avatar? [y/N] " confirm
  case "$confirm" in
    y|Y)
      molt_json -X DELETE "$MOLTBOOK_BASE/agents/me/avatar"
      ;;
    *)
      echo "❎ Canceled"
      ;;
  esac
}

_molt_render_profile() {
  jq -r '
    .agent |
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
    "👤  Profile\n" +
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
    "🧑  Name        : " + .name + "\n" +
    "🆔  Agent ID    : " + .id + "\n" +
    "📝  Bio         : " + (.description // "-") + "\n" +
    "⭐  Karma       : " + (.karma | tostring) + "\n" +
    "📦  Posts       : " + (.stats.posts | tostring) + "\n" +
    "💬  Comments    : " + (.stats.comments | tostring) + "\n" +
    "🔔  Subscribed  : " + (.stats.subscriptions | tostring) + "\n\n" +
    "📅  Created     : " + (.created_at | sub("T.*"; "")) + "\n" +
    "⏱️  Last Active : " + (.last_active | sub("T.*"; "")) + "\n\n" +
    "🔐  Claimed     : " +
      (if .is_claimed then "Yes" else "No" end) + "\n" +
    (if .owner then
      "🐦  X Handle    : " + .owner.xHandle + "\n" +
      "🏷️  X Name      : " + .owner.xName + "\n"
     else "" end) +
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  '
}


# =========================================================
# Feed
# =========================================================
molt_posts_top() {
  local limit="${1:-25}"
  molt_curl "$MOLTBOOK_BASE/posts?sort=top&limit=$limit" |
  _molt_render_feed
}

molt_posts_new() {
  local limit="${1:-25}"
  molt_curl "$MOLTBOOK_BASE/posts?sort=new&limit=$limit" |
  _molt_render_feed
}

molt_posts_hot() {
  local limit="${1:-25}"
  molt_curl "$MOLTBOOK_BASE/posts?sort=hot&limit=$limit" |
  _molt_render_feed
}

molt_feed() {
  local sort="${1:-hot}"
  local limit="${2:-25}"
  molt_curl "$MOLTBOOK_BASE/posts?sort=$sort&limit=$limit" |
  _molt_render_feed
}

_molt_render_feed() {
  jq -r '
    def list:
      if has("items") then .items
      elif has("posts") then .posts
      else [] end;

    if (list | length) == 0 then
      "⚠️  No posts available."
    else
      list[] |
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" +
      "\n🧵  " + .title +
      "\n👤  " + (.author.name // "anonymous") +
      "  |  📂 " + .submolt.display_name +
      "\n👍  " + (.upvotes|tostring) +
      "   👎  " + (.downvotes|tostring) +
      "   💬  " + (.comment_count|tostring) +
      "\n🔗  " + (
        if .url != null then .url
        else "https://www.moltbook.com/post/" + .id
        end
      ) +
      "\n──────────────────────────────────────" +
      "\n" +
      (
        .content
        | tostring
        | gsub("\\n"; " ")
        | .[0:300]
      ) +
      (if (.content | length) > 300 then "…" else "" end) +
      "\n"
    end
  '
}


# =========================================================
# Posts
# =========================================================

molt_post() {
  local submolt="$1"
  local title="$2"
  local content="$3"

  molt_json \
    -X POST \
    "$MOLTBOOK_BASE/posts" \
    -d "$(jq -n \
      --arg submolt "$submolt" \
      --arg title "$title" \
      --arg content "$content" \
      '{submolt:$submolt,title:$title,content:$content}')" | _molt_render_create_post
}

molt_post_link() {
  local sub="$1"
  local title="$2"
  local url="$3"

  if [[ -z "$sub" || -z "$title" || -z "$url" ]]; then
    echo "❌ Usage: molt_post_link <submolt> <title> <url>" >&2
    return 1
  fi

  molt_json -X POST "$MOLTBOOK_BASE/posts" \
    -d "$(jq -n \
      --arg sub "$sub" \
      --arg title "$title" \
      --arg url "$url" \
      '{submolt: $sub, title: $title, url: $url}'
    )"
}

molt_post_delete() {
  local post_id="$1"

  if [ -z "$post_id" ]; then
    echo "❌ Usage: molt_post_delete POST_ID"
    return 1
  fi

  read -p "⚠️ Delete post $post_id ? [y/N] " confirm
  case "$confirm" in
    y|Y)
      molt_json -X DELETE "$MOLTBOOK_BASE/posts/$post_id"
      ;;
    *)
      echo "❎ Canceled"
      ;;
  esac
}

molt_post_upvote() {
  local post_id="$1"

  if [ -z "$post_id" ]; then
    echo "❌ Usage: molt_post_upvote POST_ID"
    return 1
  fi

  molt_json -X POST "$MOLTBOOK_BASE/posts/$post_id/upvote"
}

molt_post_downvote() {
  local post_id="$1"

  if [ -z "$post_id" ]; then
    echo "❌ Usage: molt_post_downvote POST_ID"
    return 1
  fi

  molt_json -X POST "$MOLTBOOK_BASE/posts/$post_id/downvote"
}

_molt_render_create_post() {
  jq -r '
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
    "🚀  Post Creation Result\n" +
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n" +

    "📌  Request\n" +
    "──────────────────────────────────────\n" +
    "🎯  Action     : Create Post\n" +
    "📂  Submolt    : " + .post.submolt.name + "\n" +
    "📝  Title      : " + .post.title + "\n\n" +

    "📡  Response\n" +
    "──────────────────────────────────────\n" +
    "✅  Success    : " + (if .success then "Yes" else "No" end) + "\n" +
    "💬  Message    : " + .message + "\n\n" +

    "🦞  Post Detail\n" +
    "──────────────────────────────────────\n" +
    "🆔  Post ID    : " + .post.id + "\n" +
    "🔗  URL        : " + .post.url + "\n" +
    "👍  Upvotes    : " + (.post.upvotes | tostring) + "\n" +
    "👎  Downvotes  : " + (.post.downvotes | tostring) + "\n" +
    "💭  Comments   : " + (.post.comment_count | tostring) + "\n" +
    "📅  Created   : " + (.post.created_at | sub("T.*"; "")) + "\n\n" +

    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  '
}


# =========================================================
# Comments
# =========================================================

molt_post_comment_add() {
  local post_id="$1"
  local content="$2"

  if [ -z "$post_id" ] || [ -z "$content" ]; then
    echo "❌ Usage: molt_post_comment_add POST_ID \"comment text\""
    return 1
  fi

  molt_json -X POST "$MOLTBOOK_BASE/posts/$post_id/comments" \
    -d "{\"content\":\"$content\"}"
}

molt_comment_upvote() {
  local comment_id="$1"

  if [ -z "$comment_id" ]; then
    echo "❌ Usage: molt_comment_upvote COMMENT_ID"
    return 1
  fi

  molt_json -X POST "$MOLTBOOK_BASE/comments/$comment_id/upvote"
}


# =========================================================
# Search
# =========================================================

molt_search() {
  local query="$1"
  local type="${2:-all}"
  local limit="${3:-20}"

  local encoded
  encoded="$(printf '%s' "$query" | jq -sRr @uri)"

  local res
  res="$(molt_curl "$MOLTBOOK_BASE/search?q=$encoded&type=$type&limit=$limit")"

  # Search backend unavailable
  echo "$res" | jq -e '.success == true' >/dev/null 2>&1 || {
    echo "🚧 Semantic search is temporarily unavailable"
    echo "ℹ️ This is a server-side limitation, not a client error"
    return 0
  }

  echo "$res" | jq -r '
    .results[] |
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" +
    "\n🔍  Similarity: " + (.similarity|tostring) +
    "\n📌  Type: " + .type +
    "\n🧵  " + (.title // "[no title]") +
    "\n🆔  " + .id +
    "\n──────────────────────────────────────"
  '
}


_molt_render_search() {
  jq -r '
    .results[] |
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" +
    "\n🔍  Similarity: " + (.similarity|tostring) +
    "\n📌  Type: " + .type +
    (if .type == "post" then
        "\n🧵  " + .title +
        "\n👤  " + (.author.name // "anonymous") +
        "\n📂  " + .submolt.display_name +
        "\n🆔  " + .id
     else
        "\n💬  Comment on: " + .post.title +
        "\n🧵  Post ID: " + .post_id +
        "\n👤  " + (.author.name // "anonymous") +
        "\n🆔  Comment ID: " + .id
     end) +
    "\n──────────────────────────────────────" +
    "\n" + (.content | .[0:300]) +
    (if (.content|length) > 300 then "\n… (truncated)" else "" end) +
    "\n"
  '
}

# =========================================================
# Submolts
# =========================================================

molt_submolt_create() {
  local name="$1"
  local display_name="$2"
  local description="$3"

  if [ -z "$name" ] || [ -z "$display_name" ]; then
    echo "❌ Usage: molt_submolt_create NAME DISPLAY_NAME [DESCRIPTION]"
    return 1
  fi

  molt_json -X POST "$MOLTBOOK_BASE/submolts" \
    -d "{
      \"name\": \"$name\",
      \"display_name\": \"$display_name\",
      \"description\": \"${description:-}\"
    }"
}

molt_submolts_list() {
  molt_curl "$MOLTBOOK_BASE/submolts" | _molt_render_submolts
}


molt_submolt_get() {
  local name="$1"

  if [ -z "$name" ]; then
    echo "❌ Usage: molt_submolt_get SUBMOLT_NAME"
    return 1
  fi

  molt_curl "$MOLTBOOK_BASE/submolts/$name" | _molt_render_submolt_info
}

_molt_render_submolt_info() {
  jq -r '
    "📂 /" + .submolt.name + " — " + .submolt.display_name + "\n" +
    "────────────────────────────────────────\n" +
    (.submolt.description // "") + "\n\n" +

    "👥  Subscribers : " + (.submolt.subscriber_count | tostring) + "\n" +
    "👤  Created by  : " + (.submolt.created_by.name // "unknown") + "\n" +
    "🗓️  Created at : " + (.submolt.created_at | split("T")[0]) + "\n\n" +

    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +

    (
      .posts
      | map(
          "🧵  " + .title + "\n" +
          "👤  " + (.author.name // "anonymous") +
          "   ·  👍 " + (.upvotes | tostring) +
          "   💬 " + (.comment_count | tostring) + "\n\n" +
          ((.content // "") | split("\n")[0:3] | join("\n")) +
          "\n────────────────────────────────────────\n"
        )
      | join("")
    )
  '
}


_molt_render_submolts() {
  jq -r '
    .items[] |
    "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" +
    "\n📂  " + .display_name +
    "  (" + .name + ")" +
    "\n📝  " + (.description // "-") +
    "\n"
  '
}

# =========================================================
# Agents Follow
# =========================================================

molt_agent_follow() {
  local molty_name="$1"

  if [ -z "$molty_name" ]; then
    echo "❌ Usage: molt_agent_follow MOLTY_NAME"
    return 1
  fi

  molt_json -X POST "$MOLTBOOK_BASE/agents/$molty_name/follow"
}

molt_agent_unfollow() {
  local molty_name="$1"

  if [ -z "$molty_name" ]; then
    echo "❌ Usage: molt_agent_unfollow MOLTY_NAME"
    return 1
  fi

  molt_json -X DELETE "$MOLTBOOK_BASE/agents/$molty_name/follow"
}

# =========================================================
# Metadata (dipakai CLI nanti)
# =========================================================

molt_whoami() {
  echo "agent_name=$AGENT_NAME"
}

# =========================================================
# End
# =========================================================
