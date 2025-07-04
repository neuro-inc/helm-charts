import os
from pathlib import Path
from typing import Any

from apolo_kube_client.client import KubeClient
from apolo_kube_client.config import KubeClientAuthType, KubeConfig

ADMISSION_CONTROLLER_PREFIX = "admission-controller"
SECRET_PREFIX = f"{ADMISSION_CONTROLLER_PREFIX}-certs"


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


def gen_secrets_url(kube: KubeClient, secret_name: str | None = None) -> str:
    """Generates kubernetes API URL for secrets"""
    url = f"{kube.namespace_url}/secrets"
    if secret_name is not None:
        url = f"{url}/{secret_name}"
    return url


def gen_admission_controller_url(
    kube: KubeClient, admission_controller_name: str | None = None
) -> str:
    """Generates kubernetes API URL for an admission controller"""
    url = f"{kube._base_url}/apis/admissionregistration.k8s.io/v1/mutatingwebhookconfigurations"  # noqa
    if admission_controller_name is not None:
        url = f"{url}/{admission_controller_name}"
    return url


async def get_cert_secret(
    kube: KubeClient,
    secret_name: str,
) -> dict[str, str]:
    """Returns a cert secret contents"""
    url = gen_secrets_url(kube, secret_name)
    response = await kube.get(url)
    return response["data"]


async def create_cert_secret(
    kube: KubeClient,
    secret_name: str,
    certs: dict[str, str],
):
    """Creates a certificates secret"""
    payload = {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {"name": secret_name, "labels": {}},
        "data": certs,
        "type": "kubernetes.io/tls",
    }
    await kube.post(f"{kube.namespace_url}/secrets", json=payload)


async def get_admission_controller(
    kube: KubeClient,
    service_name: str,
) -> dict[str, Any]:
    """Returns an admission controller"""
    admission_controller_name = f"{ADMISSION_CONTROLLER_PREFIX}-{service_name}"
    url = gen_admission_controller_url(kube, admission_controller_name)
    return await kube.get(url)


def gen_webhook_payload(
    namespace: str,
    service_name: str,
    path: str,
    ca_bundle: str,
    failure_policy: str,
    reinvocation_policy: str | None,
    object_selector: dict[str, Any],
    namespace_selector: dict[str, Any],
    rules: list[dict[str, Any]],
    timeout_seconds: int,
) -> dict[str, Any]:
    webhook_name = f"{service_name}.apolo.us"

    rules = rules or [
        {
            "operations": ["CREATE"],
            "apiGroups": [""],
            "apiVersions": ["v1"],
            "resources": ["pods"],
        }
    ]

    webhook = {
        "name": webhook_name,
        "admissionReviewVersions": ["v1", "v1beta1"],
        "sideEffects": "None",
        "clientConfig": {
            "service": {"namespace": namespace, "name": service_name, "path": path},
            "caBundle": ca_bundle,
        },
        "rules": rules,
        "failurePolicy": failure_policy,
        "timeoutSeconds": timeout_seconds,

    }
    if reinvocation_policy:
        webhook["reinvocationPolicy"] = reinvocation_policy
    if object_selector:
        webhook["objectSelector"] = object_selector
    if namespace_selector:
        webhook["namespaceSelector"] = namespace_selector
    return webhook


async def create_admission_controller(
    kube: KubeClient,
    service_name: str,
    secret_name: str,
    webhook_path: str,
    object_selector: dict[str, Any],
    namespace_selector: dict[str, Any],
    rules: list[dict[str, Any]],
    failure_policy: str,
    reinvocation_policy: str | None,
    timeout_seconds: int,
) -> dict[str, Any]:
    url = gen_admission_controller_url(kube)
    admission_controller_name = f"{ADMISSION_CONTROLLER_PREFIX}-{service_name}"
    certs = await get_cert_secret(kube, secret_name)
    ca_bundle = certs["ca.crt"]

    webhook = gen_webhook_payload(
        namespace=kube.namespace,
        service_name=service_name,
        path=webhook_path,
        ca_bundle=ca_bundle,
        failure_policy=failure_policy,
        reinvocation_policy=reinvocation_policy,
        object_selector=object_selector,
        namespace_selector=namespace_selector,
        rules=rules,
        timeout_seconds=timeout_seconds,
    )

    payload = {
        "apiVersion": "admissionregistration.k8s.io/v1",
        "kind": "MutatingWebhookConfiguration",
        "metadata": {"name": admission_controller_name},
        "webhooks": [webhook],
    }

    # todo: ensure that service is already responding to pings ?
    return await kube.post(url, json=payload)


async def update_admission_controller(
    kube: KubeClient,
    service_name: str,
    secret_name: str,
    webhook_path: str,
    object_selector: dict[str, Any],
    namespace_selector: dict[str, Any],
    rules: list[dict[str, Any]],
    failure_policy: str,
    reinvocation_policy: str | None,
    timeout_seconds: int,
) -> dict[str, Any] | None:
    admission_controller_name = f"{ADMISSION_CONTROLLER_PREFIX}-{service_name}"
    url = gen_admission_controller_url(kube, admission_controller_name)
    certs = await get_cert_secret(kube, secret_name)
    ca_bundle = certs["ca.crt"]

    webhook = gen_webhook_payload(
        namespace=kube.namespace,
        service_name=service_name,
        path=webhook_path,
        ca_bundle=ca_bundle,
        failure_policy=failure_policy,
        reinvocation_policy=reinvocation_policy,
        object_selector=object_selector,
        namespace_selector=namespace_selector,
        rules=rules,
        timeout_seconds=timeout_seconds,
    )

    patch_body = {"webhooks": [webhook]}

    return await kube.patch(
        url, json=patch_body, headers={"Content-Type": "application/merge-patch+json"}
    )
