# Twingate remote network plus the host-level connector. The connector is
# installed on the Netcup host by provision_server's image bootstrap script
# (systemd unit twingate-connector), not as an in-cluster Helm release, so that
# SSH and the K8s API stay reachable through Twingate even when the cluster is
# broken. These resources must exist before the Debian installation so their
# tokens can be included in the custom script; this module is created first and
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
