# Adding an app to Kids Computer

A tile is one big button on the home screen. Kids Computer does not contain the other apps. It opens them. If the app is not installed, the tile stays on the screen and says **Coming soon**. That is normal. It is not an error, and you do not need a new build of the launcher when the app shows up later.

## The six starter tiles

| Order | Tile | Bundle id | Path, if the id is not found |
| --- | --- | --- | --- |
| 1 | Race Time | `com.racetime.fsae` | `/Applications/RaceTime.app` |
| 2 | Typing Tutor | `com.kidscomputer.typingtutor` | none, until you install it |
| 3 | Chess | `com.apple.Chess` | `/System/Applications/Chess.app` |
| 4 | Math Quiz | `com.kidscomputer.mathquiz` | none, until you install it |
| 5 | Reading | `com.kidscomputer.reading` | none, until you install it |
| 6 | Drawing Helper | `com.kidscomputer.drawing` | none, until you install it |

Those bundle ids are the shared contract for this family of apps. Use them exactly.

- Race Time is the separate Electron app. Its Mac bundle id is `com.racetime.fsae`.
- Typing Tutor, Math Quiz, Reading, and Drawing Helper are separate Mac apps. Reading's own window may be titled Reading Quest. Drawing Helper's own window may be titled Draw With Me. The tile names above are what the child sees. The bundle id is what makes the tile open the app.
- Chess is the Chess app that comes with the Mac.

## What "Coming soon" means

On each refresh the launcher looks for the app in this order:

1. Ask macOS for the app with that bundle id. If it finds one, the tile is ready.
2. Otherwise, if the tile has an application path and that file exists, the tile is ready.
3. Otherwise the tile is **Coming soon**.

A Coming soon tile is still visible. Tapping it shows a short line such as "Typing Tutor is coming soon." It does not open an error window. When you install an app with the matching bundle id (usually by putting it in `/Applications` and getting past the first-open prompt), the tile wakes up on its own. Quit and reopen the launcher if you want to see it immediately. The launcher also checks again every couple of seconds.

Find a real bundle id with:

```bash
mdls -name kMDItemCFBundleIdentifier "/Applications/Some App.app"
```

The id in that output has to match the tile. A close-but-not-the-same id does not count. `com.kidscomputer.reading` does not match `com.kidscomputer.readinggame`.

## What the launcher allows to keep running

While the desktop lock is on, a normal app that is not a tile gets closed. Two extra cases stay open:

- A helper whose bundle id is the tile's id plus a dot and more. Race Time's Electron helpers look like `com.racetime.fsae.helper` and are allowed. You do not add them as their own tiles.
- A process whose files live inside the approved `.app` bundle.

Finder is hidden, not quit. macOS starts Finder again immediately, and quitting it in a loop flashes the desktop.

Do not add a web browser as a tile. A browser would be allowed to stay open, including sites you do not want. Use Screen Time for the web. The setup guide says how.

## Where the list is stored

The launcher writes this file the first time it runs for that Mac account:

```text
~/Library/Application Support/Kids Computer/tiles.json
```

It does not overwrite your edits after that. Quit the launcher before you change the file by hand. A file it cannot read is left in place, and the home screen says a parent needs to fix it.

The parent password is a salted hash in that file and in the Keychain. The Keychain item uses the service name `com.kidscomputer.launcher`. The password text is never stored. Leave the hash alone unless you are resetting it with the script in the setup guide.

Usage for the local day is `usage.json` in the same folder. The log is `launcher.log`. Pictures you pick in parent settings are copied into the `icons` folder next to `tiles.json`.

## Add a tile in parent settings

Press **Control-Option-Command-P**, or tap the small star in the top-left corner five times within four seconds. Create the parent password the first time. There is no default.

**Add an activity** asks for:

- **Name.** What the child sees on the button.
- **Short description.** The smaller line under the name. You can leave it blank.
- **Bundle id.** The best way to point at an app. Example: `com.kidscomputer.mathquiz`.
- **Application path.** Optional. Use it as a fallback, or when you want a specific `.app` file. Browse starts in `/Applications`.
- **Daily time limit.** Off means no limit. On means that many minutes for the local day. At midnight the tile works again. Sleep time is not counted.
- **Show this activity.** Off hides the tile.
- **Color.** One of orange, teal, purple, blue, green, pink, yellow, red. Yellow uses dark text.
- **Fallback symbol.** An SF Symbol name, such as `book.fill`, used when the app icon is not available.
- **Picture.** Optional. If you choose one, it is copied into the `icons` folder and shown instead of the app icon.

Every tile needs a name and an id. The id is filled in from the name (letters, numbers, and dashes). Two tiles cannot share an id. Every tile needs a bundle id or an application path, or both.

**Restore the starter activities** puts the six tiles in the table above back. The previous list is saved as `tiles.json.bak`. The greeting and the parent password stay.

## Or edit tiles.json

Quit Kids Computer, then edit the file. `examples/tiles.json` is a copy of the starter list. A tile looks like this:

```json
{
  "id": "math-quiz",
  "title": "Math Quiz",
  "subtitle": "Numbers and puzzles",
  "bundleIdentifier": "com.kidscomputer.mathquiz",
  "accent": "blue",
  "enabled": true,
  "symbolName": "function"
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | Unique id. Lowercase letters, numbers, and dashes are the usual shape. |
| `title` | yes | The name on the button. |
| `subtitle` | no | Smaller line under the name. |
| `bundleIdentifier` | one of these two | Bundle id macOS uses to find the app. |
| `applicationPath` | one of these two | Full path to an `.app`, such as `/Applications/Math Quiz.app`. |
| `dailyLimitMinutes` | no | Whole minutes for the local day. Leave it out, or use 0, for no limit. |
| `accent` | no | `orange`, `teal`, `purple`, `blue`, `green`, `pink`, `yellow`, or `red`. Defaults to blue. |
| `enabled` | no | `false` hides the tile. Defaults to true. |
| `symbolName` | no | SF Symbol used when there is no app icon. Defaults to `sparkles`. |
| `customIconPath` | no | A picture on disk. Parent settings fills this in for you. |

The file can also set:

- `greetingName`. Leave it as `""` and the home screen does not use a name. The launcher never fills this in.
- `kioskEnabled`. `true` keeps the desktop lock on.
- `warnBeforeMinutes`. How early the beep and the note appear before a daily limit runs out. The default is 5.
- `extraProtectedBundleIDs`. One bundle id per entry, for a system app the lock closed and should not have. End an entry with `.*` to allow a family of ids.

Save the file, then open Kids Computer again.

## What you do not need to do

- You do not rebuild Kids Computer when you install Typing Tutor, Math Quiz, Reading, or Drawing Helper.
- You do not put a child's name in the app, the tile list, or this repo. A greeting name is optional and blank until a parent types one on that Mac.
- You do not sandbox this launcher. The desktop lock closes other apps, which the App Store does not allow. Ship it as the unsigned zip from GitHub Releases.
