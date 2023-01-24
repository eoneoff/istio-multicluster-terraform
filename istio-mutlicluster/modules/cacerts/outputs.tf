output "root-cert" {
    value = tls_self_signed_cert.ca.cert_pem
}

output "certs" {
    value = {
        for name, cert in tls_locally_signed_cert.cert : name => cert.cert_pem
    }
}

output "keys" {
    value = {
        for name, key in tls_private_key.cert : name => key.private_key_pem
    }
}