import asyncio
import json
import logging
import os

from apolo_kube_client.client import kube_client_from_config
from apolo_kube_client.errors import ResourceExists

from hooks.kube import create_kube_config, create_admission_controller, update_admission_controller

logger = logging.getLogger(__name__)


async def main():
    service_name = os.environ["SERVICE_NAME"]
    webhook_path = os.environ["WEBHOOK_PATH"]
    object_selector = json.loads(os.environ["OBJECT_SELECTOR"])
    namespace_selector = json.loads(os.environ["NAMESPACE_SELECTOR"])
    failure_policy = os.environ["FAILURE_POLICY"]

    kube_config = create_kube_config()

    async with kube_client_from_config(kube_config) as kube:
        try:
            await create_admission_controller(
                kube,
                service_name=service_name,
                secret_name=service_name,
                webhook_path=webhook_path,
                object_selector=object_selector,
                namespace_selector=namespace_selector,
                failure_policy=failure_policy,
            )
        except ResourceExists:
            await update_admission_controller(
                kube,
                service_name=service_name,
                secret_name=service_name,
                webhook_path=webhook_path,
                object_selector=object_selector,
                namespace_selector=namespace_selector,
                failure_policy=failure_policy,
            )


if __name__ == '__main__':
    asyncio.run(main())
