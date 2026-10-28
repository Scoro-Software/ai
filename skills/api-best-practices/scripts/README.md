# Scripts

Starter scripts for working with the Scoro API v4 schema. Both run the official
[openapi-generator](https://openapi-generator.tech) through its npm wrapper, so they need
Node 18+ and a Java 11+ runtime. The pinned generator (7.26.0) is downloaded on first use into
`~/.cache/openapi-generator-cli`; nothing is installed into your project.

| Script | What it does |
|---|---|
| `generate-client.sh <generator> [output-dir]` | Generates a typed client. `typescript-fetch`, `python`, `go` and `php` use the starter config in `openapi-generator/<generator>.json`; any other openapi-generator name runs with the generator's defaults. Default output `./scoro-api-client-<generator>`. |
| `generate-docs.sh [output-dir]` | Generates a browsable markdown reference: `README.md` (every operation), `Apis/<Resource>Api.md` (method, path, scopes, parameters, return type) and `Models/<Name>.md` (fields). Default output `./scoro-api-docs`. |

Both download the public schema, replace earlier generated output in the target directory,
refuse to touch a directory they did not generate, and print what to do next. Ask the user
which language they want before generating a client.

## Environment

| Variable | Meaning |
|---|---|
| `SCORO_OPENAPI_SPEC` | Schema URL or local file. Default `https://api.scoro.com/api/v4/reference/openapi`. |
| `OPENAPI_GENERATOR_ARGS` | Extra arguments for `openapi-generator generate`, for example `--additional-properties=packageName=myscoro` or `--global-property apiDocs=true,modelDocs=true`. |

Exit codes: `1` the generator failed, `2` usage or a missing prerequisite, `3` the output
directory holds something that was not generated, `4` the schema could not be read.

## Starter configs

`openapi-generator/<generator>.json` is passed to the generator with `-c`. Edit the file or
override single values through `OPENAPI_GENERATOR_ARGS`.

Common to all four:

| Option | Why |
|---|---|
| `disallowAdditionalPropertiesIfNotPresent: false` | Models accept fields the API adds later instead of failing on them. |
| `inlineSchemaNameMappings` | Names the `{id}` response that 80 create endpoints share `CreatedId`. Three create endpoints describe their id differently and keep the generator's `Create…201Response` name. |
| `globalProperties` with tests and per-model docs off (`python`, `go`, `php`) | Keeps the output to the client itself. `generate-docs.sh` covers documentation. |
| `hideGenerationTimestamp: true` | Regenerating with the same schema produces the same files. |

Per generator:

| File | Options |
|---|---|
| `typescript-fetch.json` | `npmName`, `npmVersion` (the schema's version `4` is not valid semver), `supportsES6`, `withInterfaces` (an interface per API class, handy for mocks). |
| `python.json` | `packageName`, `projectName`, `packageVersion`, `useOneOfDiscriminatorLookup`. |
| `go.json` | `packageName`, `packageVersion`, `generateInterfaces` (an interface per API, handy for mocks), `enumClassPrefix` (enum constants carry the type name), `structPrefix` (API structs carry the service name), `useOneOfDiscriminatorLookup`, `withGoMod`. |
| `php.json` | `invokerPackage` (root namespace), `packageName`, `composerPackageName`, `artifactVersion`. |

Every run also passes `--openapi-normalizer KEEP_ONLY_FIRST_TAG_IN_OPERATION=true`, so an
operation always lands in exactly one API class.

## Pinned generator version

`openapi-generator/openapitools.json` pins openapi-generator 7.26.0. OpenAPI 3.1 support in the
generator is still marked beta, and the schema is 3.1, so the generator prints a note about it
on every run; the schema validates cleanly. When bumping the version, regenerate every client,
and compare `openapi-generator/templates/markdown/api.mustache` with the new version's
`markdown-documentation/api.mustache`: the file is that template plus two lines per operation,
the HTTP method with the path and the required scopes.
