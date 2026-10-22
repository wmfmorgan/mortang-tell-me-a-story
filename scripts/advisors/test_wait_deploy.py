"""Offline tests for --wait-deploy (Addendum A6(b) rules 1-6)."""

import json
import unittest

import check

REPO = "wmfmorgan/mortang-tell-me-a-story"
SHA = "7d47fdd3fb90781b686899196d6783d246643a0f"
TOKEN = "test-token-value-not-a-secret"
URL = (
    "https://api.github.com/repos/wmfmorgan/mortang-tell-me-a-story/commits/"
    + SHA
    + "/check-runs?check_name=Supabase%20Preview&per_page=100"
)


def argv(timeout="900"):
    return [
        "--wait-deploy",
        "--repo", REPO,
        "--sha", SHA,
        "--check-name", "Supabase Preview",
        "--check-app", "supabase",
        "--timeout-s", timeout,
    ]


def run_body(status, body, timeout="900", token=TOKEN, clock=None):
    calls = []

    def http_get(url, headers, timeout_s=30):
        calls.append((url, dict(headers), timeout_s))
        if isinstance(status, Exception):
            raise status
        if isinstance(body, list):
            item = body.pop(0)
            return item
        return status, body

    kwargs = {"http_get": http_get, "env": {"GITHUB_TOKEN": token} if token is not None else {}}
    if clock is not None:
        kwargs["sleep"] = clock.sleep
        kwargs["monotonic"] = clock.monotonic
    code, out = check.execute(argv(timeout), **kwargs)
    return code, out, calls


class Clock:
    def __init__(self):
        self.t = 0
        self.slept = []

    def monotonic(self):
        return self.t

    def sleep(self, seconds):
        self.slept.append(seconds)
        self.t += seconds


def preview(status="completed", conclusion="success", name="Supabase Preview", slug="supabase"):
    return json.dumps({
        "check_runs": [
            {
                "name": name,
                "status": status,
                "conclusion": conclusion,
                "app": {"slug": slug, "name": "Supabase"},
            }
        ]
    })


class WaitDeployTest(unittest.TestCase):
    def test_wait_success(self):
        code, out, calls = run_body(200, preview())
        self.assertEqual(code, 0)
        self.assertEqual(out, "deploy confirmed\n")
        self.assertEqual(len(calls), 1)
        self.assertNotIn(TOKEN, out)

    def test_wait_nonsuccess(self):
        code, out, calls = run_body(200, preview(conclusion="failure"))
        self.assertEqual(code, 1)
        self.assertEqual(out, "deploy not confirmed\n")
        self.assertEqual(len(calls), 1)
        self.assertNotIn("failure", out)

    def test_wait_timeout(self):
        clock = Clock()
        code, out, calls = run_body(200, preview(status="in_progress", conclusion=None), timeout="60", clock=clock)
        self.assertEqual(code, 1)
        self.assertEqual(out, "deploy not confirmed\n")
        self.assertEqual(clock.slept, [30, 30])
        self.assertEqual(len(calls), 2)

    def test_wait_api_error(self):
        code, out, calls = run_body(500, "server blew up")
        self.assertEqual(code, 1)
        self.assertEqual(out, "deploy not confirmed\n")
        self.assertEqual(len(calls), 1)
        self.assertNotIn("blew up", out)

    def test_wait_network_error(self):
        code, out, calls = run_body(OSError("timed out connecting"), "")
        self.assertEqual(code, 1)
        self.assertEqual(out, "deploy not confirmed\n")
        self.assertNotIn("timed out", out)

    def test_wait_parse_error(self):
        code, out, _calls = run_body(200, "{")
        self.assertEqual(code, 1)
        self.assertEqual(out, "deploy not confirmed\n")

    def test_unconfirmed_deploy_exits_nonzero(self):
        code, out, _calls = run_body(200, preview(conclusion="timed_out"))
        self.assertNotEqual(code, 0)
        self.assertIn("deploy not confirmed", out)

    def test_http_401_exits_nonzero(self):
        code, out, calls = run_body(401, "{\"message\":\"bad credentials\"}")
        self.assertEqual(code, 1)
        self.assertEqual(len(calls), 1)
        self.assertNotIn("bad credentials", out)
        self.assertNotIn(TOKEN, out)

    def test_http_403_exits_nonzero(self):
        code, out, calls = run_body(403, "forbidden-body")
        self.assertEqual(code, 1)
        self.assertEqual(out, "deploy not confirmed\n")
        self.assertEqual(len(calls), 1)
        self.assertNotIn("forbidden-body", out)

    def test_429_is_red(self):
        code, out, calls = run_body(429, "slow down")
        self.assertEqual(code, 1)
        self.assertEqual(out, "deploy not confirmed\n")
        self.assertEqual(len(calls), 1)
        self.assertNotIn("slow down", out)

    def test_missing_token_is_red(self):
        code, out, calls = run_body(200, preview(), token=None)
        self.assertEqual(code, 1)
        self.assertEqual(out, "deploy not confirmed\n")
        self.assertEqual(calls, [])
        code, out, calls = run_body(200, preview(), token="")
        self.assertEqual(code, 1)
        self.assertEqual(calls, [])

    def test_authorization_header_only_to_api_github(self):
        code, out, calls = run_body(200, preview())
        self.assertEqual(code, 0)
        self.assertEqual(len(calls), 1)
        url, headers, _timeout = calls[0]
        self.assertEqual(url, URL)
        self.assertTrue(url.startswith("https://api.github.com/"))
        self.assertEqual(headers["Authorization"], f"Bearer {TOKEN}")
        self.assertEqual(headers["Accept"], "application/vnd.github+json")
        self.assertEqual(headers["X-GitHub-Api-Version"], "2022-11-28")
        self.assertNotIn(TOKEN, url)
        self.assertNotIn(TOKEN, out)
        host = url.split("/")[2]
        self.assertEqual(host, "api.github.com")

    def test_in_progress_then_success_sleeps_thirty(self):
        clock = Clock()
        bodies = [
            (200, preview(status="queued", conclusion=None)),
            (200, preview()),
        ]
        code, out, calls = run_body(200, bodies, timeout="900", clock=clock)
        self.assertEqual(code, 0)
        self.assertEqual(out, "deploy confirmed\n")
        self.assertEqual(clock.slept, [30])
        self.assertEqual(len(calls), 2)
        self.assertTrue(all(url.startswith("https://api.github.com/") for url, _headers, _timeout in calls))

    def test_other_app_does_not_count(self):
        clock = Clock()
        code, _out, calls = run_body(
            200,
            preview(slug="github-actions"),
            timeout="30",
            clock=clock,
        )
        self.assertEqual(code, 1)
        self.assertGreaterEqual(len(calls), 1)

    def test_real_http_get_refuses_other_hosts(self):
        with self.assertRaises(check.ParseError):
            check.real_http_get(
                "https://example.invalid/repos/a/b",
                {"Authorization": f"Bearer {TOKEN}"},
            )


if __name__ == "__main__":
    unittest.main()
