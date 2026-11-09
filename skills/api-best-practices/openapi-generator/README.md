# Generating a client or a reference with openapi-generator

This folder holds starter configs for [openapi-generator](https://openapi-generator.tech), one per
generator: `typescript-fetch.json`, `python.json`, `go.json` and `php.json`. Pass one with `-c`
when generating from the public Scoro API v4 schema. The skill was verified with openapi-generator
7.26.0; other versions may produce slightly different output. OpenAPI 3.1 support in the generator
is still marked beta and the schema is 3.1, so the generator prints a note about it on every run;
the schema validates cleanly.

Install the generator once, with any of these (Java 11+, the pip variant bundles its own):

```bash
brew install openapi-generator
npm install -g @openapitools/openapi-generator-cli && openapi-generator-cli version-manager set 7.26.0
pip install "openapi-generator-cli[jdk4py]==7.26.0"
```

Homebrew and pip install the command as `openapi-generator`; the npm wrapper installs it as
`openapi-generator-cli`. The commands below use `openapi-generator`.

## Generate a typed client

Ask the user which language they want first. Then, with `CONFIGS` pointing at this folder:

```bash
SPEC=https://api.scoro.com/api/v4/reference/openapi
CONFIGS=skills/api-best-practices/openapi-generator   # adjust to where the skill is installed

openapi-generator generate -i "$SPEC" -g typescript-fetch -c "$CONFIGS/typescript-fetch.json" \
  --openapi-normalizer KEEP_ONLY_FIRST_TAG_IN_OPERATION=true -o ./scoro-api-client-typescript-fetch

openapi-generator generate -i "$SPEC" -g python -c "$CONFIGS/python.json" \
  --openapi-normalizer KEEP_ONLY_FIRST_TAG_IN_OPERATION=true -o ./scoro-api-client-python

openapi-generator generate -i "$SPEC" -g go -c "$CONFIGS/go.json" \
  --openapi-normalizer KEEP_ONLY_FIRST_TAG_IN_OPERATION=true -o ./scoro-api-client-go \
  --git-user-id myorg --git-repo-id scoro-api

openapi-generator generate -i "$SPEC" -g php -c "$CONFIGS/php.json" \
  --openapi-normalizer KEEP_ONLY_FIRST_TAG_IN_OPERATION=true -o ./scoro-api-client-php
```

Any other generator (`java`, `csharp`, `kotlin`, `ruby`, `rust`, ...) works the same way without
`-c`; it runs with the generator's defaults.

Notes:

- `--openapi-normalizer KEEP_ONLY_FIRST_TAG_IN_OPERATION=true` puts every operation in exactly one
  API class. Keep it on every run.
- Without network access, ask the user to download the schema from `$SPEC` and pass the local file
  to `-i ./openapi.json` instead.
- Generate into a dedicated, empty directory such as `./scoro-api-client-<generator>`, never into a
  project root: the generator writes many files and overwrites what is there.
- Override a single config value with `--additional-properties`, for example
  `--additional-properties=packageName=myscoro`.
- The Go generator leaves a placeholder module path unless `--git-user-id` and `--git-repo-id` are
  given; alternatively fix it in `go.mod` afterwards.

After generating, point the client at the bare site host `https://{yoursite}.scoro.com` (the
generated paths already contain `/api/v4`), send the OAuth bearer token on every request, set
`Scoro-Company-Account` as a default header on multi-entity sites, and make one list call with an
array filter to check that it serializes as `filters[key][]=value`. The per-language fix is in
`references/getting-started.md`, "Filters in generated clients".

## Generate a browsable markdown reference

```bash
openapi-generator generate -i "$SPEC" -g markdown \
  --openapi-normalizer KEEP_ONLY_FIRST_TAG_IN_OPERATION=true -o ./scoro-api-docs
```

Output: `README.md` (every operation with its summary), `Apis/<Resource>Api.md` (per operation:
parameters and return type) and `Models/<Name>.md` (the fields of each request, response and filter
model). The HTTP method and path appear in the per-resource tables. Required scopes, response
status codes and enum values are not in these files: read them from the schema.

## What the starter configs set

Common to all four:

| Option | Why |
|---|---|
| `disallowAdditionalPropertiesIfNotPresent: false` | Models accept fields the API adds later instead of failing on them. |
| `inlineSchemaNameMappings` | Names the `{id}` response that 80 create endpoints share `CreatedId`. Three create endpoints describe their id differently and keep the generator's `Create…201Response` name. |
| `globalProperties` with tests and per-model docs off (`python`, `go`, `php`) | Keeps the output to the client itself. The markdown generator above covers documentation. |
| `hideGenerationTimestamp: true` | Regenerating with the same schema produces the same files. |

Per generator:

| File | Options |
|---|---|
| `typescript-fetch.json` | `npmName`, `npmVersion` (the schema's version `4` is not valid semver), `supportsES6`, `withInterfaces` (an interface per API class, handy for mocks). |
| `python.json` | `packageName`, `projectName`, `packageVersion`, `useOneOfDiscriminatorLookup`. |
| `go.json` | `packageName`, `packageVersion`, `generateInterfaces` (an interface per API, handy for mocks), `enumClassPrefix` (enum constants carry the type name), `structPrefix` (API structs carry the service name), `useOneOfDiscriminatorLookup`, `withGoMod`. |
| `php.json` | `invokerPackage` (root namespace), `packageName`, `composerPackageName`, `artifactVersion`. |
