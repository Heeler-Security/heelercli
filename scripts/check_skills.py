#!/usr/bin/env python3
"""Validate the public skill bundle without executing skill instructions or scans."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
from urllib.parse import unquote, urlsplit

import yaml


class UniqueLoader(yaml.SafeLoader):
    pass


def unique_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if not isinstance(key, str) or key in result:
            raise ValueError("Frontmatter keys must be unique strings")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping
)


def contained(root, path):
    if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
        raise ValueError(f"Path leaves bundle or is a symlink: {path}")
    return path


def metadata(path):
    text = path.read_text(encoding="utf-8")
    parts = re.split(r"^---[ \t]*$", text, maxsplit=2, flags=re.MULTILINE)
    if len(parts) != 3 or parts[0] or not text.startswith("---\n"):
        raise ValueError(f"Missing YAML frontmatter: {path}")
    document = yaml.load(parts[1], Loader=UniqueLoader)
    if not isinstance(document, dict):
        raise ValueError(f"Invalid frontmatter: {path}")
    name, description = document.get("name"), document.get("description")
    if (
        not isinstance(name, str)
        or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name)
        or len(name) > 64
    ):
        raise ValueError(f"Invalid skill name: {path}")
    if (
        name != path.parent.name
        or not isinstance(description, str)
        or not description.strip()
    ):
        raise ValueError(f"Folder/name mismatch or empty description: {path}")
    if not parts[2].strip():
        raise ValueError(f"Empty instructions: {path}")
    return name, description.strip(), parts[2]


def links(root, path, body):
    for target in re.findall(r"\[[^\]]*\]\(([^\s)]+)(?:\s+[^)]*)?\)", body):
        url = urlsplit(target)
        if url.scheme in {"https", "http", "mailto"} or not url.path:
            continue
        if url.scheme or url.netloc or url.path.startswith("/"):
            raise ValueError(f"Unsupported link in {path}: {target}")
        resolved = contained(root, path.parent / unquote(url.path))
        if not resolved.exists():
            raise ValueError(f"Broken relative link in {path}: {target}")


def check_examples(name, body, commands):
    fenced = re.findall(r"```[^\n]*\n(.*?)```", body, re.DOTALL)
    prose = re.sub(r"```.*?```", "", body, flags=re.DOTALL)
    examples = fenced + re.findall(r"`([^`]+)`", prose)
    contracts = {tuple(command["path"]): set(command["flags"]) for command in commands}
    for example in examples:
        for invocation in re.findall(
            r"\bheelercli\s+([^\n]+)", example.replace("\\\n", " ")
        ):
            if re.search(r"\bheelercli\b", invocation):
                raise ValueError(
                    f"Use separate command examples, not compound invocations: {name}"
                )
            tokens = shlex.split(invocation)
            if tokens == ["--version"]:
                continue
            path = []
            for token in tokens:
                if token.startswith(("-", "[", "<")):
                    break
                path.append(token)
            if tuple(path) not in contracts:
                raise ValueError(f"Uncovered commands in {name}: {' '.join(path)}")
            flags = set(re.findall(r"(?<![\w-])--?[a-z][a-z0-9-]*", invocation))
            flags = {
                "--quiet" if flag == "-q" else "--help" if flag == "-h" else flag
                for flag in flags
            }
            missing = flags - contracts[tuple(path)] - {"--help"}
            if missing:
                raise ValueError(f"Uncovered flags in {name}: {sorted(missing)}")


def catalog(root):
    contract = json.loads((root / ".agents/skill-commands.json").read_text())
    version = contract["minimum_cli_version"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("Minimum CLI version must be an exact release")
    skills = []
    skills_root = contained(root, root / ".agents/skills")
    for directory in sorted(skills_root.iterdir()):
        if not directory.is_dir():
            raise ValueError(f"Unexpected skill entry: {directory}")
        contained(root, directory)
        path = contained(root, directory / "SKILL.md")
        name, description, body = metadata(path)
        links(root, path, body)
        commands = contract["skills"].get(name)
        if not isinstance(commands, list) or not commands:
            raise ValueError(f"Missing command contract: {name}")
        for command in commands:
            if set(command) != {"path", "flags"} or not command["path"]:
                raise ValueError(f"Invalid command contract: {name}")
            if any(
                not re.fullmatch(r"[a-z][a-z0-9-]*", part) for part in command["path"]
            ):
                raise ValueError(f"Unsafe command path: {name}")
            if any(
                not re.fullmatch(r"--?[a-z][a-z0-9-]*", flag)
                for flag in command["flags"]
            ):
                raise ValueError(f"Invalid option: {name}")
        check_examples(name, body, commands)
        files = {}
        for resource in sorted(directory.rglob("*")):
            contained(root, resource)
            if resource.is_file():
                if resource.suffix == ".md" and resource != path:
                    resource_body = resource.read_text(encoding="utf-8")
                    links(root, resource, resource_body)
                    check_examples(name, resource_body, commands)
                files[resource.relative_to(root).as_posix()] = hashlib.sha256(
                    resource.read_bytes()
                ).hexdigest()
        skills.append(
            {
                "name": name,
                "description": description,
                "path": path.relative_to(root).as_posix(),
                "files": files,
                "commands": commands,
            }
        )
    if not skills or set(contract["skills"]) != {skill["name"] for skill in skills}:
        raise ValueError("Command contract must cover every skill exactly once")
    return {"schema_version": 1, "minimum_cli_version": version, "skills": skills}


def run_help(binary, arguments):
    environment = {
        key: value
        for key, value in os.environ.items()
        if key in {"PATH", "SYSTEMROOT", "WINDIR", "TMP", "TEMP"}
    }
    result = subprocess.run(
        [str(binary), *arguments],
        text=True,
        capture_output=True,
        timeout=15,
        env=environment,
        check=False,
    )
    if result.returncode:
        raise ValueError(f"CLI help failed for {arguments}: exit {result.returncode}")
    return result.stdout + result.stderr


def cli_check(binary, document, expected_version=None):
    version_output = run_help(binary, ["--version"])
    match = re.search(r"\bversion v?(\d+\.\d+\.\d+)(?![\w.-])", version_output)
    if not match:
        raise ValueError("CLI must identify an exact stable release version")
    version = match[1]
    if expected_version is not None and version != expected_version:
        raise ValueError(
            f"CLI version mismatch: expected {expected_version}, received {version}"
        )
    if tuple(map(int, version.split("."))) < tuple(
        map(int, document["minimum_cli_version"].split("."))
    ):
        raise ValueError("CLI is older than the bundle's minimum version")
    checked = {}
    for skill in document["skills"]:
        for command in skill["commands"]:
            parts = tuple(command["path"])
            if parts not in checked:
                checked[parts] = run_help(binary, [*parts, "--help"])
            help_text = checked[parts]
            if not re.search(
                r"heeler-?cli\s+" + r"\s+".join(map(re.escape, parts)) + r"(?:\s|$)",
                help_text,
            ):
                raise ValueError(f"CLI did not return help for {' '.join(parts)}")
            for flag in command["flags"]:
                if not re.search(
                    r"(?<![\w-])" + re.escape(flag) + r"(?![\w-])", help_text
                ):
                    raise ValueError(f"Unsupported flag for {' '.join(parts)}: {flag}")
    return {
        "cli_version": version,
        "command_help_checks": len(checked),
        "workflow_execution": "not_performed",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root", type=Path, default=Path(__file__).resolve().parents[1]
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Regenerate the deterministic discovery catalog",
    )
    parser.add_argument(
        "--cli",
        type=Path,
        help="Existing trusted CLI binary; only --version and --help run",
    )
    parser.add_argument(
        "--expected-version",
        help="Require the actual CLI version to match this release",
    )
    args = parser.parse_args()
    if args.expected_version and not args.cli:
        parser.error("--expected-version requires --cli")
    try:
        document = catalog(args.root)
        path = contained(args.root, args.root / ".agents/skills.json")
        serialized = json.dumps(document, indent=2, ensure_ascii=False) + "\n"
        if args.write:
            path.write_text(serialized, encoding="utf-8")
        elif not path.is_file() or path.read_text(encoding="utf-8") != serialized:
            raise ValueError(
                "Discovery catalog is stale; run scripts/check_skills.py --write"
            )
        result = {
            "status": "PASS",
            "skills": len(document["skills"]),
            "catalog_sha256": hashlib.sha256(serialized.encode()).hexdigest(),
            "cli_help": "not_checked",
            "native_client_workflows": "not_checked",
        }
        if args.cli:
            result["cli_help"] = cli_check(
                args.cli.resolve(), document, args.expected_version
            )
        print(json.dumps(result, indent=2))
    except (
        ValueError,
        KeyError,
        TypeError,
        OSError,
        yaml.YAMLError,
        subprocess.TimeoutExpired,
    ) as error:
        print(f"Skill conformance failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
