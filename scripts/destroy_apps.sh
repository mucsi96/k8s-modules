#!/bin/bash

set -euo pipefail

source .venv/bin/activate

terraform destroy \
  -target=module.setup_backup_app \
  -target=module.setup_learn_language_app \
  -target=module.setup_hello_app \
  -target=module.setup_training_log_app
