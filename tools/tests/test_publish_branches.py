"""2026-11-18: the publish script must name branches that exist (the Legion rename once renamed
build/rldb-game in the script only, and the mirror kept just `main`)."""
import os
import subprocess
import sys
import tempfile
import unittest

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
import publish_github  # noqa: E402


class PublishBranchesTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        d = self.dir.name
        for cmd in (["init", "-q", "-b", "main"], ["-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q",
                    "--allow-empty", "-m", "x"], ["branch", "build/rldb-game"]):
            subprocess.run(["git", *cmd], cwd=d, check=True, capture_output=True)
        self._branches = publish_github.BRANCHES
        self.addCleanup(setattr, publish_github, "BRANCHES", self._branches)

    def test_no_missing_branch_when_all_exist(self):
        publish_github.BRANCHES = ["main", "build/rldb-game"]
        self.assertEqual(publish_github.missing_branches(self.dir.name), [])

    def test_a_renamed_branch_is_reported_missing(self):
        publish_github.BRANCHES = ["main", "build/legion-game"]
        self.assertEqual(publish_github.missing_branches(self.dir.name), ["build/legion-game"])

    def test_this_repo_has_every_published_branch(self):
        self.assertEqual(publish_github.missing_branches(), [])


if __name__ == "__main__":
    unittest.main()
