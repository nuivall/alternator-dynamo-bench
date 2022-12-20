# alternator-dynamo-bench

# How to configure (first usage only)

1. Configure AWS CLI if not done already
2. Install terraform (https://developer.hashicorp.com/terraform/downloads?product_intent=terraform)
3. Run `terraform init` in repository root directory

# How to run

1. Run `terraform apply -auto-approve` in repository root directory
2. ...
3. Run  `terraform destroy` when you're done with the instances

# Tips

- Run `terraform output -json loader_public_ips` anytime to get loaders IPs
- Use `ssh -v -i ./private_key ubuntu@{IP}` to login into any instance