"""Lock rev 2 Addendum B (TMAS-M17-01): at --layer prod, check.py prints only
lint name, level and per-class counts. No detail, cache_key, remediation,
metadata, title, description or object names reach stdout or stderr."""
import os
import re
import subprocess
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
CHECK = os.path.join(HERE, "check.py")
FIX = os.path.join(HERE, "fixtures", "prod_redaction")

ALLOWED_LINE = re.compile(
    r"^(?:"
    r"class=(?:new|stale|delegated|accepted|report-only) name=[a-z0-9_]+ level=(?:ERROR|WARN|INFO|-) count=[0-9]+"
    r"|summary new=[0-9]+ stale=[0-9]+ delegated=[0-9]+ accepted=[0-9]+ report-only=[0-9]+"
    r"|amber name=[a-z0-9_]+ review_by=[0-9]{4}-[0-9]{2}-[0-9]{2}"
    r"|error kind=(?:input|parse|baseline)"
    r"|advisors prod: (?:GREEN|AMBER|RED)"
    r")$"
)


class ProdLayerRedactionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        env = {k: v for k, v in os.environ.items()
               if k not in ("GITHUB_TOKEN", "SUPABASE_ADVISORS_TOKEN", "GITHUB_STEP_SUMMARY")}
        cls.proc = subprocess.run(
            [sys.executable, CHECK, "--layer", "prod",
             "--baseline", os.path.join(FIX, "baseline.json"),
             "--api", os.path.join(FIX, "security.json"), os.path.join(FIX, "performance.json")],
            cwd=HERE, env=env, capture_output=True, text=True, timeout=60, check=False,
        )

    def test_exit_red_on_new_findings(self):
        self.assertEqual(self.proc.returncode, 1)

    def test_no_finding_details_in_output(self):
        out = (self.proc.stdout + self.proc.stderr).lower()
        for needle in ("sentinel", "detail", "cache_key", "remediation", "metadata", "http"):
            self.assertNotIn(needle, out)

    def test_stderr_empty(self):
        self.assertEqual(self.proc.stderr, "")

    def test_every_line_is_name_level_or_count(self):
        lines = [l for l in self.proc.stdout.splitlines() if l.strip()]
        self.assertTrue(lines)
        for line in lines:
            self.assertRegex(line, ALLOWED_LINE)

    def test_counts(self):
        lines = set(self.proc.stdout.splitlines())
        for expected in (
            "class=new name=security_definer_view level=ERROR count=2",
            "class=new name=auth_rls_initplan level=WARN count=1",
            "class=accepted name=auth_leaked_password_protection level=WARN count=1",
            "class=report-only name=unused_index level=INFO count=3",
            "summary new=3 stale=0 delegated=0 accepted=1 report-only=3",
            "advisors prod: RED",
        ):
            self.assertIn(expected, lines)


if __name__ == "__main__":
    unittest.main()
