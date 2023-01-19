# alternator-dynamo-bench

# How to configure

This is needed for first the usage only.

1. Configure AWS CLI if not done already
2. Install terraform (https://developer.hashicorp.com/terraform/downloads?product_intent=terraform)
3. Run `terraform init` in repository root directory
4. Install golang
5. Run `git submodule update` in repository root directory to fetch scylla terraform provider
6. Run `go build` in terraform-provider-scylladbcloud submodule directory to build it
7. Run `./create-tf-rc-file.sh` in repository root directory, adjust `local_scylla_provider_directory` path inside the script first! (TODO: automate this)
8. Get API auth token for your account from Scylla Cloud support team.

# How to provision

1. Run `terraform apply -auto-approve` in repository root directory
2. Do benchmarking
3. Run `terraform destroy -auto-approve` when you're done with the instances and table

# Benchmarking

Benchmarking is not fully automated yet. You'd need to adjust some things but in general `./bench.sh` can run on:
 - DynamoDB
 - Alternator
 - Scylla CQL

# Tips

- Run `terraform output -json loader_public_ips` anytime to get loader IPs
- Use `ssh -v -o "StrictHostKeyChecking no" -i ./private_key ubuntu@{IP}` to login into any instance
- In case something fails during `apply` you can safely retry it to continue and reconcile the state
- Create variables files named for instance `defaults.tfvars` with following content:
`
dynamo_testing = false
scylla_cloud_token = "YOUR_TOKEN_HERE"
`
and use terraform commands with -var-file="defaults.tfvars" to avoid typing them every time.