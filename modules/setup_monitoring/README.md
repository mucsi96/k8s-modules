# Monitoring stack

Deploys a Kubernetes monitoring stack inspired by the
[`kubetools`](https://github.com/mucsi96/kubetools) `deploy_kubenetes_monitoring`
Ansible role:

- **kube-prometheus-stack** &mdash; Prometheus + Alertmanager + Grafana, with
  default service/pod monitor selectors disabled so any `ServiceMonitor` /
  `PodMonitor` in the cluster is picked up.
- **loki** (Loki v3.x in `singleBinary` deployment mode) &mdash; modern
  replacement for the now-deprecated `loki-stack` chart.
- **promtail** &mdash; DaemonSet log shipper, pushing logs to Loki.
- **kubernetes-dashboard** v7.x &mdash; the official upstream dashboard,
  fronted by Kong, auto-authenticated against a dedicated cluster-admin
  service-account token injected by Traefik.

## Grafana persistence

Grafana stores all of its state (dashboards, users, datasources, ...) in a
dedicated **Postgres schema** (default name: `grafana`) within the existing
shared Postgres database. The schema is created by a one-shot Kubernetes Job
that runs `psql` before Grafana is rolled out. Persisting metadata in Postgres
means dashboards edited in the UI survive Grafana pod restarts and can be
backed up alongside the rest of the application data.

Connection wiring is delivered to Grafana via the `GF_DATABASE_URL` environment
variable, sourced from a `grafana-db-credentials` Kubernetes Secret. The same
schema is also added as a Grafana datasource so users can build dashboards
from any other table in the Postgres database.

## Backup

The module exposes a `grafana_backup_config` output that matches the schema
used by [`setup_backup_app`](../setup_backup_app). Pass it through
`setup_backup_app.additional_dbs` to include the Grafana schema in the
scheduled Postgres backups uploaded to Azure Blob Storage.

## Public access

Each UI is exposed on its own subdomain of the cluster's DNS zone:

| Tool | URL |
| --- | --- |
| Grafana | `https://grafana.<dns_zone>/` |
| Prometheus | `https://prometheus.<dns_zone>/` |
| Kubernetes Dashboard | `https://dashboard.<dns_zone>/` |

The wildcard CNAME and Cloudflare tunnel set up by
`setup_ingress_controller` already routes every subdomain through Traefik,
and a **Cloudflare Zero Trust Access application** is created for each
hostname &mdash; reusing the same SSO policy that protects the Traefik
dashboard.

For convenience, a Traefik `Middleware` rewrites the bare root path of each
subdomain to a useful default:

| Subdomain | `/` redirect target |
| --- | --- |
| `grafana.*` | `/login` |
| `prometheus.*` | `/targets` |
| `dashboard.*` | `/#/workloads?namespace=_all` |

So you can type `prometheus.example.com` in your browser without remembering
the deep link to the targets page, etc.
