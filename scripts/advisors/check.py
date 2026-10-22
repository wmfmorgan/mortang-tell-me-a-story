"""Supabase advisors gate (lock §7.2, Addendum A6(b), Addendum B1).

Stdlib only. --layer prod prints only the §7.2a lines. --wait-deploy sends
GITHUB_TOKEN only to https://api.github.com and never prints it.
"""

import argparse
import csv
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path

PIN_COMMIT = "fccca4b1c4d8b48b8ccd69bd6b30e84adcb92975"
PIN_SHA256 = "d8d558baad3e03832e521c527907fa50a9a172fabd899dd0f5c2504a5a0e9349"
DELEGATED_LINT = "authenticated_security_definer_function_executable"

# Level and category from splinter fccca4b1 (29 lints). Used to reject a
# baseline that accepts an ERROR lint or a SECURITY lint. Not an allowlist.
_LINTS = {
    "unindexed_foreign_keys": ("INFO", "PERFORMANCE"),
    "auth_users_exposed": ("ERROR", "SECURITY"),
    "auth_rls_initplan": ("WARN", "PERFORMANCE"),
    "no_primary_key": ("INFO", "PERFORMANCE"),
    "unused_index": ("INFO", "PERFORMANCE"),
    "multiple_permissive_policies": ("WARN", "PERFORMANCE"),
    "policy_exists_rls_disabled": ("ERROR", "SECURITY"),
    "rls_enabled_no_policy": ("INFO", "SECURITY"),
    "duplicate_index": ("WARN", "PERFORMANCE"),
    "security_definer_view": ("ERROR", "SECURITY"),
    "function_search_path_mutable": ("WARN", "SECURITY"),
    "rls_disabled_in_public": ("ERROR", "SECURITY"),
    "extension_in_public": ("WARN", "SECURITY"),
    "rls_references_user_metadata": ("ERROR", "SECURITY"),
    "materialized_view_in_api": ("WARN", "SECURITY"),
    "foreign_table_in_api": ("WARN", "SECURITY"),
    "unsupported_reg_types": ("WARN", "SECURITY"),
    "insecure_queue_exposed_in_api": ("ERROR", "SECURITY"),
    "table_bloat": ("WARN", "PERFORMANCE"),
    "fkey_to_auth_unique": ("ERROR", "SECURITY"),
    "extension_versions_outdated": ("WARN", "SECURITY"),
    "sensitive_columns_exposed": ("ERROR", "SECURITY"),
    "rls_policy_always_true": ("WARN", "SECURITY"),
    "public_bucket_allows_listing": ("WARN", "SECURITY"),
    "pg_graphql_anon_table_exposed": ("WARN", "SECURITY"),
    "pg_graphql_authenticated_table_exposed": ("WARN", "SECURITY"),
    "anon_security_definer_function_executable": ("WARN", "SECURITY"),
    "authenticated_security_definer_function_executable": ("WARN", "SECURITY"),
    "autovacuum_disabled": ("INFO", "PERFORMANCE"),
}
_ERROR_LINTS = {name for name, (level, _) in _LINTS.items() if level == "ERROR"}
_SECURITY_LINTS = {name for name, (_, cat) in _LINTS.items() if cat == "SECURITY"}

_LINT_NAME = re.compile(r"^[a-z0-9_]+$")
_IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_$]*")
_CSV_COLUMNS = [
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
_API_KEYS = frozenset(_CSV_COLUMNS)
_LEVELS = {"ERROR", "WARN", "INFO"}
_CLASS_ORDER = {"new": 0, "stale": 1, "delegated": 2, "accepted": 3, "report-only": 4}
_LEVEL_ORDER = {"ERROR": 0, "WARN": 1, "INFO": 2, "-": 3}
_MULTIWORD_TYPES = (
    "timestamp with time zone",
    "timestamp without time zone",
    "time with time zone",
    "time without time zone",
    "double precision",
    "character varying",
    "bit varying",
)
_POLL_S = 30
_PROD_LINE = re.compile(
    r"^(?:"
    r"class=(?:new|stale|delegated|accepted|report-only) "
    r"name=[a-z0-9_]+ level=(?:ERROR|WARN|INFO|-) count=[0-9]+"
    r"|summary new=[0-9]+ stale=[0-9]+ delegated=[0-9]+ "
    r"accepted=[0-9]+ report-only=[0-9]+"
    r"|amber name=[a-z0-9_]+ review_by=[0-9]{4}-[0-9]{2}-[0-9]{2}"
    r"|error kind=(?:input|parse|baseline)"
    r"|advisors prod: (?:GREEN|AMBER|RED)"
    r")$"
)


class AdvisorsError(Exception):
    kind = "parse"


class InputError(AdvisorsError):
    kind = "input"


class ParseError(AdvisorsError):
    kind = "parse"


class BaselineError(AdvisorsError):
    kind = "baseline"


@dataclass(frozen=True)
class Finding:
    name: str
    level: str
    detail: str
    cache_key: str
    remediation: str
    metadata: dict
    categories: tuple
    title: str
    description: str


@dataclass(frozen=True)
class Accepted:
    name: str
    metadata: tuple
    scope: str
    review_by: date
    owner: str


@dataclass(frozen=True)
class Sig:
    schema: str
    name: str
    types: str


@dataclass
class Baseline:
    report_only_names: list
    local_skip_names: list
    delegated: str | None
    accepted: list


@dataclass
class Report:
    new: list
    accepted_findings: list
    delegated_findings: list
    report_only: list
    local_skip: list
    stale_accepted: list
    stale_sigs: list
    amber: list


def catalog_path():
    return Path(__file__).resolve().parents[2] / "supabase" / "tests" / "catalog_acl_guard.sql"


def _read_text(path):
    try:
        return Path(path).read_text(encoding="utf-8")
    except UnicodeDecodeError:
        raise ParseError() from None
    except OSError:
        raise InputError() from None


def _require_name(value):
    if not isinstance(value, str) or not _LINT_NAME.fullmatch(value):
        raise BaselineError()
    return value


def _require_text(value):
    if not isinstance(value, str) or value.strip() == "":
        raise BaselineError()
    return value


def _require_date(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        raise BaselineError()
    try:
        return date.fromisoformat(value)
    except ValueError:
        raise BaselineError() from None


def _exact_keys(obj, allowed):
    if not isinstance(obj, dict) or set(obj) - allowed:
        raise BaselineError()


def load_baseline(path):
    try:
        data = json.loads(_read_text(path))
    except json.JSONDecodeError:
        raise ParseError() from None
    if (
        not isinstance(data, dict)
        or set(data)
        != {
            "version",
            "splinter",
            "report_only_lints",
            "local_skip_lints",
            "delegated",
            "accepted",
        }
        or type(data["version"]) is not int
        or data["version"] != 1
    ):
        raise BaselineError()
    pin = data["splinter"]
    if (
        not isinstance(pin, dict)
        or set(pin) != {"commit", "sha256"}
        or pin["commit"] != PIN_COMMIT
        or pin["sha256"] != PIN_SHA256
    ):
        raise BaselineError()

    def named_rules(items, allowed_keys):
        if not isinstance(items, list):
            raise BaselineError()
        names = []
        for item in items:
            _exact_keys(item, allowed_keys)
            for key in allowed_keys:
                if key not in item:
                    raise BaselineError()
            name = _require_name(item["name"])
            _require_text(item["reason"])
            _require_text(item["owner"])
            if name in _ERROR_LINTS:
                raise BaselineError()
            names.append(name)
        if len(names) != len(set(names)):
            raise BaselineError()
        return names

    report_only = named_rules(
        data["report_only_lints"], {"name", "reason", "owner"}
    )
    local_skip = named_rules(
        data["local_skip_lints"], {"name", "reason", "owner"}
    )
    if set(report_only) & set(local_skip):
        raise BaselineError()

    raw_delegated = data["delegated"]
    if not isinstance(raw_delegated, list) or len(raw_delegated) > 1:
        raise BaselineError()
    delegated = None
    if raw_delegated:
        item = raw_delegated[0]
        _exact_keys(item, {"name", "source", "reason", "owner"})
        for key in ("name", "source", "reason", "owner"):
            if key not in item:
                raise BaselineError()
        delegated = _require_name(item["name"])
        _require_text(item["source"])
        _require_text(item["reason"])
        _require_text(item["owner"])
        if delegated != DELEGATED_LINT or delegated in _ERROR_LINTS:
            raise BaselineError()
        if delegated in report_only or delegated in local_skip:
            raise BaselineError()

    if not isinstance(data["accepted"], list):
        raise BaselineError()
    accepted = []
    seen = set()
    for item in data["accepted"]:
        _exact_keys(
            item,
            {"match", "scope", "reason", "owner", "added", "review_by", "ref"},
        )
        for key in ("match", "scope", "reason", "owner", "added", "review_by"):
            if key not in item:
                raise BaselineError()
        match = item["match"]
        if not isinstance(match, dict) or "name" not in match:
            raise BaselineError()
        name = _require_name(match["name"])
        meta = []
        for key, expected in match.items():
            if key == "name":
                continue
            if not key.startswith("metadata."):
                raise BaselineError()
            parts = tuple(key.split(".")[1:])
            if not parts or any(not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", p) for p in parts):
                raise BaselineError()
            if (
                not isinstance(expected, str)
                or expected == ""
                or re.search(r"[*?\[\]()|+^$\\]", expected)
                or ".*" in expected
            ):
                raise BaselineError()
            meta.append((parts, expected))
        scope = item["scope"]
        if scope not in ("prod", "local", "both"):
            raise BaselineError()
        owner = _require_text(item["owner"])
        _require_text(item["reason"])
        _require_date(item["added"])
        review_by = _require_date(item["review_by"])
        if "ref" in item:
            _require_text(item["ref"])
        if name in _ERROR_LINTS or name in _SECURITY_LINTS:
            raise BaselineError()
        if name not in _LINTS and not (owner == "Bill" and scope == "prod"):
            raise BaselineError()
        if name in report_only or name in local_skip or name == delegated:
            raise BaselineError()
        if name in seen:
            raise BaselineError()
        seen.add(name)
        accepted.append(
            Accepted(name, tuple(meta), scope, review_by, owner)
        )
    return Baseline(report_only, local_skip, delegated, accepted)


def _split_args(text):
    if text.strip() == "":
        return []
    parts = []
    buf = []
    depth = 0
    for ch in text:
        if ch == "," and depth == 0:
            parts.append("".join(buf).strip())
            buf = []
            continue
        if ch in "([":
            depth += 1
        elif ch in ")]" and depth:
            depth -= 1
        buf.append(ch)
    parts.append("".join(buf).strip())
    return [part for part in parts if part != ""]


def _extract_type(part):
    part = " ".join(part.split())
    if part == "":
        raise ParseError()
    low = part.lower()
    for mode in ("inout ", "variadic ", "out ", "in "):
        if low.startswith(mode):
            part = part[len(mode) :]
            low = part.lower()
            break
    for prefix in _MULTIWORD_TYPES:
        if low == prefix or low.startswith(prefix + " ") or low.startswith(prefix + "("):
            return low
    tokens = part.split(" ")
    if len(tokens) > 1 and _IDENT.fullmatch(tokens[0]):
        return " ".join(tokens[1:]).lower()
    return low


def normalize_arg_types(arguments):
    if not isinstance(arguments, str):
        raise ParseError()
    if arguments.strip() == "":
        return ""
    return ", ".join(_extract_type(part) for part in _split_args(arguments))


def load_allowlist(path):
    text = _read_text(path)
    match = re.search(r"set_eq\(\$\$.*?\$\$,\s*\$\$values\b(.*?)\${2}", text, re.S)
    if not match:
        raise ParseError()
    raw = re.findall(r"\('([^']+)'\)", match.group(1))
    sigs = []
    for item in raw:
        parsed = re.fullmatch(r"([a-z_][a-z0-9_]*)\((.*)\)", item)
        if not parsed:
            raise ParseError()
        name, args = parsed.groups()
        sigs.append(Sig("public", name, normalize_arg_types(args)))
    if not sigs or len(sigs) != len(set(sigs)):
        raise ParseError()
    return sigs


def _finding_from_fields(fields):
    name = fields["name"]
    level = fields["level"]
    if not isinstance(name, str) or not _LINT_NAME.fullmatch(name):
        raise ParseError()
    if level not in _LEVELS:
        raise ParseError()
    metadata = fields["metadata"]
    if not isinstance(metadata, dict):
        raise ParseError()
    for banned in ("entities", "findings", "items"):
        if isinstance(metadata.get(banned), list):
            raise ParseError()
    categories = fields["categories"]
    if (
        not isinstance(categories, list)
        or not categories
        or not all(isinstance(item, str) and item != "" for item in categories)
    ):
        raise ParseError()
    for key in ("detail", "cache_key", "remediation", "title", "description", "facing"):
        if not isinstance(fields[key], str):
            raise ParseError()
    return Finding(
        name=name,
        level=level,
        detail=fields["detail"],
        cache_key=fields["cache_key"],
        remediation=fields["remediation"],
        metadata=metadata,
        categories=tuple(categories),
        title=fields["title"],
        description=fields["description"],
    )


def _parse_pg_categories(value):
    if not isinstance(value, str):
        raise ParseError()
    text = value.strip()
    if len(text) < 2 or text[0] != "{" or text[-1] != "}":
        raise ParseError()
    inner = text[1:-1].strip()
    if inner == "":
        raise ParseError()
    parts = []
    for piece in inner.split(","):
        item = piece.strip().strip('"')
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*", item):
            raise ParseError()
        parts.append(item)
    return parts


def parse_csv_findings(text):
    reader = csv.DictReader(io.StringIO(text))
    if reader.fieldnames != _CSV_COLUMNS:
        raise ParseError()
    findings = []
    for row in reader:
        if None in row or row.get(None):
            raise ParseError()
        try:
            metadata = json.loads(row["metadata"])
        except (json.JSONDecodeError, TypeError):
            raise ParseError() from None
        fields = dict(row)
        fields["metadata"] = metadata
        fields["categories"] = _parse_pg_categories(row["categories"])
        findings.append(_finding_from_fields(fields))
    return findings


def parse_api_document(text):
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        raise ParseError() from None
    if not isinstance(data, dict) or set(data) != {"lints"} or not isinstance(data["lints"], list):
        raise ParseError()
    findings = []
    for lint in data["lints"]:
        if not isinstance(lint, dict) or set(lint) != _API_KEYS:
            raise ParseError()
        findings.append(_finding_from_fields(lint))
    return findings


def _signature_of(finding):
    metadata = finding.metadata
    schema = metadata.get("schema")
    name = metadata.get("name")
    arguments = metadata.get("arguments")
    if not isinstance(schema, str) or not isinstance(name, str):
        raise ParseError()
    if not re.fullmatch(r"[a-z_][a-z0-9_]*", schema):
        raise ParseError()
    if not re.fullmatch(r"[a-z_][a-z0-9_]*", name):
        raise ParseError()
    return Sig(schema, name, normalize_arg_types(arguments))


def _in_scope(entry, layer):
    return entry.scope == "both" or entry.scope == layer


def _matches(finding, entry):
    if finding.name != entry.name:
        return False
    for path, expected in entry.metadata:
        current = finding.metadata
        for part in path:
            if not isinstance(current, dict) or part not in current:
                return False
            current = current[part]
        if current != expected:
            return False
    return True


def evaluate(baseline, findings, allow, layer, today):
    scoped = [entry for entry in baseline.accepted if _in_scope(entry, layer)]
    allow_set = set(allow)
    report = Report([], [], [], [], [], [], [], [])
    covered = set()
    for finding in findings:
        if finding.level == "ERROR":
            report.new.append(finding)
            continue
        if finding.name in baseline.report_only_names:
            report.report_only.append(finding)
            continue
        if layer == "local" and finding.name in baseline.local_skip_names:
            report.local_skip.append(finding)
            continue
        if baseline.delegated and finding.name == baseline.delegated:
            sig = _signature_of(finding)
            if sig in allow_set:
                report.delegated_findings.append(finding)
                covered.add(sig)
            else:
                report.new.append(finding)
            continue
        if any(_matches(finding, entry) for entry in scoped):
            report.accepted_findings.append(finding)
            continue
        report.new.append(finding)
    for entry in scoped:
        if not any(_matches(finding, entry) for finding in findings):
            report.stale_accepted.append(entry)
    if baseline.delegated:
        report.stale_sigs = sorted(
            allow_set - covered, key=lambda sig: (sig.name, sig.types)
        )
    if layer == "prod":
        report.amber = sorted(
            (entry for entry in scoped if entry.review_by < today),
            key=lambda entry: entry.name,
        )
    return report


def _status(report):
    if report.new or report.stale_accepted or report.stale_sigs:
        return 1, "RED"
    if report.amber:
        return 0, "AMBER"
    return 0, "GREEN"


def _summary_counts(report):
    return {
        "new": len(report.new),
        "stale": len(report.stale_accepted) + len(report.stale_sigs),
        "delegated": len(report.delegated_findings),
        "accepted": len(report.accepted_findings),
        "report-only": len(report.report_only),
        "local-skip": len(report.local_skip),
    }


def format_prod(report, baseline):
    groups = Counter()
    for finding in report.new:
        groups[("new", finding.name, finding.level)] += 1
    for entry in report.stale_accepted:
        groups[("stale", entry.name, "-")] += 1
    if report.stale_sigs and baseline.delegated:
        groups[("stale", baseline.delegated, "-")] += len(report.stale_sigs)
    for finding in report.delegated_findings:
        groups[("delegated", finding.name, finding.level)] += 1
    for finding in report.accepted_findings:
        groups[("accepted", finding.name, finding.level)] += 1
    for finding in report.report_only:
        groups[("report-only", finding.name, finding.level)] += 1
    lines = []
    for key in sorted(groups, key=lambda item: (_CLASS_ORDER[item[0]], item[1], _LEVEL_ORDER[item[2]])):
        klass, name, level = key
        lines.append(f"class={klass} name={name} level={level} count={groups[key]}")
    for entry in report.amber:
        lines.append(f"amber name={entry.name} review_by={entry.review_by.isoformat()}")
    counts = _summary_counts(report)
    lines.append(
        f"summary new={counts['new']} stale={counts['stale']} "
        f"delegated={counts['delegated']} accepted={counts['accepted']} "
        f"report-only={counts['report-only']}"
    )
    _code, status = _status(report)
    lines.append(f"advisors prod: {status}")
    text = "\n".join(lines) + "\n"
    for line in lines:
        if not _PROD_LINE.fullmatch(line):
            raise ParseError()
    return text


def format_local(report, baseline):
    lines = []
    for finding in sorted(report.new, key=lambda item: (item.name, item.cache_key)):
        detail = " ".join(finding.detail.split())
        lines.append(
            f"new name={finding.name} level={finding.level} detail={detail} "
            f"cache_key={finding.cache_key} remediation={finding.remediation}"
        )
    for entry in sorted(report.stale_accepted, key=lambda item: item.name):
        lines.append(
            f"stale name={entry.name} level=- remove this entry in the same PR that fixed it"
        )
    for sig in report.stale_sigs:
        lines.append(
            f"stale delegated name={baseline.delegated} "
            f"signature={sig.schema}.{sig.name}({sig.types})"
        )
    report_counts = Counter(finding.name for finding in report.report_only)
    for name in baseline.report_only_names:
        lines.append(f"report-only name={name} count={report_counts.get(name, 0)}")
    skip_counts = Counter(finding.name for finding in report.local_skip)
    for name in baseline.local_skip_names:
        lines.append(f"local-skip name={name} count={skip_counts.get(name, 0)}")
    if baseline.delegated:
        lines.append(
            f"delegated name={baseline.delegated} matched={len(report.delegated_findings)}"
        )
    accepted_counts = Counter(finding.name for finding in report.accepted_findings)
    for name in sorted(accepted_counts):
        lines.append(f"accepted name={name} count={accepted_counts[name]}")
    counts = _summary_counts(report)
    lines.append(
        f"summary new={counts['new']} stale={counts['stale']} "
        f"delegated={counts['delegated']} accepted={counts['accepted']} "
        f"report-only={counts['report-only']} local-skip={counts['local-skip']}"
    )
    _code, status = _status(report)
    lines.append(f"advisors local: {status}")
    return "\n".join(lines) + "\n"


def _allow_for(baseline):
    if not baseline.delegated:
        return []
    return load_allowlist(catalog_path())


def run_local(baseline_path, findings_path):
    baseline = load_baseline(baseline_path)
    findings = parse_csv_findings(_read_text(findings_path))
    report = evaluate(baseline, findings, _allow_for(baseline), "local", date(1970, 1, 1))
    code, _status_name = _status(report)
    return code, format_local(report, baseline)


def run_prod(baseline_path, api_paths, today):
    baseline = load_baseline(baseline_path)
    findings = []
    for path in api_paths:
        findings.extend(parse_api_document(_read_text(path)))
    report = evaluate(baseline, findings, _allow_for(baseline), "prod", today)
    code, _status_name = _status(report)
    return code, format_prod(report, baseline)


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def real_http_get(url, headers, timeout=30):
    parts = urllib.parse.urlsplit(url)
    if parts.scheme != "https" or parts.hostname != "api.github.com":
        raise ParseError()
    request = urllib.request.Request(url, headers=dict(headers), method="GET")
    opener = urllib.request.build_opener(_NoRedirect)
    try:
        with opener.open(request, timeout=timeout) as response:
            return response.status, response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        return exc.code, ""
    except Exception:
        raise ParseError() from None


def _check_runs_url(repo, sha, check_name):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo or ""):
        raise ParseError()
    if not re.fullmatch(r"[0-9a-fA-F]{7,64}", sha or ""):
        raise ParseError()
    if not re.fullmatch(r"[A-Za-z0-9 ._:-]{1,100}", check_name or ""):
        raise ParseError()
    query = (
        "check_name="
        + urllib.parse.quote(check_name, safe="")
        + "&per_page=100"
    )
    return f"https://api.github.com/repos/{repo}/commits/{sha}/check-runs?{query}"


def _deploy_state(body, check_name, check_app):
    try:
        data = json.loads(body)
    except json.JSONDecodeError:
        raise ParseError() from None
    runs = data.get("check_runs") if isinstance(data, dict) else None
    if not isinstance(runs, list):
        raise ParseError()
    saw_success = False
    for run in runs:
        if not isinstance(run, dict):
            raise ParseError()
        if run.get("name") != check_name:
            continue
        app = run.get("app")
        if not isinstance(app, dict) or app.get("slug") != check_app:
            continue
        if run.get("status") != "completed":
            continue
        if run.get("conclusion") == "success":
            saw_success = True
        else:
            return "red"
    if saw_success:
        return "green"
    return "pending"


def wait_for_deploy(
    *,
    repo,
    sha,
    check_name,
    check_app,
    timeout_s,
    token,
    http_get,
    sleep,
    monotonic,
):
    if not isinstance(check_app, str) or not re.fullmatch(r"[a-z0-9_-]+", check_app):
        raise ParseError()
    if not isinstance(timeout_s, int) or isinstance(timeout_s, bool) or timeout_s < 0:
        raise ParseError()
    url = _check_runs_url(repo, sha, check_name)
    if urllib.parse.urlsplit(url).hostname != "api.github.com":
        raise ParseError()
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "advisors-check",
    }
    start = monotonic()
    while True:
        if monotonic() - start >= timeout_s:
            return 1, "deploy not confirmed\n"
        try:
            status, body = http_get(url, headers, 30)
        except Exception:
            raise ParseError() from None
        if not isinstance(status, int) or status < 200 or status > 299:
            return 1, "deploy not confirmed\n"
        state = _deploy_state(body, check_name, check_app)
        if state == "green":
            return 0, "deploy confirmed\n"
        if state == "red":
            return 1, "deploy not confirmed\n"
        remaining = timeout_s - (monotonic() - start)
        if remaining <= 0:
            return 1, "deploy not confirmed\n"
        sleep(min(_POLL_S, remaining))


def _parser():
    parser = argparse.ArgumentParser(add_help=False, exit_on_error=False)
    parser.add_argument("--layer", choices=("local", "prod"))
    parser.add_argument("--baseline")
    parser.add_argument("--findings")
    parser.add_argument("--api", nargs=2)
    parser.add_argument("--wait-deploy", action="store_true")
    parser.add_argument("--repo")
    parser.add_argument("--sha")
    parser.add_argument("--check-name")
    parser.add_argument("--check-app")
    parser.add_argument("--timeout-s", type=int, default=900)
    return parser


def _mode_of(argv):
    if "--wait-deploy" in argv:
        return "wait"
    if "--layer" in argv:
        index = argv.index("--layer")
        if index + 1 < len(argv) and argv[index + 1] == "prod":
            return "prod"
    return "local"


def _fail(mode, kind):
    if mode == "wait":
        return 1, "deploy not confirmed\n"
    if mode == "prod":
        return 1, f"error kind={kind}\nadvisors prod: RED\n"
    return 1, f"error kind={kind}\nadvisors local: RED\n"


def execute(argv, *, http_get=None, sleep=None, monotonic=None, today=None, env=None):
    mode = _mode_of(argv)
    try:
        args, unknown = _parser().parse_known_args(argv)
        if unknown:
            raise ParseError()
        if args.wait_deploy:
            mode = "wait"
            if args.layer or args.baseline or args.findings or args.api:
                raise ParseError()
            if not args.repo or not args.sha or not args.check_name or not args.check_app:
                raise ParseError()
            source = os.environ if env is None else env
            token = source.get("GITHUB_TOKEN") if source else None
            if not isinstance(token, str) or token.strip() == "":
                return 1, "deploy not confirmed\n"
            return wait_for_deploy(
                repo=args.repo,
                sha=args.sha,
                check_name=args.check_name,
                check_app=args.check_app,
                timeout_s=args.timeout_s,
                token=token,
                http_get=http_get or real_http_get,
                sleep=sleep or time.sleep,
                monotonic=monotonic or time.monotonic,
            )
        if args.layer == "local":
            mode = "local"
            if not args.baseline or not args.findings or args.api:
                raise InputError()
            return run_local(args.baseline, args.findings)
        if args.layer == "prod":
            mode = "prod"
            if not args.baseline or not args.api or args.findings:
                raise InputError()
            when = today if today is not None else datetime.now(timezone.utc).date()
            return run_prod(args.baseline, args.api, when)
        raise InputError()
    except AdvisorsError as exc:
        return _fail(mode, exc.kind)
    except Exception:
        return _fail(mode, "parse")


def main(argv=None):
    code, out = execute(sys.argv[1:] if argv is None else argv)
    sys.stdout.write(out)
    return code


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.stdout.write("error kind=parse\nadvisors prod: RED\n")
        sys.exit(1)
