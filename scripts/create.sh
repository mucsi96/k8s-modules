#!/bin/bash

terraform plan -out=tfplan
terraform apply -auto-approve tfplan