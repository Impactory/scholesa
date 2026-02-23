#!/usr/bin/env python3
import argparse, json, os, re

# Known AI-adjacent packages (expand over time)
KNOWN = {
  # LLM vendors
  "openai": "OPENAI",
  "@azure/openai": "AZURE_OPENAI",
  "anthropic": "ANTHROPIC",
  "@anthropic-ai/sdk": "ANTHROPIC",
  "@google/generative-ai": "GEMINI",
  "google-genai": "GEMINI",
  "@google-cloud/vertexai": "VERTEX_AI",
  "cohere-ai": "COHERE",
  "cohere": "COHERE",
  "mistralai": "MISTRAL",
  "groq-sdk": "GROQ",
  "together-ai": "TOGETHER",
  "replicate": "REPLICATE",

  # Speech
  "openai-whisper": "WHISPER",
  "whisper": "WHISPER",
  "deepgram": "DEEPGRAM",
  "assemblyai": "ASSEMBLYAI",
  "elevenlabs": "ELEVENLABS",

  # Frameworks
  "langchain": "LANGCHAIN",
  "langchain-core": "LANGCHAIN",
  "llamaindex": "LLAMAINDEX",
  "semantic-kernel": "SEMANTIC_KERNEL",
  "litellm": "LITELLM",
  "haystack": "HAYSTACK",

  # Vector DB
  "pinecone": "PINECONE",
  "@pinecone-database/pinecone": "PINECONE",
  "weaviate-client": "WEAVIATE",
  "qdrant-client": "QDRANT",
  "pymilvus": "MILVUS",
  "chromadb": "CHROMA",
  "pgvector": "PGVECTOR",
}

LOCKFILES = ["pnpm-lock.yaml", "yarn.lock", "package-lock.json", "poetry.lock", "Pipfile.lock", "requirements.txt", "go.mod", "go.sum"]

def find_lockfiles(root):
    out = []
    for lf in LOCKFILES:
        p = os.path.join(root, lf)
        if os.path.exists(p):
            out.append(p)
    # also find nested lockfiles
    for dirpath, _, filenames in os.walk(root):
        for lf in LOCKFILES:
            if lf in filenames:
                p = os.path.join(dirpath, lf)
                if p not in out:
                    out.append(p)
    return out

def scan_file_for_known(path):
    hits = []
    try:
        txt = open(path, "r", encoding="utf-8", errors="ignore").read()
    except Exception:
        return hits
    lower = txt.lower()
    for pkg, provider in KNOWN.items():
        if pkg.lower() in lower:
            hits.append({"package": pkg, "provider": provider, "file": path})
    return hits

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", required=True)
    ap.add_argument("--git-sha", required=True)
    ap.add_argument("--timestamp", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    lockfiles = find_lockfiles(args.repo_root)
    deps_hits = []
    for lf in lockfiles:
        deps_hits.extend(scan_file_for_known(lf))

    providers = sorted({h["provider"] for h in deps_hits})
    packages = sorted({h["package"] for h in deps_hits})

    payload = {
        "timestamp": args.timestamp,
        "gitSha": args.git_sha,
        "repoRoot": args.repo_root,
        "lockfilesScanned": lockfiles,
        "providersFound": providers,
        "packagesFound": packages,
        "hits": deps_hits
    }

    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)

if __name__ == "__main__":
    main()