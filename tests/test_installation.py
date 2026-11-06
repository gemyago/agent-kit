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

    def advance_upstream(self):
        upstream = self.root / "upstream"
        result = run("git", "clone", "--quiet", str(self.fixture), str(upstream))
        self.assertEqual(result.returncode, 0, result.stderr)
        skill = upstream / "skills/gak-checkpoint/SKILL.md"
        skill.write_text(skill.read_text() + "\nUpdated upstream skill\n")
        self.commit_changes(upstream)
        result = run("git", "remote", "set-url", "origin", str(upstream), cwd=self.checkout)
        self.assertEqual(result.returncode, 0, result.stderr)
        return run("git", "rev-parse", "HEAD", cwd=upstream).stdout.strip()

    def head(self, repository=None):
        result = run("git", "rev-parse", "HEAD", cwd=repository or self.checkout)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def state_records(self):
        records = [line.split("\t") for line in
                   (self.checkout / ".install-state").read_text().splitlines()]
        self.assertEqual(len(records), len({location for location, _ in records}))
        return dict(records)

    def commit_changes(self, repository):
        result = run("git", "add", "--all", cwd=repository)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = run("git", "-c", "user.name=GAK Tests", "-c", "user.email=gak@example.invalid",
                     "commit", "--quiet", "-am", "Test update", cwd=repository)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_install_without_pull_uses_cached_head(self):
        original = run("git", "rev-parse", "HEAD", cwd=self.checkout).stdout.strip()
        self.advance_upstream()
        self.install()
        self.assertEqual(run("git", "rev-parse", "HEAD", cwd=self.checkout).stdout.strip(), original)
        installed = (self.destination / "gak-checkpoint/SKILL.md").read_text()
        self.assertNotIn("Updated upstream skill", installed)
        self.assertEqual(self.state_records(), {str(self.destination): original})

    def test_pull_updates_skills_and_preserves_personal_settings(self):
        self.install()
        custom = self.config.read_text() + "\n# Personal settings\n"
        self.config.write_text(custom)
        commit = self.advance_upstream()
        self.install("--global", "--pull")
        installed = (self.destination / "gak-checkpoint/SKILL.md").read_text()
        self.assertIn("Updated upstream skill", installed)
        self.assertEqual(self.state_records(), {str(self.destination): commit})
        self.assertEqual(self.config.read_text(), custom)
        self.assertEqual(run("git", "rev-parse", "HEAD", cwd=self.checkout).stdout.strip(), commit)

    def test_pull_works_with_project_target(self):
        commit = self.advance_upstream()
        self.install("--pull", "--target", str(self.target))
        installed = (self.target / ".agents/skills/gak-checkpoint/SKILL.md").read_text()
        self.assertIn("Updated upstream skill", installed)
        self.assertEqual(self.state_records(), {str(self.target / ".agents/skills"): commit})

    def test_pull_failure_leaves_existing_installation_and_settings_unchanged(self):
        self.install()
        installed = self.destination / "gak-checkpoint/SKILL.md"
        original = installed.read_bytes()
        custom = self.config.read_text() + "\n# Personal settings\n"
        self.config.write_text(custom)
        result = run("git", "remote", "set-url", "origin", str(self.root / "missing remote"), cwd=self.checkout)
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.install("--global", "--pull", success=False)
        self.assertIn("pull failed; installation stopped", result.stderr)
        self.assertEqual(installed.read_bytes(), original)
        self.assertEqual(self.config.read_text(), custom)

    def test_pull_rejects_diverged_history_without_installing(self):
        self.advance_upstream()
        template = self.checkout / "crew-manager.yaml.template"
        template.write_text(template.read_text() + "\n# Local commit\n")
        self.commit_changes(self.checkout)
        original = run("git", "rev-parse", "HEAD", cwd=self.checkout).stdout.strip()
        # User pull preferences must not turn this into a rebase or merge.
        result = run("git", "config", "pull.rebase", "true", cwd=self.checkout)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.install("--global", "--pull", success=False)
        self.assertEqual(run("git", "rev-parse", "HEAD", cwd=self.checkout).stdout.strip(), original)
        self.assertFalse(self.destination.exists())
        self.assertFalse(self.config.exists())

    def test_pull_preserves_conflicting_local_edits_without_installing(self):
        self.advance_upstream()
        skill = self.checkout / "skills/gak-checkpoint/SKILL.md"
        custom = skill.read_text() + "\nLocal edit\n"
        skill.write_text(custom)
        original = run("git", "rev-parse", "HEAD", cwd=self.checkout).stdout.strip()
        result = run("git", "config", "merge.autoStash", "true", cwd=self.checkout)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.install("--global", "--pull", success=False)
        self.assertEqual(run("git", "rev-parse", "HEAD", cwd=self.checkout).stdout.strip(), original)
        self.assertEqual(skill.read_text(), custom)
        self.assertFalse(self.destination.exists())
        self.assertFalse(self.config.exists())

    def test_pull_works_when_checkout_must_be_cloned(self):
        shutil.rmtree(self.checkout)
        self.env.update(GIT_CONFIG_COUNT="1",
                        GIT_CONFIG_KEY_0=f"url.{self.fixture}.insteadOf",
                        GIT_CONFIG_VALUE_0="https://github.com/gemyago/agent-kit.git")
        # Run the entry script outside the cache, as with the curl install.
        result = run("bash", str(ROOT / "install.sh"), "--global", "--pull", env=self.env)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual({p.name for p in self.destination.iterdir()}, SKILLS)
        self.assertTrue(self.config.is_file())

    def test_fresh_install_and_update_preserve_personal_settings(self):
        self.install()
        self.assertEqual({p.name for p in self.destination.iterdir()}, SKILLS)
        self.assertEqual(self.config.read_bytes(), (self.checkout / "crew-manager.yaml.template").read_bytes())
        custom = self.config.read_text().replace("openai/gpt-6.1-sol", "openai/personal-model")
        self.config.write_text(custom)
        (self.destination / "gak-checkpoint/SKILL.md").write_text(
            (self.destination / "gak-checkpoint/SKILL.md").read_text() + "\nOld installed text\n")
        self.install()
        self.assertEqual(self.config.read_text(), custom)
        self.assertNotIn("Old installed text", (self.destination / "gak-checkpoint/SKILL.md").read_text())
        ignored = run("git", "check-ignore", "crew-manager.yaml", cwd=self.checkout)
        self.assertEqual(ignored.returncode, 0)
        self.assertTrue((self.destination / "gak-crew-manager/references/chat-mode.md").is_file())

    def test_install_replaces_existing_matching_skill_without_metadata(self):
        conflict = self.destination / "gak-crew-manager"
        conflict.mkdir(parents=True)
        (conflict / "SKILL.md").write_text("Locally changed skill")
        unrelated = self.destination / "another-skill"
        unrelated.mkdir()
        (unrelated / "SKILL.md").write_text("Unrelated skill")
        self.install()
        self.assertEqual((conflict / "SKILL.md").read_bytes(),
                         (self.checkout / "skills/gak-crew-manager/SKILL.md").read_bytes())
        self.assertEqual((unrelated / "SKILL.md").read_text(), "Unrelated skill")

    def test_symlink_in_destination_is_rejected(self):
        self.install()
        state = (self.checkout / ".install-state").read_bytes()
        external = self.root / "outside.md"
        external.write_text("Unchanged")
        (self.destination / "gak-crew-manager/custom.md").symlink_to(external)
        self.install(success=False)
        self.assertEqual(external.read_text(), "Unchanged")
        self.assertEqual((self.checkout / ".install-state").read_bytes(), state)

    def test_legacy_destination_settings_seed_personal_config(self):
        legacy = self.destination / "crew-manager"
        legacy.mkdir(parents=True)
        custom = (self.checkout / "crew-manager.yaml.template").read_text() + "\n# Personal policy\n"
        (legacy / "config.yaml").write_text(custom)
        self.install()
        self.assertEqual(self.config.read_text(), custom)
        self.assertEqual((legacy / "config.yaml").read_text(), custom)
        self.install()
        self.assertEqual(self.config.read_text(), custom)

    def test_existing_personal_config_wins_over_legacy(self):
        legacy = self.destination / "crew-manager"
        legacy.mkdir(parents=True)
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

    def test_personal_config_symlink_is_rejected_without_modifying_target(self):
        external = self.root / "settings.yaml"
        external.write_text("Personal settings")
        self.config.symlink_to(external)
        self.install(success=False)
        self.assertEqual(external.read_text(), "Personal settings")
        self.assertFalse(self.destination.exists())
        self.assertFalse((self.checkout / ".install-state").exists())

    def test_unrelated_legacy_name_is_left_alone(self):
        legacy = self.destination / "crew-manager"
        legacy.mkdir(parents=True)
        (legacy / "SKILL.md").write_text("Unrelated skill")
        self.install()
        self.assertEqual((legacy / "SKILL.md").read_text(), "Unrelated skill")
        self.assertTrue((self.destination / "gak-crew-manager/SKILL.md").is_file())

    def test_install_copies_committed_files_without_changes(self):
        changed = self.checkout / "skills/gak-checkpoint/SKILL.md"
        committed = changed.read_bytes()
        changed.write_text("Uncommitted edit")
        (changed.parent / "untracked.md").write_text("Untracked")
        self.install()
        self.assertEqual((self.destination / "gak-checkpoint/SKILL.md").read_bytes(), committed)
        self.assertFalse((self.destination / "gak-checkpoint/untracked.md").exists())
        for name in SKILLS:
            for source in (self.fixture / "skills" / name).rglob("*"):
                if source.is_file():
                    installed = self.destination / name / source.relative_to(self.fixture / "skills" / name)
                    self.assertEqual(installed.read_bytes(), source.read_bytes())
                    self.assertEqual(installed.stat().st_mode & 0o777, source.stat().st_mode & 0o777)
        self.assertEqual({p.name for p in self.destination.iterdir()}, SKILLS)
        ignored = run("git", "check-ignore", ".install-state", cwd=self.checkout)
        self.assertEqual(ignored.returncode, 0)

    def test_renamed_skill_removes_old_directory(self):
        self.install()
        old = self.checkout / "skills/gak-checkpoint"
        new = self.checkout / "skills/gak-renamed-checkpoint"
        old.rename(new)
        skill = new / "SKILL.md"
        skill.write_text(skill.read_text().replace("name: gak-checkpoint", "name: gak-renamed-checkpoint"))
        (self.destination / "gak-checkpoint/local.md").write_text("Local addition")
        self.commit_changes(self.checkout)
        self.install()
        self.assertFalse((self.destination / "gak-checkpoint").exists())
        self.assertEqual((self.destination / new.name / "SKILL.md").read_bytes(), skill.read_bytes())
        self.assertEqual(self.state_records(), {str(self.destination): self.head()})

    def test_update_removes_deleted_skill_and_modified_obsolete_files(self):
        self.install()
        obsolete = "gak-crew-manager/references/chat-mode.md"
        (self.destination / obsolete).write_text("Locally changed obsolete file")
        (self.checkout / "skills" / obsolete).unlink()
        shutil.rmtree(self.checkout / "skills/gak-crew-explore")
        self.commit_changes(self.checkout)
        self.install()
        self.assertFalse((self.destination / obsolete).exists())
        self.assertFalse((self.destination / "gak-crew-explore").exists())
        self.assertEqual(self.state_records(), {str(self.destination): self.head()})

    def test_same_commit_install_repairs_files_and_keeps_one_state_record(self):
        self.install()
        missing = self.destination / "gak-crew-manager/references/chat-mode.md"
        missing.unlink()
        changed = self.destination / "gak-checkpoint/SKILL.md"
        changed.write_text("Changed")
        self.install()
        self.assertEqual(missing.read_bytes(),
                         (self.checkout / "skills/gak-crew-manager/references/chat-mode.md").read_bytes())
        self.assertEqual(changed.read_bytes(), (self.checkout / "skills/gak-checkpoint/SKILL.md").read_bytes())
        self.assertEqual(self.state_records(), {str(self.destination): self.head()})

    def test_registry_tracks_each_destination_independently(self):
        self.install()
        original = self.head()
        self.install("--target", str(self.target))
        obsolete = "gak-crew-manager/references/chat-mode.md"
        (self.checkout / "skills" / obsolete).unlink()
        self.commit_changes(self.checkout)
        self.install()
        project_destination = self.target / ".agents/skills"
        self.assertFalse((self.destination / obsolete).exists())
        self.assertTrue((project_destination / obsolete).exists())
        self.assertEqual(self.state_records(), {str(self.destination): self.head(),
                                               str(project_destination): original})
        self.install("--target", str(self.target / "."))
        self.assertFalse((project_destination / obsolete).exists())
        self.assertEqual(self.state_records(), {str(self.destination): self.head(),
                                               str(project_destination): self.head()})

    def test_unavailable_installed_commit_stops_before_writes(self):
        self.install()
        state = self.checkout / ".install-state"
        state.write_text(f"{self.destination}\t{'0' * 40}\n")
        installed = self.destination / "gak-checkpoint/SKILL.md"
        installed.write_text("Unchanged installation")
        original = state.read_bytes()
        self.config.unlink()
        result = self.install(success=False)
        self.assertIn("is unavailable", result.stderr)
        self.assertEqual(installed.read_text(), "Unchanged installation")
        self.assertEqual(state.read_bytes(), original)
        self.assertFalse(self.config.exists())

    def test_structural_conflict_does_not_remove_files_or_advance_state(self):
        self.install()
        original = (self.checkout / ".install-state").read_bytes()
        obsolete = self.checkout / "skills/gak-crew-manager/references/chat-mode.md"
        obsolete.unlink()
        new = self.checkout / "skills/gak-checkpoint/new-directory/new.md"
        new.parent.mkdir()
        new.write_text("New file")
        (self.destination / "gak-checkpoint/new-directory").write_text("Blocking file")
        self.commit_changes(self.checkout)
        self.install(success=False)
        self.assertTrue((self.destination / "gak-crew-manager/references/chat-mode.md").is_file())
        self.assertEqual((self.checkout / ".install-state").read_bytes(), original)

    def test_update_handles_file_and_directory_transitions(self):
        first = self.checkout / "skills/gak-checkpoint/file-to-directory"
        second = self.checkout / "skills/gak-checkpoint/directory-to-file"
        first.write_text("Old file")
        second.mkdir()
        (second / "old.md").write_text("Old nested file")
        self.commit_changes(self.checkout)
        self.install()
        first.unlink()
        nested = first / "directory with trailing newline\n"
        nested.mkdir(parents=True)
        (nested / "new file\nwith newline.md").write_text("New nested file")
        shutil.rmtree(second)
        second.write_text("New file")
        self.commit_changes(self.checkout)
        self.install()
        self.assertEqual((self.destination / "gak-checkpoint/file-to-directory/directory with trailing newline\n/new file\nwith newline.md").read_text(),
                         "New nested file")
        self.assertEqual((self.destination / "gak-checkpoint/directory-to-file").read_text(), "New file")

    def test_update_can_remove_all_skills_and_repeat(self):
        self.install()
        shutil.rmtree(self.checkout / "skills")
        self.commit_changes(self.checkout)
        self.install()
        self.assertEqual(list(self.destination.iterdir()), [])
        self.install()
        self.assertEqual(self.state_records(), {str(self.destination): self.head()})

    def test_install_state_symlink_is_rejected(self):
        external = self.root / "outside-state"
        external.write_text("Unchanged")
        (self.checkout / ".install-state").symlink_to(external)
        self.install(success=False)
        self.assertEqual(external.read_text(), "Unchanged")
        self.assertFalse(self.destination.exists())

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
