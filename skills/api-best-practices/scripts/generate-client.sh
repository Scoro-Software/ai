#!/usr/bin/env bash
# Generate a typed client for the Scoro API v4 with openapi-generator.
#
#   scripts/generate-client.sh <generator> [output-dir] [--spec URL-OR-FILE] [-- <extra generate arguments>]
#
#   generator    typescript-fetch, python, go or php apply the starter config in
#                scripts/openapi-generator/<generator>.json. Any other openapi-generator
#                name (java, csharp, kotlin, ruby, rust, ...) runs with its defaults.
#   output-dir   default ./scoro-api-client-<generator>
#   --spec       schema URL or local file (default: the public schema)
#   --           everything after it goes to openapi-generator generate, for example
#                -- --additional-properties=packageName=myscoro
#
# Needs openapi-generator installed (the script says how when it is missing). Details in scripts/README.md.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<USAGE
usage: generate-client.sh <generator> [output-dir] [--spec URL-OR-FILE] [-- <extra generate arguments>]

  generator    typescript-fetch, python, go or php (starter config applied),
               or any other openapi-generator name
  output-dir   default ./scoro-api-client-<generator>
  --spec       schema URL or local file (default: the public schema)
  --           pass the rest to openapi-generator generate
USAGE
}

positional=()
passthrough=()
while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
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
      usage
      exit 2
      ;;
    *)
      positional+=("$1")
      shift
      ;;
  esac
done
generator=${positional[0]:-}
if [ -z "$generator" ]; then
  usage
  exit 2
fi
out=${positional[1]:-./scoro-api-client-$generator}
config="$here/openapi-generator/$generator.json"
config_args=()
if [ -f "$config" ]; then
  config_args=(--config "$config")
fi

"$here/openapi-generator/run.sh" "$generator" "$out" ${config_args[@]+"${config_args[@]}"} ${passthrough[@]+"${passthrough[@]}"}

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
