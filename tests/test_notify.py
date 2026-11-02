"""Run: python3 tests/test_notify.py"""

from datetime import datetime
from importlib.machinery import SourceFileLoader
from pathlib import Path

notify = SourceFileLoader("notify", str(Path(__file__).parent.parent / "bin/docket-notify")).load_module()


def event(uid, start, all_day="False", calendar="c"):
    return {"uid": uid, "title": uid, "start": start, "end": start, "all-day": all_day,
            "location": "", "calendar": calendar}


now = datetime(2026, 11, 2, 9, 0)
events = [
    event("soon", "2026-11-02 09:10"),
    event("now", "2026-11-02 09:00"),
    event("later", "2026-11-02 09:11"),
    event("allday", "2026-11-02", all_day="True"),
    event("done", "2026-11-02 09:05"),
    event("race", "2026-11-02 09:05", calendar="f1"),
]
keys = [key for key, _, _ in notify.due(events, now, 10, {"done|2026-11-02 09:05": "x"}, {"f1"})]
assert keys == ["soon|2026-11-02 09:10", "now|2026-11-02 09:00"], keys
print("ok")
