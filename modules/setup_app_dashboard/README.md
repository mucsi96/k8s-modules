# Observatory inventory

`apps` accepts deployed application descriptors and repository-only entries:

```hcl
{
  name       = "p07"
  repository = "mucsi96/p07"
  url        = "https://github.com/mucsi96/p07"
}
```

Omitted or empty `namespace` means repository-only tracking. These entries are
included in Observatory's configuration but create no Kubernetes reader Role or
RoleBinding. Existing application namespace permissions retain their addresses.

Deploy Observatory's repository-only inventory support before applying such
entries. After applying inventory changes, rerun the Observatory pipeline to
refresh its chart-owned configuration. The GitHub token must have read access to
the tracked repositories, including issues, pull requests, checks and Actions.
