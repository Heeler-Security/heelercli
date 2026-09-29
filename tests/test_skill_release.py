import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import tomllib
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "check_skills", ROOT / "scripts/check_skills.py"
)
CHECK = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CHECK)


class SkillReleaseTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        shutil.copytree(ROOT / ".agents", self.root / ".agents")
        self.path = self.root / ".agents/skills/heeler-secrets-scan/SKILL.md"

    def test_catalog_covers_all_skills_deterministically(self):
        generated = CHECK.catalog(self.root)
        recorded = json.loads((ROOT / ".agents/skills.json").read_text())
        self.assertEqual(recorded, generated)
        self.assertEqual(
            len(list((self.root / ".agents/skills").iterdir())),
            len(generated["skills"]),
        )

    def test_frontmatter_rejects_invalid_yaml(self):
        self.path.write_text(
            "---\nname: heeler-secrets-scan\ndescription: value: invalid\n---\nbody"
        )
        with self.assertRaises(CHECK.yaml.YAMLError):
            CHECK.catalog(self.root)

    def test_frontmatter_rejects_duplicate_keys(self):
        self.path.write_text(
            "---\nname: heeler-secrets-scan\nname: other\ndescription: valid\n---\nbody"
        )
        with self.assertRaisesRegex(ValueError, "unique"):
            CHECK.catalog(self.root)

    def test_frontmatter_separator_inside_description_is_not_a_delimiter(self):
        self.path.write_text(
            '---\nname: heeler-secrets-scan\ndescription: "Scan --- selected files"\n---\nbody'
        )
        self.assertEqual(CHECK.metadata(self.path)[1], "Scan --- selected files")

    def test_client_configuration_recipes(self):
        clients = ROOT / ".agents/clients"
        codex = tomllib.loads((clients / "codex.toml").read_text())
        self.assertEqual(
            codex, {"mcp_servers": {"heeler": {"url": "https://app.heeler.com/mcp"}}}
        )
        for name, key in [
            ("claude-code.json", "mcpServers"),
            ("vscode.json", "servers"),
        ]:
            with self.subTest(client=name):
                self.assertEqual(
                    json.loads((clients / name).read_text()),
                    {
                        key: {
                            "heeler": {
                                "type": "http",
                                "url": "https://app.heeler.com/mcp",
                            }
                        }
                    },
                )

    def test_folder_name_must_match(self):
        self.path.write_text("---\nname: another\ndescription: valid\n---\nbody")
        with self.assertRaisesRegex(ValueError, "mismatch"):
            CHECK.catalog(self.root)

    def test_broken_link_fails(self):
        self.path.write_text(self.path.read_text() + "\n[guide](missing.md)\n")
        with self.assertRaisesRegex(ValueError, "Broken"):
            CHECK.catalog(self.root)

    def test_broken_resource_link_fails(self):
        (self.path.parent / "reference.md").write_text("[guide](missing.md)")
        with self.assertRaisesRegex(ValueError, "Broken"):
            CHECK.catalog(self.root)

    def test_link_escape_fails(self):
        self.path.write_text(
            self.path.read_text() + "\n[guide](../../../../outside.md)\n"
        )
        with self.assertRaisesRegex(ValueError, "leaves bundle"):
            CHECK.catalog(self.root)

    def test_symlink_resource_fails(self):
        (self.path.parent / "outside").symlink_to(self.root.parent)
        with self.assertRaisesRegex(ValueError, "symlink"):
            CHECK.catalog(self.root)

    def test_resource_bytes_change_catalog_hash(self):
        original = CHECK.catalog(self.root)
        (self.path.parent / "reference.md").write_text("Versioned resource")
        changed = CHECK.catalog(self.root)
        self.assertNotEqual(original, changed)

    def test_undocumented_command_contract_fails(self):
        self.path.write_text(
            self.path.read_text() + "\n`heelercli nonexistent --format json`\n"
        )
        with self.assertRaisesRegex(ValueError, "Uncovered commands"):
            CHECK.catalog(self.root)

    def test_undocumented_flag_fails(self):
        self.path.write_text(
            self.path.read_text() + "\n`heelercli secrets --definitely-not-real`\n"
        )
        with self.assertRaisesRegex(ValueError, "Uncovered flags"):
            CHECK.catalog(self.root)

    def test_undocumented_subcommand_fails(self):
        self.path.write_text(
            self.path.read_text() + "\n`heelercli secrets nonexistent`\n"
        )
        with self.assertRaisesRegex(ValueError, "Uncovered commands"):
            CHECK.catalog(self.root)

    def test_compound_example_does_not_hide_second_command(self):
        self.path.write_text(
            self.path.read_text()
            + "\n`heelercli secrets --quiet && heelercli nonexistent`\n"
        )
        with self.assertRaisesRegex(ValueError, "compound"):
            CHECK.catalog(self.root)

    def test_continued_example_does_not_hide_flag(self):
        self.path.write_text(
            self.path.read_text()
            + "\n```bash\nheelercli secrets \\\n  --nonexistent\n```\n"
        )
        with self.assertRaisesRegex(ValueError, "Uncovered flags"):
            CHECK.catalog(self.root)

    def test_no_extra_or_missing_skill_contract(self):
        contract_path = self.root / ".agents/skill-commands.json"
        contract = json.loads(contract_path.read_text())
        contract["skills"]["nonexistent"] = [{"path": ["ci"], "flags": []}]
        contract_path.write_text(json.dumps(contract))
        with self.assertRaisesRegex(ValueError, "every skill"):
            CHECK.catalog(self.root)

    def test_help_only_and_release_identity(self):
        document = {
            "minimum_cli_version": "1.0.24",
            "skills": [{"commands": [{"path": ["ci"], "flags": ["--checks"]}]}],
        }
        calls = []

        def help_output(binary, args):
            calls.append(args)
            return (
                "heeler-cli version 1.0.24"
                if args == ["--version"]
                else "Usage: heelercli ci [flags]\n --checks strings"
            )

        with patch.object(CHECK, "run_help", side_effect=help_output):
            result = CHECK.cli_check(Path("cli"), document, "1.0.24")
        self.assertEqual(calls, [["--version"], ["ci", "--help"]])
        self.assertEqual(result["workflow_execution"], "not_performed")

    def test_wrong_or_old_release_fails(self):
        document = {"minimum_cli_version": "1.0.24", "skills": []}
        with patch.object(CHECK, "run_help", return_value="heeler-cli version 1.0.22"):
            with self.assertRaisesRegex(ValueError, "mismatch"):
                CHECK.cli_check(Path("cli"), document, "1.0.24")
            with self.assertRaisesRegex(ValueError, "older"):
                CHECK.cli_check(Path("cli"), document)

    def test_actual_binary_help_uses_hyphenated_name(self):
        document = {
            "minimum_cli_version": "1.0.24",
            "skills": [{"commands": [{"path": ["licenses"], "flags": []}]}],
        }
        with patch.object(
            CHECK,
            "run_help",
            side_effect=[
                "heeler-cli version 1.0.24",
                "Usage: heeler-cli licenses [flags]",
            ],
        ):
            self.assertEqual(
                CHECK.cli_check(Path("cli"), document)["command_help_checks"], 1
            )

    def test_missing_flag_is_not_accepted_as_prefix(self):
        document = {
            "minimum_cli_version": "1.0.24",
            "skills": [{"commands": [{"path": ["ci"], "flags": ["--check"]}]}],
        }
        with patch.object(
            CHECK,
            "run_help",
            side_effect=[
                "heeler-cli version 1.0.24",
                "Usage: heelercli ci [flags]\n --checks strings",
            ],
        ):
            with self.assertRaisesRegex(ValueError, "Unsupported flag"):
                CHECK.cli_check(Path("cli"), document)

    def test_parent_help_is_not_a_subcommand_pass(self):
        document = {
            "minimum_cli_version": "1.0.24",
            "skills": [{"commands": [{"path": ["licenses", "valid"], "flags": []}]}],
        }
        with patch.object(
            CHECK,
            "run_help",
            side_effect=[
                "heeler-cli version 1.0.24",
                "Usage: heelercli licenses [flags]",
            ],
        ):
            with self.assertRaisesRegex(ValueError, "did not return help"):
                CHECK.cli_check(Path("cli"), document)


if __name__ == "__main__":
    unittest.main()
