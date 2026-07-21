# tech-pulse-documentdb

Terraform to spin up an EC2 + Amazon DocumentDB cluster for the SA session.

## What it builds

- 1 EC2 (`t3.micro`, Amazon Linux 2) — SSH open only to your public IP (auto-detected at apply time).
- 1 DocumentDB 8.0.1 cluster with 3 instances (primary + 2 replicas), TLS on, encrypted at rest.
- 2 security groups wiring them up (DocDB port 27017 only reachable from the EC2 SG).
- Uses the account's default VPC + subnets.

`user_data` installs on the EC2:

- `mongosh` + DocDB CA bundle + a `connect.sh` helper (endpoint pre-filled)
- `git`
- Go (pinned, `1.22.5`) from the official tarball

## Prereqs

- Terraform >= 1.5
- AWS credentials exported in the shell (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`)
- An EC2 key pair (see below)

### Create an EC2 key pair (once). IGNORE if you already have a key pair

1. AWS Console → **EC2** → **Key Pairs** → **Create key pair**
2. Name it (e.g. `demo-key`) — remember this name, you'll put it in `terraform.tfvars`
3. Type: **RSA**, Format: **.pem**
4. Click **Create** — a `.pem` file downloads automatically
5. Move it somewhere sensible and lock it down:

   ```bash
   mv ~/Downloads/demo-key.pem ~/your preferred local directory/
   chmod 400 /path to key pair/demo-key.pem
   ```

   The `chmod 400` is required — SSH refuses keys with looser permissions.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set password, ec2_key_name, project_name

terraform init
terraform apply           # ~10 min (DocDB is the slow part)
terraform output          # SSH command, DocDB endpoint, etc.
```

SSH in:

```bash
ssh -i /path/to/your-key.pem ec2-user@<ec2_public_ip>
```

On the EC2:

```bash
./connect.sh -p '<your-password>'                # opens a mongosh shell
```

Tear down when done:

```bash
terraform destroy
```

## Files

| file                       | what it is                                                           |
| -------------------------- | -------------------------------------------------------------------- |
| `main.tf`                  | providers, VPC lookups, SGs, DocDB cluster + 3 instances, EC2        |
| `variables.tf`             | inputs (region, instance classes, key name, password, ...)           |
| `outputs.tf`               | SSH command, DocDB endpoint, mongosh helper, connection URI template |
| `user_data.sh.tftpl`       | EC2 bootstrap script (mongosh, git, Go)                              |
| `terraform.tfvars.example` | sample values — copy to `terraform.tfvars` and edit                  |
| `.gitignore`               | keeps `terraform.tfvars`, state files, `.pem`s, etc. out of git      |

## Notes

- SSH ingress is locked to the public IP terraform sees at apply time. If your IP changes (café, VPN), re-run `terraform apply` to refresh the SG.
- Applying will replace the EC2 if `user_data` changes — expect a new public IP.
- DocumentDB 8.0 requires Graviton or `db.t3.medium`. `db.r8g.*` is NOT supported yet.
