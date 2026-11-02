# Docket

Standalone calendar window (Quickshell) and reminder notifier for calendars synced by
vdirsyncer and read through khal. No accounts of its own: add or remove calendars in
`~/.config/vdirsyncer/config` and `~/.config/khal/config`.

- `docket [agenda|week|month]`: open the window, or raise it if it is already open.
  Keys: ←/→ move, `t` today, `a`/`w`/`m` views, `n` new event, `/` search, `r` sync.
  Double-click empty space in the week view to create an event at that hour.
  Meetings with a Meet/Zoom/Teams link get a Join button in the agenda and sidebar from
  15 minutes before until they end.
- Search (`/`, or `qs ipc -p qml call docket search "<text>"`) looks through titles, locations
  and notes of everything khal has, next occurrence first. It reads khal's cache database
  (`~/.cache/khal/khal.db`, layout version 5) directly, because `khal search` is too slow.
- Settings (toolbar button, or `qs ipc -p qml call docket settings [week|calendars|reminders]`):
  - Week view: hours shown in the grid.
  - Calendars: rename, hide, and color each calendar (theme palette, intense variant, or `#rrggbb`).
  - Reminders: lead time (off / 5 / 10 / 15 / 30 min) and which calendars notify.

  All saved to `~/.config/docket/config.json`, which can also be edited by hand:
  `dayStartHour`, `dayEndHour`, `calendarColors` and `calendarNames` (`{"<calendar id>": ...}`),
  `hiddenCalendars` and `reminderCalendarsOff` (lists of calendar ids), `reminderMinutes`.
- `docket-notify`: run every minute by `docket-notify.timer`. Notifies before timed events,
  using the Reminders settings from `config.json` (10 minutes, every calendar, if unset).
- `docket-helper`: the JSON bridge the window uses (`events`, `calendars`, `create`, `update`,
  `delete`, `search`, `sync`).

New events (optionally repeating daily/weekly/monthly/yearly, with notes) go through
`khal new`. Single events can be edited or deleted from their details popup: Docket rewrites
or removes the event's `.ics` file in `~/.calendars` (bumping `SEQUENCE`), after copying the
original to `~/.local/state/docket/backup/`. Every write then starts `vdirsyncer-sync.service`.
Repeating events, events crossing midnight and read-only calendars are not editable yet; use
Google Calendar or iCloud for those. Restore a change by copying its backup back into the
calendar folder and syncing.

Install: `./install` (symlinks into `~/.local/bin`, `~/.local/share/applications`,
`~/.config/systemd/user`, enables the timer).
Test: `python3 tests/test_notify.py`

`qml/CalendarModel.js` is copied from
[omarchy-caldav-calendar](https://github.com/SirWizardLizard/omarchy-caldav-calendar)
(MIT, Copyright (c) 2026 sirwizardlizard).
