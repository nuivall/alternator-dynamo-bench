# alternator-dynamo-bench

# How to configure (first usage only)

1. Configure AWS CLI if not done already
2. Install terraform (https://developer.hashicorp.com/terraform/downloads?product_intent=terraform)
3. Run `terraform init` in repository root directory

# How to provision loaders

1. Run `terraform apply -auto-approve` in repository root directory
2. Do benchmarking (see #Benchmarking DynamoDB or #Benchmarking Alternator)
3. Run `terraform destroy` when you're done with the instances

# Benchmarking DynamoDB

1. Run `terraform apply -auto-approve -target=module.dynamodb` to provision table
2. Run `./bench.sh`
3. Run `terraform destroy -auto-approve -target=module.dynamodb` to delete table

# Benchmarking Alternator

TODO

# Tips

- Run `terraform output -json loader_public_ips` anytime to get loader IPs
- Use `ssh -v -o "StrictHostKeyChecking no" -i ./private_key ubuntu@{IP}` to login into any instance
