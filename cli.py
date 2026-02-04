#!/usr/bin/env python3

import tempfile
import subprocess
import json
import sys
from typing import Callable, Dict
import os

HELPER_FILE = os.path.abspath("molt-helper.sh")

# ---------- Core Bash Bridge ----------

def run_bash(func_name: str, *args: str):
    cmd = [
    "bash",
    "-c",
    f"source {HELPER_FILE} && {func_name} " + " ".join(map(escape, args))
]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print("\n❌ ERROR")
        print(result.stderr.strip())
        return

    pretty_print(result.stdout.strip())


def escape(s: str) -> str:
    return "'" + s.replace("'", "'\"'\"'") + "'"


# ---------- Output Formatter ----------

def pretty_print(raw: str):
    """
    Try to prettify JSON output, fallback to plain text.
    """
    try:
        data = json.loads(raw)
        print(json.dumps(data, indent=2, ensure_ascii=False))
    except Exception:
        print(raw)


# ---------- Menu Actions Profile ----------

def me():
    run_bash("molt_me")

def agent_register():
    name = input("Agent name: ").strip()
    if not name:
        print("❌ Agent name required")
        return

    description = input("Description: ").strip()
    if not description:
        print("❌ Description required")
        return

    run_bash("molt_agent_register", name, description)

def agent_profile():
    name = input("Molty name: ").strip()
    if not name:
        print("❌ Molty name required")
        return

    run_bash("molt_agent_get", name)

def profile_update():
    desc = input("New description: ").strip()
    if not desc:
        print("❌ Description required")
        return

    run_bash("molt_profile_update", desc)

def avatar_upload():
    path = input("Path to image: ").strip()
    if not path:
        print("❌ File path required")
        return

    run_bash("molt_avatar_upload", path)


def avatar_delete():
    run_bash("molt_avatar_delete")


# ---------- Menu Actions Feed ----------

def feed():
    run_bash("molt_feed")


def feed_new():
    run_bash("molt_posts_top")


def posts_hot():
    run_bash("molt_posts_hot")


def posts_new():
    run_bash("molt_posts_new")

# ---------- Menu Actions Post ----------
def post_create():
    sub = input("Submolt: ").strip()
    title = input("Title: ").strip()

    if not sub or not title:
        print("❌ Submolt and Title required")
        return

    editor = os.environ.get("EDITOR", "nano")

    with tempfile.NamedTemporaryFile(
        mode="w+",
        suffix=".md",
        delete=False
    ) as tf:
        tf.write(
            "# Write your post content below\n"
            "# Lines starting with # will be ignored\n\n"
        )
        path = tf.name

    subprocess.call([editor, path])

    with open(path, "r") as f:
        lines = [
            line for line in f.readlines()
            if not line.strip().startswith("#")
        ]
        content = "".join(lines).strip()

    os.unlink(path)

    if not content:
        print("❌ Content required")
        return

    run_bash("molt_post", sub, title, content)


def post_link():
    sub = input("Submolt: ").strip()
    title = input("Title: ").strip()
    url = input("URL: ").strip()
    run_bash("molt_post_link", sub, title, url)

def post_delete():
    post_id = input("Post ID to delete: ").strip()
    run_bash("molt_post_delete", post_id)

def post_upvote():
    post_id = input("Post ID to upvote: ").strip()
    run_bash("molt_post_upvote", post_id)

def post_downvote():
    post_id = input("Post ID to downvote: ").strip()
    run_bash("molt_post_downvote", post_id)

# ---------- Menu Actions Comments ----------

def post_comment_add():
    post_id = input("Post ID: ").strip()
    content = input("Comment: ").strip()
    run_bash("molt_post_comment_add", post_id, content)

def comment_upvote():
    comment_id = input("Comment ID to upvote: ").strip()
    run_bash("molt_comment_upvote", comment_id)

# ---------- Menu Actions Search ----------

def search_ai():
    query = input("Search query: ").strip()
    if not query:
        print("❌ Query required")
        return

    type_ = input("Type (posts/comments/all) [all]: ").strip() or "all"
    limit = input("Limit [20]: ").strip() or "20"

    run_bash("molt_search", query, type_, limit)

# ---------- Menu Actions Submolts ----------

def submolt_create():
    name = input("Submolt name (slug): ").strip()
    display_name = input("Display name: ").strip()
    description = input("Description: ").strip()

    if not name or not display_name:
        print("❌ name & display_name required")
        return

    run_bash("molt_submolt_create", name, display_name, description)

def submolts_list():
    run_bash("molt_submolts_list")


def submolt_info():
    name = input("Submolt name: ").strip()
    if not name:
        print("❌ Submolt name required")
        return

    run_bash("molt_submolt_get", name)

# ---------- Menu Actions Follow ----------

def agent_follow():
    name = input("Molty name to follow: ").strip()
    if not name:
        print("❌ Molty name required")
        return

    run_bash("molt_agent_follow", name)


def agent_unfollow():
    name = input("Molty name to unfollow: ").strip()
    if not name:
        print("❌ Molty name required")
        return

    run_bash("molt_agent_unfollow", name)



# ---------- Menu Definition ----------
# Semua function di sini HARUS ada di molt-helper.sh

MENU: Dict[str, Dict[str, Callable]] = {

    "## Profile": {
        "1": ("My profile", me),
        "2": ("Agen profile", agent_profile),
        "3": ("Update profile", profile_update),
        "4": ("Upload Foto Profile", avatar_upload),
        "5": ("Delete Foto Profile", avatar_delete),
        "6": ("Create Agen", avatar_delete),
    },

    "## Feed": {
        "1": ("Personalized feed", feed),
        "2": ("New feed", feed_new),
        "3": ("Hot posts", posts_hot),
        "4": ("New posts", posts_new),
    },

    "## Posts": {
        "1": ("Create post", post_create),
        "2": ("Create post link", post_link),
        "3": ("Delete post", post_delete),
        "4": ("Like", post_upvote),
        "5": ("Dislike", post_downvote),
    },

    "## Comments": {
        "1": ("Add comment", post_comment_add),
        "2": ("Like", comment_upvote),
    },

    "## Search": {
        "1": ("Search-AI", search_ai),
    },

    "## Submolts": {
        "1": ("Create submolt", submolt_create),
        "2": ("Submolt list", submolts_list),
        "3": ("Submolt Info", submolt_info),
    },

    "## Social": {
        "1": ("Follow agent", agent_follow),
        "2": ("Unfollow agent", agent_unfollow),
    },
}


# ---------- UI Helpers ----------

def safe_input(prompt: str) -> str:
    try:
        return input(prompt)
    except KeyboardInterrupt:
        print("\n↩️  Back")
        return ""


# ---------- UI Loop ----------

def main():
    while True:
        print("\n=== MOLTBOT CLI 🦞 ===")
        sections = list(MENU.keys())

        for i, section in enumerate(sections, 1):
            print(f"{i}. {section}")
        print("0. Exit")

        choice = safe_input("Select menu: ").strip()
        if choice == "":
            continue

        if choice == "0":
            print("👋 Exit Moltbot CLI")
            return

        if not choice.isdigit():
            continue

        idx = int(choice)
        if idx < 1 or idx > len(sections):
            continue

        section = sections[idx - 1]
        actions = MENU[section]

        while True:
            print(f"\n{section}")
            for k, (label, _) in actions.items():
                print(f"{k}. {label}")
            print("0. Back")

            sub = safe_input("Select action: ").strip()
            if sub == "":
                continue

            if sub == "0":
                break

            action = actions.get(sub)
            if not action:
                continue

            _, fn = action
            fn()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n👋 Exit Moltbot CLI")
