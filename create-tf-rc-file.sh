#!/bin/bash

# todo: SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

local_scylla_provider_directory="/code/scylladb/terraform-provider-scylladbcloud"

cat >~/.terraformrc <<EOF
provider_installation {
  # Use an overridden package directory for the given provider. This disables the version and
  # checksum verifications for this provider and forces Terraform to look for the
  # null provider plugin in the given directory.
  dev_overrides {
    "registry.terraform.io/scylladb/scylladbcloud" = "$local_scylla_provider_directory"
  }
  # For all other providers, install them directly from their origin provider
  # registries as normal. If you omit this, Terraform will _only_ use
  # the dev_overrides block, and so no other providers will be available.
  direct {}
}
EOF

echo "~/.terraformrc" file created