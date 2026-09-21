# Platform management API (Management v1)

This development-branch extension publishes models, scenes, channels, schedules and tasks from a platform. CPU regression tests are distinct from hardware inference acceptance. Existing web, MQTT, ONVIF and GB28181 interfaces remain available.

## Authentication and endpoints

Use the existing `/gtw/cwai/login/dologin` endpoint and `mtk` session header. Management accepts authenticated HTTP only; account identity comes from the server, not JSON or MQTT.

Paths begin with `/gtw/cwai/Management/`. Use POST JSON except UploadChunk, which uses PUT bytes. Responses retain resCode/resData/resMsg; HTTP 200 alone does not prove completion.

| Endpoint | Input | Result |
| --- | --- | --- |
| Capabilities | Empty object | Protocol, serial, identified chip, runtimes, incarnation, features |
| ResourceInventory | platformId, resourceIds | Every retained version, native ID, digest, configuration and task state |
| PrepareResource | SHA-256 hash, byte size, display name | Verified existing file, or upload ID and offset |
| UploadChunk | Bytes, X-Upload-Id, X-Upload-Offset | Durable offset and final measured hash |
| ApplyOperation | Operation object | PENDING, SUCCEEDED or FAILED |
| OperationStatus | operationId | Durable result; interrupted intents are reconciled |
| TaskActivate | Operation ID, external/version IDs, incarnation, enabled | Switch one logical task or disable all versions |

The first valid write binds platform ID and authenticated account. New sessions retain ownership; silent takeover is unavailable. State lives in the configuration directory under `management/state.sqlite`. Restarts preserve incarnation; factory reset or journal loss changes it. An unidentified Sophon chip returns unknown; the compiled BM1688 label is not hardware evidence.

## Resource contract

Apply requests carry operationId, platformId, externalId, versionId, hash, incarnation, Unix-second expiresAt, action, kind, name, config, files, references and activationPolicy. An operation ID binds the entire payload. Versions are immutable. Each direct reference carries kind, externalId, versionId and a verified native localId. Files must already be verified.

Removal targets an exact version and refuses cascading deletion of shared dependencies. Reconcile pending operations before sending another write.

| Kind | Configuration | Native behavior |
| --- | --- | --- |
| model | chip, runtime, native modelType, config | Existing template, binary and tensor checks; separate version IDs |
| scene | Existing edgeLayout JSON strings | Existing layout save and action loading |
| channel | type, url/devicePath, or one video file | Native channel service and actual channel ID |
| schedule | periods with week/begin/end; Sunday=0 | Durable time template |
| task | overrides, roi areas/shieldedAreas, channel/scene and optional schedule references | Existing parameter validation and construction, initially disabled |

Use native model types such as yolov8_det, classify, feature, ocr and dino. Generic detector/classifier names are not guessed. Model config supports normalizationMode, colorChannel and artifactRoles; unknown fields fail explicitly. Artifact roles include model, encoder, decoder, vocab, tokenizer and characters. Renaming a binary does not change its runtime.

Channels support RTSP, USB, uploaded video and registered GB28181 sources. ONVIF accepts a resolved RTSP stream or full native save parameters inside `config.onvif` (endpoint, username, password, profileToken and related options). Full ONVIF configurations get stable, version-specific source IDs. GB28181 still requires the corresponding SIP registration.

Task versions use private execution scenes for their parameters and shared model references. Preparation never enables the task. Activation stops older versions first; disabling stops all versions. Outside its time window a task reports scheduled; starting and failed states never masquerade as running. Confirm final state through inventory.

## Storage and verification

Limits: 1 MiB chunks, 5 GiB files, eight unfinished uploads per account, 24-hour expiry and a 256 MiB disk reserve including outstanding reservations. SHA-256 gates readiness. Content files are deduplicated; native model/video files are execution copies, not a second platform catalog.

SQLite records intent and reserved IDs before effects. Retries reuse those IDs. Native readback, persistence failures and import completion markers prevent receipt-only success. Historical versions, operations and completed blobs remain retained; retention and capacity require deployment-specific validation. Local edits can cause drift and should be reconciled from the platform.

Run `bash scripts/build_cpu_test.sh`, `./build_cpu/cosmo-tests "[management]"`, the complete test suite, `bash scripts/format_check.sh --staged --check` and `npm run docs:verify`. Coverage includes recovery, ownership, immutable versions, dependency protection, upload verification, real HTTP PUT, native task preparation, schedule persistence and ONVIF persistence. Inference, video sources, upgrade rollback and power-loss endurance require separate device acceptance.
