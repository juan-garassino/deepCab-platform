# Module: `dns`

Optional Cloud DNS records. Default **disabled** — staging/prod set
`enabled = true` and pass a `zone_name` + `dns_name`. Dev uses raw Cloud Run
`*.run.app` URLs and skips this module.

## Modes

- `create_zone = true` — creates a managed zone via TF
- `create_zone = false` — looks up an existing zone (recommended when DNS is owned by an external system)

## Records input

Pass a `map(object)`:

```hcl
records = {
  api = {
    type    = "CNAME"
    ttl     = 300
    rrdatas = ["ghs.googlehosted.com."]   # Cloud Run domain mapping target
  }
  mlflow = {
    type    = "A"
    ttl     = 300
    rrdatas = ["35.x.x.x"]   # load balancer IP
  }
}
```

## Outputs

| Name | Description |
|---|---|
| `enabled` | Effective on/off. |
| `zone_name` | The zone used (created or referenced). |
| `record_names` | Fully-qualified DNS names produced. |
