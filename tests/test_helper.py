"""Run: python3 tests/test_helper.py

Drives bin/docket-helper (and the real khal) against a throwaway calendar folder.
"""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

HELPER = Path(__file__).parent.parent / "bin/docket-helper"

WEEKLY = """BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//test//EN
BEGIN:VEVENT
UID:weekly
SUMMARY:Standup
DTSTART;TZID=America/Toronto:20261102T100000
DTEND;TZID=America/Toronto:20261102T110000
RRULE:FREQ=WEEKLY;COUNT=4
END:VEVENT
END:VCALENDAR
"""

MEETING = """BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//test//EN
BEGIN:VEVENT
UID:meeting
SUMMARY:Review
DTSTART;TZID=America/Toronto:20261105T150000
DTEND;TZID=America/Toronto:20261105T160000
ORGANIZER;CN=Ana Example:mailto:ana@example.com
ATTENDEE;CN=Bo Example;PARTSTAT=ACCEPTED:mailto:bo@example.com
ATTENDEE;PARTSTAT=NEEDS-ACTION:mailto:cy@example.com
END:VEVENT
END:VCALENDAR
"""

BERLIN = """BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//test//EN
BEGIN:VEVENT
UID:berlin
SUMMARY:Call
DTSTART;TZID=Europe/Berlin:20261104T160000
DTEND;TZID=Europe/Berlin:20261104T170000
END:VEVENT
END:VCALENDAR
"""

CONFIG = """[calendars]
[[test]]
path = {root}/account/test
type = calendar
[[other]]
path = {root}/account/other
type = calendar
[sqlite]
path = {root}/khal.db
[locale]
local_timezone = America/Toronto
default_timezone = America/Toronto
timeformat = %H:%M
dateformat = %Y-%m-%d
longdateformat = %Y-%m-%d
datetimeformat = %Y-%m-%d %H:%M
longdatetimeformat = %Y-%m-%d %H:%M
"""


class HelperTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        root = Path(self.dir.name)
        folder = root / "account/test"
        folder.mkdir(parents=True)
        (root / "account/other").mkdir()
        (folder / "weekly.ics").write_text(WEEKLY)
        (folder / "berlin.ics").write_text(BERLIN)
        (folder / "meeting.ics").write_text(MEETING)
        (root / "khal.conf").write_text(CONFIG.format(root=root))
        self.env = {**os.environ, "TZ": "America/Toronto", "XDG_STATE_HOME": str(root / "state"),
                    "DOCKET_KHAL_CONFIG": str(root / "khal.conf"), "DOCKET_CALENDAR_ROOT": str(root)}

    def tearDown(self):
        self.dir.cleanup()

    def run_helper(self, *args):
        result = subprocess.run([str(HELPER), *args], capture_output=True, text=True, env=self.env)
        return json.loads(result.stdout)

    def write(self, command, **fields):
        return self.run_helper(command, json.dumps({"calendar": "test", **fields}))

    def listed(self, uid="weekly", calendar="test"):
        events = self.run_helper("events", "2026-11-01", "2026-12-01")["events"]
        return sorted((e["start"][:16], e["title"]) for e in events
                      if e["uid"] == uid and e["calendarId"] == calendar)

    def edit(self, scope, occurrence, start, end, title):
        return self.write("update", uid="weekly", scope=scope, occurrence=occurrence, title=title,
                          allDay=False, start=start, end=end)

    def test_delete_one_occurrence(self):
        self.assertTrue(self.write("delete", uid="weekly", scope="this",
                                   occurrence="2026-11-09T10:00:00-05:00")["ok"])
        self.assertEqual([s for s, _ in self.listed()],
                         ["2026-11-02T10:00", "2026-11-16T10:00", "2026-11-23T10:00"])

    def test_edit_one_occurrence_twice(self):
        self.assertTrue(self.edit("this", "2026-11-16T10:00:00-05:00",
                                  "2026-11-16T14:00", "2026-11-16T15:00", "Moved")["ok"])
        # the moved occurrence is now shown at 14:00; editing it again changes the same exception
        self.assertTrue(self.edit("this", "2026-11-16T14:00:00-05:00",
                                  "2026-11-16T15:00", "2026-11-16T16:00", "Moved again")["ok"])
        self.assertEqual(self.listed(), [("2026-11-02T10:00", "Standup"),
                                         ("2026-11-09T10:00", "Standup"),
                                         ("2026-11-16T15:00", "Moved again"),
                                         ("2026-11-23T10:00", "Standup")])
        text = (Path(self.dir.name) / "account/test/weekly.ics").read_text()
        self.assertEqual(text.count("BEGIN:VEVENT"), 2)

    def test_edit_series_keeps_exceptions(self):
        self.write("delete", uid="weekly", scope="this", occurrence="2026-11-09T10:00:00-05:00")
        self.edit("this", "2026-11-16T10:00:00-05:00", "2026-11-16T14:00", "2026-11-16T15:00", "Moved")
        # edited from the third occurrence: every occurrence moves 30 minutes earlier
        result = self.edit("all", "2026-11-23T10:00:00-05:00",
                           "2026-11-23T09:30", "2026-11-23T10:00", "Series")
        self.assertTrue(result["ok"], result)
        self.assertEqual(self.listed(), [("2026-11-02T09:30", "Series"),
                                         ("2026-11-16T14:00", "Moved"),
                                         ("2026-11-23T09:30", "Series")])

    def test_edit_series_from_a_moved_occurrence(self):
        self.edit("this", "2026-11-16T10:00:00-05:00", "2026-11-16T11:00", "2026-11-16T11:30", "Standup")
        # the form shows the moved occurrence's 11:00-11:30; only the title changes
        result = self.edit("all", "2026-11-16T11:00:00-05:00",
                           "2026-11-16T11:00", "2026-11-16T11:30", "Daily")
        self.assertTrue(result["ok"], result)
        self.assertEqual(self.listed(), [("2026-11-02T10:00", "Daily"),
                                         ("2026-11-09T10:00", "Daily"),
                                         ("2026-11-16T11:00", "Daily"),
                                         ("2026-11-23T10:00", "Daily")])
        ends = [e["end"][11:16] for e in self.run_helper("events", "2026-11-01", "2026-12-01")["events"]
                if e["uid"] == "weekly"]
        self.assertEqual(ends, ["11:00", "11:00", "11:30", "11:00"])

    def test_series_cannot_move_to_another_day(self):
        result = self.edit("all", "2026-11-02T10:00:00-05:00",
                           "2026-11-03T10:00", "2026-11-03T11:00", "Standup")
        self.assertFalse(result["ok"])
        self.assertIn("another day", result["error"])

    def test_repeating_needs_a_scope(self):
        self.assertFalse(self.write("delete", uid="weekly")["ok"])
        self.assertFalse(self.edit("", "2026-11-02T10:00:00-05:00",
                                   "2026-11-02T10:00", "2026-11-02T11:00", "Standup")["ok"])
        self.assertEqual(len(self.listed()), 4)

    def test_repeating_cannot_become_all_day(self):
        result = self.write("update", uid="weekly", scope="this", title="x", allDay=True,
                            occurrence="2026-11-02T10:00:00-05:00",
                            start="2026-11-02", end="2026-11-02")
        self.assertFalse(result["ok"])

    def test_delete_series(self):
        self.assertTrue(self.write("delete", uid="weekly", scope="all")["ok"])
        self.assertEqual(self.listed(), [])
        self.assertEqual(len(list((Path(self.dir.name) / "state/docket/backup").iterdir())), 1)

    def test_single_event_in_other_zone_keeps_local_time(self):
        # 16:00 Berlin is 10:00 here; the form's 12:00 is local time, not Berlin time
        result = self.write("update", uid="berlin", title="Call", allDay=False,
                            start="2026-11-04T12:00", end="2026-11-04T13:00")
        self.assertTrue(result["ok"], result)
        self.assertEqual(self.listed("berlin"), [("2026-11-04T12:00", "Call")])
        self.assertIn("TZID=Europe/Berlin:20261104T180000",
                      (Path(self.dir.name) / "account/test/berlin.ics").read_text())

    def test_move_to_another_calendar(self):
        result = self.write("update", uid="berlin", title="Call", allDay=False, moveTo="other",
                            start="2026-11-04T10:00", end="2026-11-04T11:00")
        self.assertTrue(result["ok"], result)
        self.assertEqual(self.listed("berlin"), [])
        self.assertEqual(self.listed("berlin", "other"), [("2026-11-04T10:00", "Call")])
        self.assertFalse((Path(self.dir.name) / "account/test/berlin.ics").exists())

    def test_move_whole_series_only(self):
        args = dict(uid="weekly", title="Standup", allDay=False, moveTo="other",
                    occurrence="2026-11-02T10:00:00-05:00",
                    start="2026-11-02T10:00", end="2026-11-02T11:00")
        self.assertFalse(self.write("update", scope="this", **args)["ok"])
        self.assertEqual(len(self.listed()), 4)
        self.assertTrue(self.write("update", scope="all", **args)["ok"])
        self.assertEqual(len(self.listed("weekly", "other")), 4)

    def test_invitations_do_not_move(self):
        result = self.write("update", uid="meeting", title="Review", allDay=False, moveTo="other",
                            start="2026-11-05T15:00", end="2026-11-05T16:00")
        self.assertFalse(result["ok"])
        self.assertIn("Invitations", result["error"])
        self.assertEqual(self.listed("meeting"), [("2026-11-05T15:00", "Review")])

    def test_people(self):
        found = self.run_helper("people", "test", "meeting")
        self.assertEqual(found["organizer"], {"name": "Ana Example", "email": "ana@example.com",
                                              "status": ""})
        self.assertEqual(found["attendees"], [
            {"name": "Bo Example", "email": "bo@example.com", "status": "accepted"},
            {"name": "", "email": "cy@example.com", "status": "needs-action"}])
        self.assertEqual(self.run_helper("people", "test", "weekly"),
                         {"ok": True, "organizer": None, "attendees": []})
        self.assertFalse(self.run_helper("people", "test", "missing")["ok"])

    def test_search_reads_the_configured_database(self):
        self.listed()  # any khal command fills the database
        found = self.run_helper("search", "review")
        self.assertTrue(found["ok"], found)
        self.assertEqual([e["uid"] for e in found["events"]], ["meeting"])

    def test_unwritable_calendar_is_an_error_not_a_crash(self):
        folder = Path(self.dir.name) / "account/test"
        folder.chmod(0o555)
        try:
            result = self.edit("this", "2026-11-09T10:00:00-05:00",
                               "2026-11-09T11:00", "2026-11-09T12:00", "Standup")
        finally:
            folder.chmod(0o755)
        self.assertFalse(result["ok"])
        self.assertIn("Permission denied", result["error"])

    def fake_systemctl(self, exit_code):
        """PATH with a systemctl that logs its arguments; no khal config, so the helper syncs."""
        bin_dir = Path(self.dir.name) / "fakebin"
        bin_dir.mkdir(exist_ok=True)
        log = Path(self.dir.name) / "systemctl.log"
        script = bin_dir / "systemctl"
        script.write_text(f'#!/bin/sh\necho "$*" >> {log}\nexit {exit_code}\n')
        script.chmod(0o755)
        env = {k: v for k, v in self.env.items() if k != "DOCKET_KHAL_CONFIG"}
        env["PATH"] = f"{bin_dir}:{os.environ['PATH']}"
        return env, log

    def test_sync_runs_twice(self):
        # Google rewrites what it's sent; the second pass fetches that copy right away
        env, log = self.fake_systemctl(0)
        result = subprocess.run([str(HELPER), "sync"], capture_output=True, text=True, env=env)
        self.assertTrue(json.loads(result.stdout)["ok"], result.stdout)
        self.assertEqual(log.read_text().splitlines(), ["--user start vdirsyncer-sync.service"] * 2)

    def test_sync_failure_is_reported(self):
        env, log = self.fake_systemctl(1)
        result = subprocess.run([str(HELPER), "sync"], capture_output=True, text=True, env=env)
        self.assertFalse(json.loads(result.stdout)["ok"])
        self.assertEqual(len(log.read_text().splitlines()), 1)


if __name__ == "__main__":
    unittest.main()
