import asyncio
import json
import logging
import os

from apolo_kube_client import KubeClient
from hooks.kube import create_kube_config
from kubernetes.client.models import (
    V1Secret,
    V1MutatingWebhookConfiguration,
    V1MutatingWebhook,
    V1RuleWithOperations,
    AdmissionregistrationV1WebhookClientConfig,
    AdmissionregistrationV1ServiceReference,
    V1LabelSelector,
    V1ObjectMeta,
    V1LabelSelectorRequirement,
)


logger = logging.getLogger(__name__)

TIMEOUT_DEFAULT_S = 30  # seconds
ADMISSION_CONTROLLER_PREFIX = "admission-controller"
SECRET_PREFIX = f"{ADMISSION_CONTROLLER_PREFIX}-certs"


async def main():
    service_name = os.environ["SERVICE_NAME"]
    webhook_path = os.environ["WEBHOOK_PATH"]
    cert_secret_name = os.environ["CERT_SECRET_NAME"]
    object_selector = json.loads(os.environ["OBJECT_SELECTOR"])
    namespace_selector = json.loads(os.environ["NAMESPACE_SELECTOR"])
    rules = json.loads(os.environ.get("RULES") or "[]")
    failure_policy = os.environ["FAILURE_POLICY"]
    reinvocation_policy = os.environ.get("REINVOCATION_POLICY")
    timeout_seconds = int(os.environ.get("TIMEOUT_SECONDS") or TIMEOUT_DEFAULT_S)

    kube_config = create_kube_config()

    async with KubeClient(config=kube_config) as kube_client:
        admission_controller_name = f"{ADMISSION_CONTROLLER_PREFIX}-{service_name}"
        secret: V1Secret = await kube_client.core_v1.secret.get(name=cert_secret_name)

        client_config = AdmissionregistrationV1WebhookClientConfig(
            service=AdmissionregistrationV1ServiceReference(
                namespace=kube_client.namespace,
                name=service_name,
                path=webhook_path,
            ),
            ca_bundle=secret.data["ca.crt"],
        )

        object_selector = (
            V1LabelSelector(
                match_labels=object_selector.get("matchLabels", {}),
                match_expressions=[
                    V1LabelSelectorRequirement(
                        key=expr["key"],
                        operator=expr["operator"],
                        values=expr.get("values", []),
                    )
                    for expr in namespace_selector.get("matchExpressions", [])
                ],
            )
            if object_selector
            else None
        )

        namespace_selector = (
            V1LabelSelector(
                match_labels=namespace_selector.get("matchLabels", {}),
                match_expressions=[
                    V1LabelSelectorRequirement(
                        key=expr["key"],
                        operator=expr["operator"],
                        values=expr.get("values", []),
                    )
                    for expr in namespace_selector.get("matchExpressions", [])
                ],
            )
            if namespace_selector
            else None
        )

        rules = (
            [
                V1RuleWithOperations(
                    operations=rule["operations"],
                    api_groups=rule["apiGroups"],
                    api_versions=rule["apiVersions"],
                    resources=rule["resources"],
                    scope=rule["scope"],
                )
                for rule in rules
            ]
            if rules
            else [
                V1RuleWithOperations(
                    operations=["CREATE"],
                    api_groups=[""],
                    api_versions=["v1"],
                    resources=["pods"],
                )
            ]
        )

        await kube_client.admission_registration_k8s_io_v1.mutating_webhook_configuration.create_or_update(
            model=V1MutatingWebhookConfiguration(
                api_version="admissionregistration.k8s.io/v1",
                kind="MutatingWebhookConfiguration",
                metadata=V1ObjectMeta(name=admission_controller_name),
                webhooks=[
                    V1MutatingWebhook(
                        name=f"{service_name}.apolo.us",
                        admission_review_versions=["v1", "v1beta1"],
                        side_effects="None",
                        client_config=client_config,
                        object_selector=object_selector,
                        namespace_selector=namespace_selector,
                        rules=rules,
                        failure_policy=failure_policy,
                        reinvocation_policy=reinvocation_policy,
                        timeout_seconds=timeout_seconds,
                    )
                ],
            )
        )


if __name__ == "__main__":
    asyncio.run(main())
