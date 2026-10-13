# bucket-usage

Lists S3 buckets on a schedule and exports their size to Prometheus. Built for object storage that offers no usage
metrics to its tenants (Layer7 Garage on imdc). Standard library Python only, script in a ConfigMap, one replica.

## Metrics

| metric | labels | |
| --- | --- | --- |
| `s3_bucket_bytes` | `bucket`, `kind` | bytes at the last successful listing |
| `s3_bucket_objects` | `bucket`, `kind` | objects at the last successful listing |
| `s3_bucket_scan_success` | `bucket` | 1 if the last listing succeeded |
| `s3_bucket_scan_last_success_timestamp_seconds` | `bucket` | Unix time of the last successful listing, 0 before the first |
| `s3_bucket_scan_duration_seconds` | `bucket` | duration of the last listing |

`kind` splits a docker registry bucket by key layout: `registry_blobs`, `registry_uploads` (unfinished pushes under
`_uploads/`), `registry_repositories` (link files). Every other key is `other`.

The size series appear after the first successful listing and keep the last good values while later listings fail.

## Values

| value | default | |
| --- | --- | --- |
| `endpoint` | `""` | S3 endpoint URL with scheme, required |
| `region` | `""` | SigV4 region, required |
| `buckets` | `[]` | `- name: <bucket>` with `secret: {name, accessKeyKey, secretKeyKey}`, one credential per bucket |
| `scanIntervalSeconds` | `900` | pause between two passes over all buckets |
| `image.tag` | `3.13-alpine@sha256:…` | pinned by digest |
| `serviceMonitor.enabled` | `true` | |
| `serviceMonitor.interval` | `60s` | the exporter serves cached results, scraping is cheap |
| `serviceMonitor.labels` | `{}` | labels the Prometheus `serviceMonitorSelector` expects |

The exporter sends `User-Agent: bucket-usage/1.0`: Cloudflare in front of Layer7 rejects the default
`Python-urllib` agent with `403`, body `error code: 1010`.
