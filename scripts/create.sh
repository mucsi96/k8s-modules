#!/bin/bash

source .venv/bin/activate

terraform plan -out=tfplan
terraform apply -auto-approve tfplan