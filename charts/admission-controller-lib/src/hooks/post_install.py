import asyncio
import json
import logging
import os

from apolo_kube_client.client import kube_client_from_config
from apolo_kube_client.errors import ResourceExists
from hooks.kube import (
    create_admission_controller,
    create_kube_config,
    update_admission_controller,
)

logger = logging.getLogger(__name__)

TIMEOUT_DEFAULT_S = 30  # seconds


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

    async with kube_client_from_config(kube_config) as kube:
        try:
            await create_admission_controller(
                kube,
                service_name=service_name,
                secret_name=cert_secret_name,
                webhook_path=webhook_path,
                object_selector=object_selector,
                namespace_selector=namespace_selector,
                rules=rules,
                failure_policy=failure_policy,
                reinvocation_policy=reinvocation_policy,
                timeout_seconds=timeout_seconds,
            )
        except ResourceExists:
            await update_admission_controller(
                kube,
                service_name=service_name,
                secret_name=cert_secret_name,
                webhook_path=webhook_path,
                object_selector=object_selector,
                namespace_selector=namespace_selector,
                rules=rules,
                failure_policy=failure_policy,
                reinvocation_policy=reinvocation_policy,
                timeout_seconds=timeout_seconds,
            )


if __name__ == "__main__":
    asyncio.run(main())
