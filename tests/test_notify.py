"""Run: python3 tests/test_notify.py"""

from datetime import datetime
from importlib.machinery import SourceFileLoader
from pathlib import Path

notify = SourceFileLoader("notify", str(Path(__file__).parent.parent / "bin/docket-notify")).load_module()


def event(uid, start, all_day="False", calendar="c", alarms=()):
    return {"uid": uid, "title": uid, "start": start, "end": start, "all-day": all_day,
            "location": "", "calendar": calendar,
            "alarms-list": [{"delta": -minutes * 60.0} for minutes in alarms]}


def due_uids(events, now, notified=None):
    return [e["uid"] for _, _, e in notify.due(events, now, 10, notified or {}, {"f1"})]


now = datetime(2026, 11, 2, 9, 0)

# default lead for timed events without their own alerts; muted calendars and repeats skipped
events = [
    event("soon", "2026-11-02 09:10"),
    event("now", "2026-11-02 09:00"),
    event("later", "2026-11-02 09:11"),
    event("done", "2026-11-02 09:05"),
    event("race", "2026-11-02 09:05", calendar="f1"),
    event("started", "2026-11-02 08:59"),
]
assert due_uids(events, now, {"done|2026-11-02 09:05|10": "x"}) == ["soon", "now"]

# an event's own alerts replace the default: 1 h before is due, 10 min before is not
assert due_uids([event("own", "2026-11-02 09:30", alarms=[60])], now) == ["own"]
assert due_uids([event("own", "2026-11-02 09:05", alarms=[1440])], now) == ["own"]
assert due_uids([event("own", "2026-11-02 09:05", alarms=[0])], now) == []

# a day-before alert fires a day ahead; at 08:00 it is still an hour too early
tomorrow = event("tomorrow", "2026-11-03 09:00", alarms=[1440, 15])
assert due_uids([tomorrow], now) == ["tomorrow"]
assert due_uids([tomorrow], datetime(2026, 11, 2, 8, 0)) == []

# two alerts already past (after a suspend) make one notification and are both remembered
both = notify.due([event("both", "2026-11-02 09:20", alarms=[60, 30])], now, 10, {})
assert [keys for keys, _, _ in both] == [["both|2026-11-02 09:20|30", "both|2026-11-02 09:20|60"]]

# all-day events: 09:00 on the day by default, all day long until announced
birthday = event("birthday", "2026-11-02", all_day="True")
assert due_uids([birthday], datetime(2026, 11, 2, 8, 59)) == []
assert due_uids([birthday], now) == ["birthday"]
assert due_uids([birthday], datetime(2026, 11, 2, 23, 59)) == ["birthday"]
assert due_uids([birthday], now, {"birthday|2026-11-02|-540": "x"}) == []
# own alert on an all-day event: 15 h before midnight = 09:00 the day before
assert due_uids([event("eve", "2026-11-03", all_day="True", alarms=[900])], now) == ["eve"]

assert notify.until(datetime(2026, 11, 2, 9, 45), now) == "in 45 min"
assert notify.until(datetime(2026, 11, 3, 9, 0), now) == "in 24 h"
assert notify.until(datetime(2026, 11, 5, 9, 0), now) == "in 3 days"
print("ok")
