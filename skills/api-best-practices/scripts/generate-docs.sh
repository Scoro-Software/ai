#!/usr/bin/env bash
# Generate a browsable markdown reference of the Scoro API v4 with openapi-generator.
#
#   scripts/generate-docs.sh [output-dir]      default ./scoro-api-docs
#
# Needs Node 18+ and Java 11+. Environment: SCORO_OPENAPI_SPEC (schema URL or file),
# OPENAPI_GENERATOR_ARGS (extra generate arguments). Details in scripts/README.md.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-}" in
  -h|--help)
    echo "usage: generate-docs.sh [output-dir]   (default ./scoro-api-docs)"
    exit 2
    ;;
esac
out=${1:-./scoro-api-docs}

"$here/openapi-generator/run.sh" markdown "$out"

cat <<NEXT

Docs generated in $out
  README.md               every operation with method, path and summary, linked to the files below
  Apis/<Resource>Api.md   per operation: method and path, scopes, parameters, return type
  Models/<Name>.md        the fields of each request, response and filter model

Response status codes and enum values are not in these files: read them from the schema,
https://api.scoro.com/api/v4/reference/openapi.
NEXT
