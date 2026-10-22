"""Offline tests for an optional observed_at string on prod advisor lints."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import date
from pathlib import Path

import check

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
REAL_BASELINE = ROOT / "supabase" / "advisors-baseline.json"
FIX = HERE / "fixtures" / "observed_at"
CHECK = HERE / "check.py"
TODAY = date(2026, 10, 22)
GREEN = (
    "class=delegated name=authenticated_security_definer_function_executable "
    "level=WARN count=30\n"
    "class=accepted name=auth_leaked_password_protection level=WARN count=1\n"
    "class=report-only name=unused_index level=INFO count=19\n"
    "summary new=0 stale=0 delegated=30 accepted=1 report-only=19\n"
    "advisors prod: GREEN\n"
)
PARSE_RED = "error kind=parse\nadvisors prod: RED\n"


def _load(name):
    return json.loads((FIX / name).read_text(encoding="utf-8"))


def _run(security, performance):
    return check.execute(
        [
            "--layer",
            "prod",
            "--baseline",
            str(REAL_BASELINE),
            "--api",
            str(security),
            str(performance),
        ],
        today=TODAY,
    )


def _metadata_strings(value):
    if isinstance(value, str):
        return [value]
    if isinstance(value, dict):
        found = []
        for item in value.values():
            found.extend(_metadata_strings(item))
        return found
    if isinstance(value, list):
        found = []
        for item in value:
            found.extend(_metadata_strings(item))
        return found
    return []


def _hidden_strings(doc):
    found = []
    for lint in doc["lints"]:
        if "observed_at" in lint:
            found.append(lint["observed_at"])
        for key in ("detail", "title", "description", "remediation", "cache_key"):
            found.append(lint[key])
        found.extend(_metadata_strings(lint["metadata"]))
    return found


class ObservedAtTest(unittest.TestCase):
    def test_observed_at_on_every_lint_is_green(self):
        code, out = _run(FIX / "security.json", FIX / "performance.json")
        self.assertEqual(code, 0)
        self.assertEqual(out, GREEN)

    def test_observed_at_mixed_is_green(self):
        code, out = _run(FIX / "security_mixed.json", FIX / "performance_mixed.json")
        self.assertEqual(code, 0)
        self.assertEqual(out, GREEN)

    def _run_with_first_lint(self, **changes):
        security = _load("security.json")
        performance = _load("performance.json")
        security["lints"][0].update(changes)
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        sec = Path(tmp.name) / "security.json"
        perf = Path(tmp.name) / "performance.json"
        sec.write_text(json.dumps(security) + "\n", encoding="utf-8")
        perf.write_text(json.dumps(performance) + "\n", encoding="utf-8")
        return _run(sec, perf)

    def test_observed_at_non_string_is_parse_error(self):
        for label, value in (("null", None), ("number", 1)):
            with self.subTest(value=label):
                code, out = self._run_with_first_lint(observed_at=value)
                self.assertEqual(code, 1)
                self.assertEqual(out, PARSE_RED)

    def test_twelfth_key_with_observed_at_is_parse_error(self):
        code, out = self._run_with_first_lint(
            twelfth_unknown_key="synthetic-twelfth-sentinel"
        )
        self.assertEqual(code, 1)
        self.assertEqual(out, PARSE_RED)

    def test_observed_at_never_printed(self):
        env = {
            key: value
            for key, value in os.environ.items()
            if key not in ("GITHUB_TOKEN", "SUPABASE_ADVISORS_TOKEN", "GITHUB_STEP_SUMMARY")
        }
        proc = subprocess.run(
            [
                sys.executable,
                str(CHECK),
                "--layer",
                "prod",
                "--baseline",
                str(REAL_BASELINE),
                "--api",
                str(FIX / "security.json"),
                str(FIX / "performance.json"),
            ],
            cwd=HERE,
            env=env,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        self.assertEqual(proc.returncode, 0)
        self.assertEqual(proc.stderr, "")
        lines = proc.stdout.splitlines()
        self.assertTrue(lines)
        for line in lines:
            self.assertIsNotNone(check._PROD_LINE.fullmatch(line))
        for blob in _hidden_strings(_load("security.json")) + _hidden_strings(
            _load("performance.json")
        ):
            self.assertNotIn(blob, proc.stdout)
        self.assertNotIn("observed_at", proc.stdout)
        self.assertNotIn("observed_at", check.Finding.__dataclass_fields__)
        for name in ("security.json", "performance.json"):
            findings = check.parse_api_document((FIX / name).read_text(encoding="utf-8"))
            self.assertTrue(findings)
            for finding in findings:
                self.assertFalse(hasattr(finding, "observed_at"))


if __name__ == "__main__":
    unittest.main()
