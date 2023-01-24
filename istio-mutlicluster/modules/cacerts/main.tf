resource "tls_private_key" "ca" {
    algorithm = "RSA"
}

resource "tls_self_signed_cert" "ca" {
    private_key_pem = tls_private_key.ca.private_key_pem
    is_ca_certificate = true
    set_subject_key_id = true
    set_authority_key_id = true
    validity_period_hours = 87600

    allowed_uses = [
      "cert_signing",
      "crl_signing"
    ]

    subject {
        common_name = "root.multicluster.com"
    }

    depends_on = [
      tls_private_key.ca
    ]
}

resource "tls_private_key" "cert" {
    for_each = toset(var.clusters)
    algorithm = "RSA"
}

resource "tls_cert_request" "cert" {

    for_each = toset(var.clusters)

    private_key_pem = tls_private_key.cert["${each.key}"].private_key_pem

    subject {
        common_name = "${each.key}.intermediate.multicluster.com"
    }

    depends_on = [
      tls_private_key.cert
    ]
}

resource "tls_locally_signed_cert" "cert" {
    for_each = toset(var.clusters)

    cert_request_pem = tls_cert_request.cert["${each.key}"].cert_request_pem

    ca_private_key_pem = tls_private_key.ca.private_key_pem
    ca_cert_pem = tls_self_signed_cert.ca.cert_pem

    is_ca_certificate = true
    set_subject_key_id = true
    validity_period_hours = 87600

    allowed_uses = [
      "cert_signing",
      "crl_signing"
    ]

    depends_on = [
      tls_cert_request.cert,
      tls_private_key.ca,
      tls_self_signed_cert.ca
    ]
}