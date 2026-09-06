resource "random_password" "password" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}"
}

resource "terraform_data" "init" {
  triggers_replace = [
    var.database,
    var.schema,
    filesha256("${path.module}/provision.sh"),
    filesha256("${path.module}/init.sql"),
  ]

  provisioner "local-exec" {
    command = "timeout 10m bash \"${path.module}/provision.sh\""
    environment = {
      SSH_HOST      = var.database.ssh.host
      SSH_PORT      = tostring(var.database.ssh.port)
      SSH_USERNAME  = var.database.ssh.username
      DB_NAMESPACE  = var.database.namespace
      DB_DEPLOYMENT = var.database.deployment
      APP_SCHEMA    = var.schema
      APP_PASSWORD  = random_password.password.result
    }
  }

  lifecycle {
    replace_triggered_by = [random_password.password]
  }
}
