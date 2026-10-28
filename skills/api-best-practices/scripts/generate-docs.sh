#!/usr/bin/env bash
# Generate a browsable markdown reference of the Scoro API v4 with openapi-generator.
#
#   scripts/generate-docs.sh [output-dir] [--spec URL-OR-FILE] [-- <extra generate arguments>]
#
#   output-dir   default ./scoro-api-docs
#   --spec       schema URL or local file (default: the public schema)
#
# Needs openapi-generator installed (the script says how when it is missing). Details in scripts/README.md.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

out=""
passthrough=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      echo "usage: generate-docs.sh [output-dir] [--spec URL-OR-FILE] [-- <extra generate arguments>]"
      exit 2
      ;;
    --)
      passthrough+=("$@")
      break
      ;;
    --spec)
      [ $# -ge 2 ] || { echo "error: --spec needs a URL or a file path" >&2; exit 2; }
      passthrough+=("$1" "$2")
      shift 2
      ;;
    --spec=*)
      passthrough+=("$1")
      shift
      ;;
    -*)
      echo "error: unknown option $1" >&2
      exit 2
      ;;
    *)
      [ -z "$out" ] || { echo "error: unexpected argument $1" >&2; exit 2; }
      out=$1
      shift
      ;;
  esac
done
out=${out:-./scoro-api-docs}

"$here/openapi-generator/run.sh" markdown "$out" ${passthrough[@]+"${passthrough[@]}"}

cat <<NEXT

Docs generated in $out
  README.md               every operation with method, path and summary, linked to the files below
  Apis/<Resource>Api.md   per operation: method and path, scopes, parameters, return type
  Models/<Name>.md        the fields of each request, response and filter model

Response status codes and enum values are not in these files: read them from the schema,
https://api.scoro.com/api/v4/reference/openapi.
NEXT
