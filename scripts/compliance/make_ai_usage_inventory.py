#!/usr/bin/env python3
import argparse, json, os, re

PROVIDER_RULES = [
  ("OPENAI", re.compile(r"\bopenai\b|api\.openai\.com|gpt-?4|azure[ -]?openai", re.I)),
  ("ANTHROPIC", re.compile(r"\banthropic\b|\bclaude\b|api\.anthropic\.com", re.I)),
  ("GEMINI", re.compile(r"\bgemini\b|generativelanguage|ai\.google\.dev", re.I)),
  ("VERTEX_AI", re.compile(r"\bvertexai\b|\baiplatform\b|aiplatform\.googleapis\.com", re.I)),
  ("COHERE", re.compile(r"\bcohere\b|api\.cohere\.ai", re.I)),
  ("MISTRAL", re.compile(r"\bmistral\b|api\.mistral", re.I)),
  ("GROQ", re.compile(r"\bgroq\b|api\.groq\.com", re.I)),
  ("TOGETHER", re.compile(r"\btogether\b|together\.ai", re.I)),
  ("REPLICATE", re.compile(r"\breplicate\b|replicate\.com", re.I)),
  ("HUGGINGFACE", re.compile(r"\bhuggingface\b|inference\.hf\.co|hf_token", re.I)),
  ("BEDROCK", re.compile(r"\bbedrock\b|amazon bedrock", re.I)),
  ("ELEVENLABS", re.compile(r"\belevenlabs\b", re.I)),
  ("DEEPGRAM", re.compile(r"\bdeepgram\b", re.I)),
  ("ASSEMBLYAI", re.compile(r"\bassemblyai\b", re.I)),
  ("VECTOR_DB", re.compile(r"\bpinecone\b|\bweaviate\b|\bqdrant\b|\bmilvus\b|\bchromadb\b|\bpgvector\b", re.I)),
  ("FRAMEWORK", re.compile(r"\blangchain\b|\bllamaindex\b|semantic-kernel|litellm|haystack", re.I)),
  ("SPEECH", re.compile(r"\bstt\b|speech-to-text|text-to-speech|\btts\b|\bwhisper\b|google cloud speech|texttospeech", re.I)),
]

def parse_grep(path, match_type):
    out = []
    if not os.path.exists(path):
        return out
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.rstrip("\n")
            m = re.match(r"^(.*?):(\d+):(.*)$", line)
            if not m:
                continue
            file, ln, snippet = m.group(1), int(m.group(2)), m.group(3)
            out.append({"file": file, "line": ln, "matchType": match_type, "snippet": snippet[:600]})
    return out

def classify(snippet):
    for provider, rx in PROVIDER_RULES:
        if rx.search(snippet):
            return provider
    return "UNKNOWN"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", required=True)
    ap.add_argument("--git-sha", required=True)
    ap.add_argument("--timestamp", required=True)
    ap.add_argument("--ai-grep", required=True)
    ap.add_argument("--key-grep", required=True)
    ap.add_argument("--deps", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    occ = []
    occ += parse_grep(args.ai_grep, "codeRef")
    occ += parse_grep(args.key_grep, "keyRef")

    providers = set()
    for o in occ:
        o["classifiedProvider"] = classify(o["snippet"])
        providers.add(o["classifiedProvider"])

    deps = {}
    if os.path.exists(args.deps):
        deps = json.load(open(args.deps, "r", encoding="utf-8"))

    payload = {
        "timestamp": args.timestamp,
        "gitSha": args.git_sha,
        "repoRoot": args.repo_root,
        "providersFoundFromGrep": sorted(list(providers)),
        "providersFoundFromDeps": deps.get("providersFound", []),
        "packagesFoundFromDeps": deps.get("packagesFound", []),
        "occurrences": occ,
        "recommendationSummary": (
            "Replace all external AI providers with internalAI provider layer. "
            "Add CI bans for external endpoints/SDKs/keys, enforce runtime egress denylist, "
            "and modularize K–12 content into subject packs + prompt modules."
        )
    }

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)

if __name__ == "__main__":
    main()