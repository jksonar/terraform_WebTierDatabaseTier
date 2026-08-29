# Web Tier + Database Tier (Azure)

Terraform for a two-tier Azure architecture: a public Load Balancer fronting
two Linux web VMs in a web subnet, backed by an Azure Database Flexible
Server (PostgreSQL or MySQL) in a private, delegated DB subnet.

```
                         Internet
                            |
                            v
                  +------------------+
                  | Public Load      |
                  | Balancer         |
                  +------------------+
                            |
                            v
              +---------------------------+
              |        Web Subnet         |
              |                           |
              |  +------+     +------+    |
              |  | VM 1 |     | VM 2 |    |
              |  +------+     +------+    |
              |                           |
              +---------------------------+
                            |
              +---------------------------+
              |       DB Subnet           |
              |                           |
              |    +----------------+     |
              |    | Azure MySQL /  |     |
              |    | PostgreSQL     |     |
              |    +----------------+     |
              |                           |
              +---------------------------+

Resource Group
    +-- VNet
    +-- Web Subnet
    |      +-- NSG
    |      +-- VM x2
    +-- DB Subnet
           +-- NSG
           +-- PostgreSQL/MySQL Flexible Server
```

## What gets created

| File | Resources |
|---|---|
| [main.tf](main.tf) | Resource group, shared locals |
| [network.tf](network.tf) | VNet, web subnet, DB subnet (delegated to the Flexible Server), private DNS zone + VNet link |
| [nsg.tf](nsg.tf) | Web NSG (HTTP inbound, Azure LB health-probe tag, SSH inbound), DB NSG (DB port only from the web subnet, deny-all fallback) |
| [loadbalancer.tf](loadbalancer.tf) | Standard public Load Balancer, backend pool, HTTP health probe, load-balancing rule |
| [vm.tf](vm.tf) | 2x Ubuntu 22.04 Linux VMs (no public IPs — reachable only through the LB), NICs joined to the backend pool, SSH key pair, nginx bootstrap via `custom_data` |
| [database.tf](database.tf) | PostgreSQL or MySQL Flexible Server (chosen by `db_engine`) + default database, private networking only (no public endpoint) |
| [outputs.tf](outputs.tf) | LB public IP, VM names/private IPs, DB FQDN and credentials |

The web VMs have **no public IPs** — all inbound traffic reaches them only
through the Load Balancer. The database has **no public network access** —
it's only reachable from the web subnet over the VNet.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), logged in (`az login`) with a subscription selected (`az account set --subscription <id>`)
- Terraform authenticates to Azure using your `az login` session (the `azurerm` provider picks it up automatically — no credentials need to be hardcoded)

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — at minimum, lock down allowed_ssh_source_cidr

terraform init
terraform plan
terraform apply
```

To reach the web tier:

```bash
terraform output load_balancer_public_ip
curl http://$(terraform output -raw load_balancer_public_ip)
```

To tear everything down:

```bash
terraform destroy
```

## Variables

| Name | Default | Description |
|---|---|---|
| `prefix` | `webdb` | Prefix used to name every resource |
| `location` | `centralus` | Azure region (see **Free Subscription notes** below) |
| `vnet_address_space` | `["10.0.0.0/16"]` | VNet CIDR |
| `web_subnet_prefix` | `10.0.1.0/24` | Web subnet CIDR |
| `db_subnet_prefix` | `10.0.2.0/24` | DB subnet CIDR |
| `vm_count` | `2` | Number of web tier VMs |
| `vm_size` | `Standard_D2als_v7` | VM size (see **Free Subscription notes** below) |
| `admin_username` | `azureadmin` | Admin username on the web VMs |
| `allowed_ssh_source_cidr` | `0.0.0.0/0` | CIDR allowed to SSH into the web VMs — **restrict this before applying** |
| `db_engine` | `postgresql` | `postgresql` or `mysql` |
| `db_sku_name` | `B_Standard_B1ms` | Flexible Server SKU (Burstable tier) |
| `db_storage_mb` | `32768` | Storage size in MB |
| `db_version` | *(auto)* | Engine version; defaults to `16` (Postgres) or `8.0.21` (MySQL) if left blank |
| `db_admin_username` | `dbadmin` | Database administrator login |
| `db_name` | `appdb` | Default database/schema name created on the server |
| `tags` | `{Project = "web-db-tier", Environment = "dev"}` | Tags applied to all resources |

## Outputs

- `load_balancer_public_ip` — public IP to reach the web tier
- `web_vm_names`, `web_vm_private_ips` — web VM identity/networking
- `vm_ssh_private_key_path` — path to the generated SSH private key (VMs have no public IP, so SSH requires a bastion/VPN/Azure Bastion into the VNet)
- `database_engine`, `database_fqdn`, `database_admin_username` — DB connection info
- `database_admin_password` — DB admin password (sensitive; `terraform output -raw database_admin_password` to reveal)

## Free Subscription notes

If you're running this on an Azure Free/Trial subscription, two things bit us
during testing and are already reflected in the defaults above:

1. **Legacy VM sizes are blocked subscription-wide.** `Standard_B1s` (and
   every other B-series, A-series, and D/E-series-**v3** size) returns
   `SkuNotAvailable` / `NotAvailableForSubscription` in every region — this
   is a subscription policy restriction, not a transient capacity issue,
   despite the error mentioning "Capacity Restrictions". Only newer VM
   generations (`*_v7` Dv7/Fv7 families, or ARM-based `Bpsv2` sizes) are
   actually open. That's why `vm_size` defaults to `Standard_D2als_v7`.

2. **PostgreSQL/MySQL Flexible Server isn't enabled in every region.**
   `eastus`, for example, returns zero supported editions/SKUs for this
   subscription — the create call fails with `ParameterOutOfRange: The
   value of the 'Version' should be in: []`, which is really "this service
   has no capability here for your subscription", not a version problem.
   Regions confirmed to work: `centralus`, `northeurope`, `uksouth`,
   `eastasia`, `southeastasia`. That's why `location` defaults to
   `centralus`.

If you hit either error again (e.g. after changing `vm_size`/`location`),
check what's actually open for your subscription before retrying:

```bash
# VM SKU restrictions in a region
az rest --method get --url "https://management.azure.com/subscriptions/<sub-id>/providers/Microsoft.Compute/skus?api-version=2021-07-01&\$filter=location eq '<region>'" \
  | jq '.value[] | select(.name=="<vm-size>") | {name, restrictions}'

# Flexible Server capability in a region
az rest --method get --url "https://management.azure.com/subscriptions/<sub-id>/providers/Microsoft.DBforPostgreSQL/locations/<region>/capabilities?api-version=2022-12-01"
```

## Security notes

- `allowed_ssh_source_cidr` defaults to `0.0.0.0/0` for convenience — set it
  to your own IP/CIDR before applying anywhere near production.
- Database credentials are generated with `random_password` and stored in
  Terraform state (`database_admin_password` output is marked sensitive).
  Treat your `.tfstate` file as a secret — it is already excluded from git
  via `.gitignore`, but if you use remote state, make sure the backend
  encrypts it at rest and restricts access.
- The generated SSH private key (`<prefix>-vm-ssh.pem`) is written to the
  project directory by `local_sensitive_file`; `*.pem` is excluded via
  `.gitignore` so it won't be committed.
