#!/usr/bin/env bash
# Generate a typed client for the Scoro API v4 with openapi-generator.
#
#   scripts/generate-client.sh <generator> [output-dir]
#
#   generator    typescript-fetch, python, go or php apply the starter config in
#                scripts/openapi-generator/<generator>.json. Any other openapi-generator
#                name (java, csharp, kotlin, ruby, rust, ...) runs with its defaults.
#   output-dir   default ./scoro-api-client-<generator>
#
# Needs Node 18+ and Java 11+. Environment: SCORO_OPENAPI_SPEC (schema URL or file),
# OPENAPI_GENERATOR_ARGS (extra generate arguments). Details in scripts/README.md.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<USAGE
usage: generate-client.sh <generator> [output-dir]

  generator    typescript-fetch, python, go or php (starter config applied),
               or any other openapi-generator name
  output-dir   default ./scoro-api-client-<generator>

Environment: SCORO_OPENAPI_SPEC (schema URL or file), OPENAPI_GENERATOR_ARGS (extra arguments).
USAGE
}

generator=${1:-}
case "$generator" in
  ""|-h|--help) usage; exit 2 ;;
esac
out=${2:-./scoro-api-client-$generator}
config="$here/openapi-generator/$generator.json"
if [ ! -f "$config" ]; then
  config=""
fi

"$here/openapi-generator/run.sh" "$generator" "$out" "$config"

cat <<NEXT

Client generated in $out

Next steps
  1. Point the client at the bare site host, https://{yoursite}.scoro.com.
     The generated paths already contain /api/v4.
  2. Send the OAuth bearer token on every request, and set Scoro-Company-Account
     as a default header on multi-entity sites.
  3. Make one list call with an array filter and look at the query string: the API
     expects filters[key][]=value for arrays, and generators differ here. The fix per
     language is in references/getting-started.md, "Filters in generated clients".
  4. Decide whether to commit $out or add it to .gitignore.
NEXT
