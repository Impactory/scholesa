#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <log-file> [log-file ...]" >&2
  exit 64
fi

for log_file in "$@"; do
  [[ -f "$log_file" ]] || continue

  perl -0pi -e '
    s#https://northamerica-1\.object-storage\.apple\.com/[^\s,)]*#[REDACTED_APPLE_UPLOAD_URL]#g;
    s#https://[^\s,)]*\?(?=[^\s,)]*(?:X-Amz-Signature|X-Goog-Signature|X-Amz-Credential|X-Goog-Credential|uploadId=|apple-asset-repo-correlation-key=))[^\s,)]*#[REDACTED_SIGNED_URL]#g;
    s#X-Amz-(?:Signature|Credential|Security-Token|Algorithm|Date|Expires|SignedHeaders)=[^&\s,)]*#[REDACTED_AWS_QUERY]#g;
    s#X-Goog-(?:Signature|Credential|Algorithm|Date|Expires|SignedHeaders)=[^&\s,)]*#[REDACTED_GOOGLE_QUERY]#g;
    s#uploadId=[^&\s,)]*#uploadId=[REDACTED]#g;
    s#apple-asset-repo-correlation-key=[^&\s,)]*#apple-asset-repo-correlation-key=[REDACTED]#g;
  ' "$log_file"
done