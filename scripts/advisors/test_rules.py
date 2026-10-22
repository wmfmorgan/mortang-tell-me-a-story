"""Offline tests for lock §7.2 rules 1-8 and the prod-layer grammar."""

import csv
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
CHECK = HERE / "check.py"
PIN = {
    "commit": check.PIN_COMMIT,
    "sha256": check.PIN_SHA256,
}
DELEGATED = {
    "name": "authenticated_security_definer_function_executable",
    "source": "supabase/tests/catalog_acl_guard.sql",
    "reason": "the catalog_acl_guard.sql set_eq list is the single source",
    "owner": "Gilfoyle",
}
CSV_COLUMNS = [
    "name",
    "title",
    "level",
    "facing",
    "categories",
    "description",
    "detail",
    "remediation",
    "metadata",
    "cache_key",
]


def baseline_doc(**kwargs):
    doc = {
        "version": 1,
        "splinter": dict(PIN),
        "report_only_lints": kwargs.get(
            "report_only",
            [{"name": "unused_index", "reason": "stats", "owner": "Gilfoyle"}],
        ),
        "local_skip_lints": kwargs.get(
            "local_skip",
            [
                {
                    "name": "extension_versions_outdated",
                    "reason": "local image differs",
                    "owner": "Gilfoyle",
                }
            ],
        ),
        "delegated": kwargs.get("delegated", []),
        "accepted": kwargs.get("accepted", []),
    }
    return doc


def accepted(name="auth_rls_initplan", scope="both", review_by="2099-12-31", owner="Gilfoyle", match=None):
    return {
        "match": match or {"name": name},
        "scope": scope,
        "reason": "fixture entry",
        "owner": owner,
        "added": "2026-10-20",
        "review_by": review_by,
    }


def api_lint(name, level, **kwargs):
    return {
        "name": name,
        "title": kwargs.get("title", "Title"),
        "level": level,
        "facing": "EXTERNAL",
        "categories": kwargs.get("categories", ["PERFORMANCE"]),
        "description": kwargs.get("description", "description"),
        "detail": kwargs.get("detail", "detail"),
        "remediation": kwargs.get("remediation", "https://example.invalid/lint"),
        "metadata": kwargs.get("metadata", {"schema": "public", "name": "objects", "type": "table"}),
        "cache_key": kwargs.get("cache_key", f"cache_{name}"),
    }


def csv_row(name, level, metadata, **kwargs):
    categories = kwargs.get("categories", "PERFORMANCE")
    return {
        "name": name,
        "title": kwargs.get("title", "Title"),
        "level": level,
        "facing": "EXTERNAL",
        "categories": "{" + categories + "}",
        "description": kwargs.get("description", "description"),
        "detail": kwargs.get("detail", "detail"),
        "remediation": kwargs.get("remediation", "https://example.invalid/lint"),
        "metadata": json.dumps(metadata),
        "cache_key": kwargs.get("cache_key", f"cache_{name}"),
    }


def definer_row(sig, arguments=None, detail=None):
    if arguments is None:
        if sig.types:
            arguments = ", ".join(f"p{i} {part}" for i, part in enumerate(sig.types.split(", ")))
        else:
            arguments = ""
    return csv_row(
        "authenticated_security_definer_function_executable",
        "WARN",
        {
            "schema": "public",
            "name": sig.name,
            "arguments": arguments,
            "language": "sql",
            "security_definer": True,
        },
        categories="SECURITY",
        detail=detail or f"Function public.{sig.name}({sig.types})",
        cache_key=f"ck_{sig.name}",
    )


class RulesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)

    def write_baseline(self, doc):
        path = self.dir / "baseline.json"
        path.write_text(json.dumps(doc) + "\n", encoding="utf-8")
        return path

    def write_csv(self, rows):
        path = self.dir / "findings.csv"
        with path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=CSV_COLUMNS)
            writer.writeheader()
            writer.writerows(rows)
        return path

    def write_api(self, name, lints):
        path = self.dir / name
        path.write_text(json.dumps({"lints": lints}) + "\n", encoding="utf-8")
        return path

    def run_local(self, doc, rows):
        baseline = self.write_baseline(doc)
        findings = self.write_csv(rows)
        return check.execute(
            ["--layer", "local", "--baseline", str(baseline), "--findings", str(findings)]
        )

    def run_prod(self, doc, security, performance, today=date(2026, 10, 22)):
        baseline = self.write_baseline(doc)
        sec = self.write_api("security.json", security)
        perf = self.write_api("performance.json", performance)
        return check.execute(
            ["--layer", "prod", "--baseline", str(baseline), "--api", str(sec), str(perf)],
            today=today,
        )

    def test_new_finding_fails(self):
        code, out = self.run_local(
            baseline_doc(),
            [csv_row("auth_rls_initplan", "WARN", {"schema": "public", "name": "stories", "type": "table"},
                     detail="SENTINEL-DETAIL", cache_key="SENTINEL-CACHE", remediation="https://example.invalid/remediation")],
        )
        self.assertEqual(code, 1)
        self.assertIn("new name=auth_rls_initplan level=WARN", out)
        self.assertIn("detail=SENTINEL-DETAIL", out)
        self.assertIn("cache_key=SENTINEL-CACHE", out)
        self.assertIn("remediation=https://example.invalid/remediation", out)
        self.assertIn("advisors local: RED", out)
        code, out = self.run_prod(
            baseline_doc(),
            [],
            [api_lint("auth_rls_initplan", "WARN", detail="SENTINEL-DETAIL",
                      cache_key="SENTINEL-CACHE", remediation="https://example.invalid/remediation")],
        )
        self.assertEqual(code, 1)
        self.assertIn("class=new name=auth_rls_initplan level=WARN count=1", out)
        self.assertNotIn("SENTINEL", out)
        self.assertNotIn("http", out.lower())
        self.assertIn("advisors prod: RED", out)

    def test_stale_accepted_entry_fails(self):
        doc = baseline_doc(accepted=[accepted(scope="both")])
        code, out = self.run_local(doc, [])
        self.assertEqual(code, 1)
        self.assertIn("stale name=auth_rls_initplan level=- remove this entry in the same PR that fixed it", out)
        code, out = self.run_prod(doc, [], [])
        self.assertEqual(code, 1)
        self.assertIn("class=stale name=auth_rls_initplan level=- count=1", out)
        self.assertNotIn("remove this entry", out)
        self.assertIn("advisors prod: RED", out)

    def test_error_fails_even_when_baselined(self):
        doc = baseline_doc(accepted=[accepted(scope="both")])
        row = csv_row(
            "auth_rls_initplan",
            "ERROR",
            {"schema": "public", "name": "stories", "type": "table"},
            detail="SENTINEL-DETAIL",
            cache_key="SENTINEL-CACHE",
            remediation="https://example.invalid/remediation",
        )
        code, out = self.run_local(doc, [row])
        self.assertEqual(code, 1)
        self.assertIn("level=ERROR", out)
        self.assertIn("detail=SENTINEL-DETAIL", out)
        self.assertNotIn("accepted name=auth_rls_initplan", out)
        code, out = self.run_prod(
            doc,
            [],
            [api_lint("auth_rls_initplan", "ERROR", detail="SENTINEL-DETAIL",
                      cache_key="SENTINEL-CACHE", remediation="https://example.invalid/remediation")],
        )
        self.assertEqual(code, 1)
        self.assertIn("class=new name=auth_rls_initplan level=ERROR count=1", out)
        self.assertNotIn("class=accepted", out)
        self.assertNotIn("SENTINEL", out)

    def test_baseline_error_entry_is_invalid(self):
        doc = baseline_doc(accepted=[accepted(name="security_definer_view", scope="prod", owner="Bill")])
        code, out = self.run_prod(doc, [], [])
        self.assertEqual(code, 1)
        self.assertEqual(out, "error kind=baseline\nadvisors prod: RED\n")
        code, out = self.run_local(doc, [])
        self.assertEqual(code, 1)
        self.assertEqual(out, "error kind=baseline\nadvisors local: RED\n")

    def test_missing_reason_is_invalid(self):
        doc = baseline_doc(report_only=[{"name": "unused_index", "owner": "Gilfoyle"}])
        code, out = self.run_local(doc, [])
        self.assertEqual(code, 1)
        self.assertIn("error kind=baseline", out)

    def test_missing_owner_is_invalid(self):
        doc = baseline_doc(delegated=[{
            "name": "authenticated_security_definer_function_executable",
            "source": "supabase/tests/catalog_acl_guard.sql",
            "reason": "allowlist",
        }])
        code, out = self.run_prod(doc, [], [])
        self.assertEqual(code, 1)
        self.assertEqual(out, "error kind=baseline\nadvisors prod: RED\n")

    def test_missing_added_on_accepted_is_invalid(self):
        entry = accepted()
        del entry["added"]
        code, out = self.run_prod(baseline_doc(accepted=[entry]), [], [])
        self.assertEqual(code, 1)
        self.assertIn("error kind=baseline", out)

    def test_missing_review_by_on_accepted_is_invalid(self):
        entry = accepted()
        del entry["review_by"]
        code, out = self.run_local(baseline_doc(accepted=[entry]), [])
        self.assertEqual(code, 1)
        self.assertIn("error kind=baseline", out)

    def test_regex_key_rejected(self):
        entry = accepted(match={"name": "auth_rls_initplan", "regex": ".*"})
        code, out = self.run_local(baseline_doc(accepted=[entry]), [])
        self.assertEqual(code, 1)
        self.assertIn("error kind=baseline", out)

    def test_wildcard_match_rejected(self):
        entry = accepted(match={"name": "auth_*"})
        code, out = self.run_prod(baseline_doc(accepted=[entry]), [], [])
        self.assertEqual(code, 1)
        self.assertEqual(out, "error kind=baseline\nadvisors prod: RED\n")

    def test_report_only_dropped_both_layers(self):
        row = csv_row("unused_index", "INFO", {"schema": "public", "name": "stories", "type": "index"})
        code, out = self.run_local(baseline_doc(), [row])
        self.assertEqual(code, 0)
        self.assertIn("report-only name=unused_index count=1", out)
        self.assertIn("summary new=0 stale=0", out)
        self.assertIn("advisors local: GREEN", out)
        code, out = self.run_prod(baseline_doc(), [], [api_lint("unused_index", "INFO", categories=["PERFORMANCE"])])
        self.assertEqual(code, 0)
        self.assertIn("class=report-only name=unused_index level=INFO count=1", out)
        self.assertNotIn("class=new", out)
        self.assertIn("advisors prod: GREEN", out)

    def test_local_skip_dropped_only_on_local(self):
        row = csv_row(
            "extension_versions_outdated",
            "WARN",
            {"schema": "public", "name": "pgcrypto", "type": "extension"},
            categories="SECURITY",
        )
        code, out = self.run_local(baseline_doc(), [row])
        self.assertEqual(code, 0)
        self.assertIn("local-skip name=extension_versions_outdated count=1", out)
        self.assertIn("local-skip=1", out)
        self.assertNotIn("class=new", out)
        lint = api_lint(
            "extension_versions_outdated",
            "WARN",
            categories=["SECURITY"],
            detail="SENTINEL-DETAIL",
            metadata={"schema": "public", "name": "pgcrypto", "type": "extension"},
        )
        code, out = self.run_prod(baseline_doc(), [lint], [])
        self.assertEqual(code, 1)
        self.assertIn("class=new name=extension_versions_outdated level=WARN count=1", out)
        self.assertNotIn("SENTINEL", out)
        self.assertNotIn("pgcrypto", out)

    def test_definer_extra_finding_fails(self):
        allow = check.load_allowlist(check.catalog_path())
        rows = [definer_row(sig) for sig in allow]
        rows.append(csv_row(
            "authenticated_security_definer_function_executable",
            "WARN",
            {"schema": "public", "name": "not_allowed", "arguments": "uuid", "security_definer": True},
            categories="SECURITY",
            detail="SENTINEL-DETAIL-not_allowed",
            cache_key="SENTINEL-CACHE-not_allowed",
        ))
        code, out = self.run_local(baseline_doc(delegated=[DELEGATED]), rows)
        self.assertEqual(code, 1)
        self.assertIn("not_allowed", out)
        self.assertIn("detail=SENTINEL-DETAIL-not_allowed", out)
        security = []
        for sig in allow:
            arguments = ""
            if sig.types:
                arguments = ", ".join(f"p{i} {part}" for i, part in enumerate(sig.types.split(", ")))
            security.append(api_lint(
                "authenticated_security_definer_function_executable",
                "WARN",
                categories=["SECURITY"],
                metadata={"schema": "public", "name": sig.name, "arguments": arguments, "security_definer": True},
                detail="kept-off-prod",
                cache_key=f"ck_{sig.name}",
            ))
        security.append(api_lint(
            "authenticated_security_definer_function_executable",
            "WARN",
            categories=["SECURITY"],
            metadata={"schema": "public", "name": "not_allowed", "arguments": "uuid", "security_definer": True},
            detail="SENTINEL-DETAIL-not_allowed",
            cache_key="SENTINEL-CACHE-not_allowed",
        ))
        code, out = self.run_prod(baseline_doc(delegated=[DELEGATED]), security, [])
        self.assertEqual(code, 1)
        self.assertIn("class=new name=authenticated_security_definer_function_executable level=WARN count=1", out)
        self.assertIn("class=delegated name=authenticated_security_definer_function_executable level=WARN count=30", out)
        self.assertNotIn("not_allowed", out)
        self.assertNotIn("SENTINEL", out)

    def test_definer_missing_finding_fails(self):
        allow = check.load_allowlist(check.catalog_path())
        kept = [sig for sig in allow if sig.name != "transfer_ownership"]
        self.assertEqual(len(kept), 29)
        rows = [definer_row(sig) for sig in kept]
        code, out = self.run_local(baseline_doc(delegated=[DELEGATED]), rows)
        self.assertEqual(code, 1)
        self.assertIn("signature=public.transfer_ownership(uuid, uuid, text)", out)
        self.assertIn("stale=1", out)
        security = []
        for sig in kept:
            arguments = ""
            if sig.types:
                arguments = ", ".join(
                    f"p{i} {part}" for i, part in enumerate(sig.types.split(", "))
                )
            security.append(api_lint(
                "authenticated_security_definer_function_executable",
                "WARN",
                categories=["SECURITY"],
                metadata={"schema": "public", "name": sig.name, "arguments": arguments},
                cache_key=f"ck_{sig.name}",
                detail="hidden",
            ))
        code, out = self.run_prod(baseline_doc(delegated=[DELEGATED]), security, [])
        self.assertEqual(code, 1)
        self.assertIn(
            "class=stale name=authenticated_security_definer_function_executable level=- count=1",
            out,
        )
        self.assertNotIn("transfer_ownership", out)
        self.assertNotIn("hidden", out)

    def test_past_review_by_amber_on_prod_only(self):
        past = baseline_doc(accepted=[accepted(scope="both", review_by="2020-01-01")])
        future = baseline_doc(accepted=[accepted(scope="both", review_by="2099-12-31")])
        row = csv_row("auth_rls_initplan", "WARN", {"schema": "public", "name": "stories", "type": "table"})
        lint = api_lint("auth_rls_initplan", "WARN")
        local_past = self.run_local(past, [row])
        local_future = self.run_local(future, [row])
        self.assertEqual(local_past[0], 0)
        self.assertEqual(local_future[0], 0)
        self.assertEqual(local_past[1], local_future[1])
        self.assertNotIn("amber", local_past[1].lower())
        self.assertIn("advisors local: GREEN", local_past[1])
        code, out = self.run_prod(past, [], [lint], today=date(2026, 10, 22))
        self.assertEqual(code, 0)
        self.assertIn("amber name=auth_rls_initplan review_by=2020-01-01", out)
        self.assertIn("advisors prod: AMBER", out)
        code, out = self.run_prod(future, [], [lint], today=date(2026, 10, 22))
        self.assertEqual(code, 0)
        self.assertNotIn("amber ", out)
        self.assertIn("advisors prod: GREEN", out)

    def test_parse_error_exits_nonzero(self):
        baseline = self.write_baseline(baseline_doc())
        bad = self.dir / "bad.json"
        bad.write_text("{", encoding="utf-8")
        empty = self.write_api("empty.json", [])
        proc = subprocess.run(
            [sys.executable, str(CHECK), "--layer", "prod", "--baseline", str(baseline),
             "--api", str(bad), str(empty)],
            cwd=HERE,
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
            env={k: v for k, v in os.environ.items() if k != "GITHUB_TOKEN"},
        )
        self.assertEqual(proc.returncode, 1)
        self.assertEqual(proc.stderr, "")
        self.assertEqual(proc.stdout, "error kind=parse\nadvisors prod: RED\n")

    def test_missing_file_is_input_error(self):
        baseline = self.write_baseline(baseline_doc())
        code, out = check.execute(
            ["--layer", "prod", "--baseline", str(baseline), "--api",
             str(self.dir / "missing.json"), str(self.dir / "also-missing.json")],
            today=date(2026, 10, 22),
        )
        self.assertEqual(code, 1)
        self.assertEqual(out, "error kind=input\nadvisors prod: RED\n")

    def test_mcp_grouped_shape_is_parse_error(self):
        grouped = {
            "lints": [
                {
                    "name": "unindexed_foreign_keys",
                    "title": "grouped",
                    "level": "INFO",
                    "facing": "EXTERNAL",
                    "categories": ["PERFORMANCE"],
                    "description": "grouped",
                    "detail": "SENTINEL-DETAIL",
                    "remediation": "https://example.invalid/grouped",
                    "metadata": [{"schema": "public", "name": "comments"}],
                    "cache_key": "grouped",
                }
            ]
        }
        path = self.dir / "grouped.json"
        path.write_text(json.dumps(grouped) + "\n", encoding="utf-8")
        empty = self.write_api("empty.json", [])
        baseline = self.write_baseline(baseline_doc())
        code, out = check.execute(
            ["--layer", "prod", "--baseline", str(baseline), "--api", str(path), str(empty)],
            today=date(2026, 10, 22),
        )
        self.assertEqual(code, 1)
        self.assertEqual(out, "error kind=parse\nadvisors prod: RED\n")
        self.assertNotIn("SENTINEL", out)

    def test_security_lint_cannot_be_accepted(self):
        entry = accepted(name="function_search_path_mutable", scope="prod", owner="Bill")
        code, out = self.run_prod(baseline_doc(accepted=[entry]), [], [])
        self.assertEqual(code, 1)
        self.assertIn("error kind=baseline", out)

    def test_allowlist_comes_from_catalog_file(self):
        sigs = check.load_allowlist(check.catalog_path())
        self.assertEqual(len(sigs), 30)
        names = {sig.name for sig in sigs}
        self.assertIn("add_co_owner", names)
        self.assertIn("my_profile", names)
        self.assertIn("rename_family", names)
        self.assertNotIn("upsert_story_member", names)
        text = check.catalog_path().read_text(encoding="utf-8")
        for sig in sigs:
            self.assertIn(f"{sig.name}({sig.types})", text)
        rename = next(sig for sig in sigs if sig.name == "rename_family")
        self.assertEqual(check.normalize_arg_types("fid uuid, name text"), rename.types)

    def test_real_baseline_matches_thirty_definers(self):
        allow = check.load_allowlist(check.catalog_path())
        rows = [definer_row(sig) for sig in allow]
        rows.append(csv_row("unused_index", "INFO", {"schema": "public", "name": "stories", "type": "index"}))
        rows.append(csv_row(
            "extension_versions_outdated",
            "WARN",
            {"type": "extension"},
            categories="SECURITY",
        ))
        findings = self.write_csv(rows)
        code, out = check.execute(
            ["--layer", "local", "--baseline", str(REAL_BASELINE), "--findings", str(findings)]
        )
        self.assertEqual(code, 0, out)
        self.assertIn("delegated name=authenticated_security_definer_function_executable matched=30", out)
        self.assertIn("summary new=0 stale=0 delegated=30 accepted=0 report-only=1 local-skip=1", out)
        self.assertIn("report-only name=unused_index count=1", out)
        self.assertIn("report-only name=table_bloat count=0", out)
        self.assertIn("local-skip name=pg_graphql_anon_table_exposed count=0", out)
        self.assertIn("advisors local: GREEN", out)

    def test_prod_redaction_fixture_exact_lines(self):
        fix = HERE / "fixtures" / "prod_redaction"
        code, out = check.execute(
            ["--layer", "prod", "--baseline", str(fix / "baseline.json"),
             "--api", str(fix / "security.json"), str(fix / "performance.json")],
            today=date(2026, 10, 22),
        )
        self.assertEqual(code, 1)
        self.assertEqual(
            out,
            "\n".join([
                "class=new name=auth_rls_initplan level=WARN count=1",
                "class=new name=security_definer_view level=ERROR count=2",
                "class=accepted name=auth_leaked_password_protection level=WARN count=1",
                "class=report-only name=unused_index level=INFO count=3",
                "summary new=3 stale=0 delegated=0 accepted=1 report-only=3",
                "advisors prod: RED",
                "",
            ]),
        )


if __name__ == "__main__":
    unittest.main()
