# MultiBlox — Roblox Multi-Instance Launcher
> **Use At Your Own Risk**
Lightweight PowerShell tool for running multiple Roblox clients on one Windows PC.

## How it works

`RobloxPlayerBeta.exe` enforces single-instance with two session-local named kernel
objects created at startup: mutex `ROBLOX_singletonMutex` and event
`ROBLOX_singletonEvent`. An `ERROR_ALREADY_EXISTS` from `CreateMutexW` only
*initiates* a hand-off to a live predecessor instance; with no live predecessor to
defer to (e.g. a third-party holder, or a crashed client's stale lock), the launch
falls through and the window opens normally.

This script pre-creates and owns those objects before Roblox starts, and keeps them
alive on a dedicated thread (ownership is thread-affine) for the whole session.

- No client files modified → low account risk (maybe)
- No handle closing of other processes → no admin required, no AV false positives
- Recover from abandoned (crashed-client) locks via `WAIT_ABANDONED`

## Usage

1. Run `MultiBlox.bat` (or `powershell -ExecutionPolicy Bypass -File MultiBlox.ps1`)
   **before** launching Roblox.
2. Keep the window open — launch Roblox from your browser repeatedly and log in
   with a different account in each window.
3. Close the window only when done. Closing it releases the lock and single
   instances return.

Options: `.\MultiBlox.ps1 -PlaceId 1818` (launch an experience directly),
`-JobId <guid>` (join a specific server).

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| "Lock is held by another live process" | Another tool (Bloxstrap tray, RAM) owns the lock | Close other holders and re-run |
| Second window opens then closes | Not a lock problem — auth ticket / expired cookie issue | Relaunch, check account validity |
| Worked earlier, not now | Holder window was closed or killed | Restart `MultiBlox.bat` before Roblox |

## Related open-source projects

Same technique, independent implementations (all cited in WHY-IT-WORKS.md):

- **Bloxstrap** (3.2k★, MIT) — [bloxstraplabs/bloxstrap](https://github.com/bloxstraplabs/bloxstrap): has a built-in "Allow multi-instance launching" toggle; no longer actively maintained.
- **Foolproof multi-instance integrations** — [Zgoly/bloxstrap-multi-instance-integration](https://github.com/Zgoly/bloxstrap-multi-instance-integration), [Zgoly/MultiBloxy](https://github.com/Zgoly/MultiBloxy)
- Minimalist classic — [ic3w0lf22/ROBLOX_MULTI](https://github.com/ic3w0lf22/ROBLOX_MULTI) (10 lines of C++ holding the same mutex)
