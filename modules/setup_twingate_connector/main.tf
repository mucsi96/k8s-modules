# Twingate remote network plus the host-level connector. The connector is
# installed on the Hetzner host itself by provision_hetzner_server's cloud-init
# (systemd unit twingate-connector), not as an in-cluster Helm release, so that
# SSH and the K8s API stay reachable through Twingate even when the cluster is
# broken. These resources must exist before hcloud_server so the tokens can be
# baked into the server's user_data — hence this module is created first and
# takes no input from the server.
resource "twingate_remote_network" "home_cluster" {
  name     = "${var.environment_name} cluster"
  location = "ON_PREMISE"
}

resource "twingate_connector" "host" {
  remote_network_id      = twingate_remote_network.home_cluster.id
  name                   = "${var.environment_name}-host"
  status_updates_enabled = true
}

resource "twingate_connector_tokens" "host" {
  connector_id = twingate_connector.host.id
}
