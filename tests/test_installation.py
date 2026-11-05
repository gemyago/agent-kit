"""Installation and OpenCode integration checks. Run with python3 -m unittest discover -s tests -v."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[1]
SKILLS = {"gak-checkpoint", "gak-crew-explore", "gak-crew-manager"}


def run(*args, env=None, cwd=None):
    return subprocess.run(args, env=env, cwd=cwd, text=True, capture_output=True)


class InstallationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        scratch = ROOT / "tmp"
        scratch.mkdir(exist_ok=True)
        cls.session = tempfile.TemporaryDirectory(prefix="gak-install-", dir=scratch)
        cls.fixture = Path(cls.session.name) / "source"
        cls.fixture.mkdir()
        for name in ("install.sh", ".gitignore", "crew-manager.yaml.template"):
            shutil.copy2(ROOT / name, cls.fixture / name)
        shutil.copytree(ROOT / "skills", cls.fixture / "skills")
        for command in (
            ("git", "init", "--quiet"),
            ("git", "add", "."),
            ("git", "-c", "user.name=GAK Tests", "-c", "user.email=gak@example.invalid", "commit", "--quiet", "-m", "Fixture"),
        ):
            result = run(*command, cwd=cls.fixture)
            if result.returncode:
                raise RuntimeError(result.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.session.cleanup()

    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(dir=self.session.name)
        self.root = Path(self.scratch.name)
        self.checkout = self.root / "checkout with spaces"
        result = run("git", "clone", "--quiet", str(self.fixture), str(self.checkout))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.destination = self.root / "installed skills"
        self.target = self.root / "workspace"
        self.target.mkdir()
        self.config = self.checkout / "crew-manager.yaml"
        self.env = dict(os.environ, GEMYAGO_AGENT_KIT_HOME=str(self.checkout),
                        GEMYAGO_AGENT_KIT_GLOBAL_SKILLS_DIR=str(self.destination))
        self.addCleanup(self.scratch.cleanup)

    def install(self, *args, success=True):
        result = run("bash", str(self.checkout / "install.sh"), *(args or ("--global",)), env=self.env)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def sync(self, success=True):
        script = self.checkout / "skills/gak-crew-manager/scripts/sync-opencode-agents.sh"
        result = run("bash", str(script), "--target", str(self.target), env=self.env)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def write_config(self, config):
        self.config.write_text(yaml.safe_dump(config, sort_keys=False))

    def agent(self, name):
        text = (self.target / ".opencode/agents" / f"{name}.md").read_text()
        return yaml.safe_load(text.split("---", 2)[1]), text

    def test_fresh_install_and_update_preserve_personal_settings(self):
        self.install()
        self.assertEqual({p.name for p in self.destination.iterdir()}, SKILLS)
        self.assertEqual(self.config.read_bytes(), (self.checkout / "crew-manager.yaml.template").read_bytes())
        custom = self.config.read_text().replace("openai/gpt-6.1-sol", "openai/personal-model")
        self.config.write_text(custom)
        extra = self.destination / "gak-crew-manager/personal.md"
        extra.write_text("Keep this")
        (self.destination / "gak-checkpoint/SKILL.md").write_text(
            (self.destination / "gak-checkpoint/SKILL.md").read_text() + "\nOld installed text\n")
        self.install()
        self.assertEqual(self.config.read_text(), custom)
        self.assertEqual(extra.read_text(), "Keep this")
        self.assertNotIn("Old installed text", (self.destination / "gak-checkpoint/SKILL.md").read_text())
        ignored = run("git", "check-ignore", "crew-manager.yaml", cwd=self.checkout)
        self.assertEqual(ignored.returncode, 0)
        self.assertTrue((self.destination / "gak-crew-manager/references/chat-mode.md").is_file())

    def test_unrelated_skill_collision_fails_before_writes(self):
        conflict = self.destination / "gak-crew-manager"
        conflict.mkdir(parents=True)
        original = "---\nname: gak-crew-manager\n---\nSomeone else's skill\n"
        (conflict / "SKILL.md").write_text(original)
        self.install(success=False)
        self.assertEqual((conflict / "SKILL.md").read_text(), original)
        self.assertEqual(list(self.destination.iterdir()), [conflict])
        self.assertFalse(self.config.exists())

    def test_symlink_in_destination_is_rejected(self):
        self.install()
        external = self.root / "outside.md"
        external.write_text("Unchanged")
        (self.destination / "gak-crew-manager/custom.md").symlink_to(external)
        self.install(success=False)
        self.assertEqual(external.read_text(), "Unchanged")

    def legacy_manager(self):
        legacy = self.destination / "crew-manager"
        legacy.mkdir(parents=True)
        (legacy / "SKILL.md").write_text(
            '---\nname: crew-manager\nmetadata:\n  gemyago-source-path: "skills/crew-manager"\n---\nLegacy\n')
        return legacy

    def test_owned_legacy_install_migrates_and_preserves_config(self):
        legacy = self.legacy_manager()
        custom = (self.checkout / "crew-manager.yaml.template").read_text() + "\n# Personal policy\n"
        (legacy / "config.yaml").write_text(custom)
        (legacy / "notes.md").write_text("Personal notes")
        self.install()
        self.assertFalse(legacy.exists())
        self.assertEqual(self.config.read_text(), custom)
        self.assertEqual((self.destination / "gak-crew-manager/notes.md").read_text(), "Personal notes")
        self.install()
        self.assertEqual(self.config.read_text(), custom)

    def test_existing_personal_config_wins_over_legacy(self):
        legacy = self.legacy_manager()
        (legacy / "config.yaml").write_text("legacy settings")
        self.config.write_text("personal settings")
        self.install()
        self.assertEqual(self.config.read_text(), "personal settings")

    def test_checkout_legacy_config_seeds_personal_config_and_remains_ignored(self):
        legacy = self.checkout / "skills/crew-manager/config.yaml"
        legacy.parent.mkdir()
        custom = (self.checkout / "crew-manager.yaml.template").read_text() + "\n# Checkout policy\n"
        legacy.write_text(custom)
        self.install()
        self.assertEqual(self.config.read_text(), custom)
        self.assertEqual(legacy.read_text(), custom)
        ignored = run("git", "check-ignore", "skills/crew-manager/config.yaml", cwd=self.checkout)
        self.assertEqual(ignored.returncode, 0)

    def test_legacy_path_conflict_is_rejected_before_migration(self):
        legacy = self.legacy_manager()
        (legacy / "references").write_text("Personal file")
        self.install(success=False)
        self.assertEqual((legacy / "references").read_text(), "Personal file")
        self.assertFalse((self.destination / "gak-crew-manager").exists())
        self.assertFalse(self.config.exists())

    def test_personal_config_symlink_is_rejected_without_modifying_target(self):
        external = self.root / "settings.yaml"
        external.write_text("Personal settings")
        self.config.symlink_to(external)
        self.install(success=False)
        self.assertEqual(external.read_text(), "Personal settings")
        self.assertFalse(self.destination.exists())

    def test_unrelated_legacy_name_is_left_alone(self):
        legacy = self.destination / "crew-manager"
        legacy.mkdir(parents=True)
        (legacy / "SKILL.md").write_text("Unrelated skill")
        self.install()
        self.assertEqual((legacy / "SKILL.md").read_text(), "Unrelated skill")
        self.assertTrue((self.destination / "gak-crew-manager/SKILL.md").is_file())

    def test_setup_installs_skills_and_generates_from_personal_config(self):
        script = self.checkout / "skills/gak-crew-manager/scripts/setup.sh"
        result = run("bash", str(script), "--target", str(self.target), env=self.env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual({p.name for p in (self.target / ".agents/skills").iterdir()}, SKILLS)
        manager, text = self.agent("gak-crew-manager")
        config = yaml.safe_load(self.config.read_text())
        self.assertEqual(manager["model"], config["manager"]["opencode_model"])
        self.assertEqual(manager["permission"]["read"][str(self.config)], "allow")
        self.assertEqual(manager["permission"]["external_directory"][str(self.checkout / "**")], "allow")
        self.assertIn(str(self.config), text)
        _, worker_text = self.agent("gak-crew-p3")
        self.assertIn("references/shared-rules.md", worker_text)

    def test_regeneration_uses_configured_names_and_removes_stale_agents(self):
        self.install()
        self.sync()
        config = yaml.safe_load(self.config.read_text())
        config["workers"]["p2"]["agent_name"] = "custom-runner"
        config["workers"]["p2"]["opencode_model"] = "test/custom-model"
        self.write_config(config)
        unrelated = self.target / ".opencode/agents/my-agent.md"
        unrelated.write_text("Personal agent")
        self.sync()
        worker, _ = self.agent("custom-runner")
        self.assertEqual(worker["model"], "test/custom-model")
        manager, _ = self.agent("gak-crew-manager")
        self.assertEqual(manager["permission"]["task"]["custom-runner"], "allow")
        self.assertNotIn("crew-*", manager["permission"]["task"])
        self.assertFalse((unrelated.parent / "gak-crew-p2.md").exists())
        self.assertEqual(unrelated.read_text(), "Personal agent")

    def test_generator_rejects_collisions_and_invalid_config_before_writes(self):
        self.install()
        agents = self.target / ".opencode/agents"
        agents.mkdir(parents=True)
        collision = agents / "gak-crew-p3.md"
        collision.write_text("Personal agent")
        self.sync(success=False)
        self.assertEqual(list(agents.iterdir()), [collision])
        self.assertEqual(collision.read_text(), "Personal agent")
        collision.unlink()
        config = yaml.safe_load(self.config.read_text())
        config["workers"]["p3"]["agent_name"] = "../escaped"
        self.write_config(config)
        self.sync(success=False)
        self.assertEqual(list(agents.iterdir()), [])
        self.assertFalse((self.target / ".opencode/escaped.md").exists())

    def test_generator_reports_missing_config(self):
        result = self.sync(success=False)
        self.assertIn(str(self.config), result.stderr)
        self.assertFalse((self.target / ".opencode").exists())

    def test_generator_rejects_duplicate_agent_names_before_writes(self):
        self.install()
        config = yaml.safe_load(self.config.read_text())
        config["workers"]["p2"]["agent_name"] = config["manager"]["agent_name"]
        self.write_config(config)
        self.sync(success=False)
        self.assertEqual(list((self.target / ".opencode/agents").iterdir()), [])

    def test_generator_updates_legacy_generated_files(self):
        self.install()
        agents = self.target / ".opencode/agents"
        agents.mkdir(parents=True)
        marker = "<!-- Generated by crew-manager sync; edit its config.yaml and re-run. -->"
        (agents / "gak-crew-manager.md").write_text(marker)
        (agents / "crew-p2.md").write_text(marker)
        self.sync()
        self.assertFalse((agents / "crew-p2.md").exists())
        manager, _ = self.agent("gak-crew-manager")
        self.assertEqual(manager["mode"], "primary")


if __name__ == "__main__":
    unittest.main()
