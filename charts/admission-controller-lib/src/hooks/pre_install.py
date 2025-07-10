import asyncio
import base64
import logging
import os
from datetime import datetime, UTC, timedelta

from apolo_kube_client import ResourceNotFound, KubeClient
from cryptography import x509
from cryptography.hazmat._oid import NameOID
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from hooks.kube import create_kube_config
from kubernetes.client.models import V1Secret

logger = logging.getLogger(__name__)

PUBLIC_EXPONENT = 65537
KEY_SIZE = 2048
EXP_DAYS = 365 * 10  # 10 years
# todo: consider lower expiration time with the ability to rotate certs


def generate_ca_and_server_cert(service_dns_name: str) -> dict[str, str]:
    """
    Generates a self-signed CA cert and a server key/cert pair, signed by that CA.
    """
    now = datetime.now(tz=UTC)

    ca_key = rsa.generate_private_key(
        public_exponent=PUBLIC_EXPONENT, key_size=KEY_SIZE, backend=default_backend()
    )

    # build a self-signed CA certificate
    ca_subject = x509.Name(
        [
            x509.NameAttribute(NameOID.COMMON_NAME, "Apolo CA"),
        ]
    )

    ca_cert = (
        x509.CertificateBuilder()
        .subject_name(ca_subject)
        .issuer_name(ca_subject)
        .public_key(ca_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now)
        .not_valid_after(now + timedelta(days=EXP_DAYS))
        .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
        .sign(private_key=ca_key, algorithm=hashes.SHA256(), backend=default_backend())
    )

    # generate server private key
    server_key = rsa.generate_private_key(
        public_exponent=PUBLIC_EXPONENT, key_size=KEY_SIZE, backend=default_backend()
    )

    # create a CSR-like certificate for the server
    server_subject = x509.Name(
        [
            x509.NameAttribute(NameOID.COMMON_NAME, service_dns_name),
        ]
    )

    alt_names = x509.SubjectAlternativeName(
        [
            x509.DNSName(service_dns_name),
        ]
    )

    server_cert_builder = (
        x509.CertificateBuilder()
        .subject_name(server_subject)
        .issuer_name(ca_cert.subject)
        .public_key(server_key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now)
        .not_valid_after(now + timedelta(days=EXP_DAYS))
        .add_extension(alt_names, critical=False)
    )

    server_cert = server_cert_builder.sign(
        private_key=ca_key, algorithm=hashes.SHA256(), backend=default_backend()
    )

    # convert to PEM strings
    ca_crt_pem = ca_cert.public_bytes(serialization.Encoding.PEM).decode("utf-8")
    tls_crt_pem = server_cert.public_bytes(serialization.Encoding.PEM).decode("utf-8")
    tls_key_pem = server_key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.TraditionalOpenSSL,
        serialization.NoEncryption(),
    ).decode("utf-8")

    return {
        "ca.crt": base64.b64encode(ca_crt_pem.encode()).decode(),
        "tls.crt": base64.b64encode(tls_crt_pem.encode()).decode(),
        "tls.key": base64.b64encode(tls_key_pem.encode()).decode(),
    }


async def main():
    namespace = os.environ["K8S_NS"]
    service_name = os.environ["SERVICE_NAME"]
    cert_secret_name = os.environ["CERT_SECRET_NAME"]
    service_dsn = f"{service_name}.{namespace}.svc"
    kube_config = create_kube_config()

    async with KubeClient(config=kube_config) as kube_client:
        try:
            await kube_client.core_v1.secret.get(name=cert_secret_name)
        except ResourceNotFound:
            # let's create certificates, and put them into a secret
            certs = generate_ca_and_server_cert(service_dns_name=service_dsn)
            secret = V1Secret(
                api_version="v1",
                kind="Secret",
                metadata={"name": cert_secret_name},
                data=certs,
                type="kubernetes.io/tls",
            )
            await kube_client.core_v1.secret.create(model=secret)


if __name__ == "__main__":
    asyncio.run(main())
