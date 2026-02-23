#!/usr/bin/env python3
import argparse, json, os, re

def parse_grep(path: str, match_type: str):
    out = []
    if not os.path.exists(path):
        return out
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.rstrip("\n")
            # grep format: ./path:line:content
            m = re.match(r"^(.*?):(\d+):(.*)$", line)
            if not m:
                continue
            file, ln, snippet = m.group(1), int(m.group(2)), m.group(3)
            out.append({
                "file": file,
                "line": ln,
                "matchType": match_type,
                "snippet": snippet[:500],
            })
    return out

def classify_occurrence(snippet: str):
    s = snippet.lower()
    if "@google/generative-ai" in s or "google-genai" in s:
        return "dep_or_import"
    if "generativelanguage.googleapis.com" in s or "ai.google.dev" in s:
        return "domain"
    if "gemini" in s:
        return "gemini_ref"
    if "api_key" in s or "google_api_key" in s:
        return "key_ref"
    return "other"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", required=True)
    ap.add_argument("--git-sha", required=True)
    ap.add_argument("--timestamp", required=True)
    ap.add_argument("--gemini-grep", required=True)
    ap.add_argument("--key-grep", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    occ = []
    occ += parse_grep(args.gemini_grep, "codeRef")
    occ += parse_grep(args.key_grep, "keyRef")

    providers = set()
    for o in occ:
        sn = o["snippet"].lower()
        if "gemini" in sn or "generativelanguage" in sn or "@google/generative-ai" in sn or "google-genai" in sn:
            providers.add("GEMINI")
        if "openai" in sn:
            providers.add("OPENAI")
        if "anthropic" in sn:
            providers.add("ANTHROPIC")
        o["classifiedAs"] = classify_occurrence(o["snippet"])

    payload = {
        "timestamp": args.timestamp,
        "gitSha": args.git_sha,
        "repoRoot": args.repo_root,
        "providersFound": sorted(list(providers)),
        "occurrences": occ,
        "recommendationSummary": (
            "Replace all vendor call sites with internalAI provider layer. "
            "Remove vendor SDKs/domains/keys. Add CI bans + egress proof."
        ),
    }

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)

if __name__ == "__main__":
    main()