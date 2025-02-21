import asyncio
import sys


def main():
    if len(sys.argv) < 2:
        raise RuntimeError("not enough args")

    _, cmd = sys.argv

    match cmd:
        case "pre-install":
            from hooks.pre_install import main
            asyncio.run(main())
        case "post-install":
            from hooks.post_install import main
            asyncio.run(main())
        case _:
            raise RuntimeError(f"unknown cdm: {cmd}")


if __name__ == "__main__":
    main()
