import os
from pathlib import Path

from apolo_kube_client import KubeClientAuthType, KubeConfig


def create_kube_config() -> KubeConfig:
    endpoint_url = os.environ["K8S_API_URL"]
    auth_type = KubeClientAuthType(os.environ["K8S_AUTH_TYPE"])
    ca_path = os.environ.get("K8S_CA_PATH")
    ca_data = Path(ca_path).read_text() if ca_path else None
    token_path = os.environ["K8S_TOKEN_PATH"]
    namespace = os.environ["K8S_NS"]

    return KubeConfig(
        endpoint_url=endpoint_url,
        cert_authority_data_pem=ca_data,
        auth_type=auth_type,
        auth_cert_path=None,
        auth_cert_key_path=None,
        token=None,
        token_path=token_path,
        namespace=namespace,
    )
