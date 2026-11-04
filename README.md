# Kids Computer

Kids Computer is a full-screen launcher for a family Mac. When a child logs in to their own Standard account, the screen fills with big tiles for the activities a parent has allowed. There is no name on the greeting unless a parent types one. There is no default parent password.

Race Time, Typing Tutor, Math Quiz, Reading, and Drawing Helper are separate apps. Chess is the Chess app that comes with the Mac. A tile whose app is not installed yet stays on the home screen and says **Coming soon**. Tapping it shows a short message. It does not pop up an error. When that app is installed with the matching bundle id, the tile starts working. You do not rebuild the launcher for that.

This is a macOS 14 or later app. It is a direct download, not an App Store app. The desktop lock closes apps that are not on the list, and the App Store sandbox does not allow that.

## Download and install

The built app is an unsigned universal zip (Apple silicon and Intel) on GitHub Releases:

https://github.com/matjns/kids-computer/releases

1. Download `KidsComputer-mac-universal.zip`. The same release has `README-mac.txt`, which is the short version of these steps.
2. Unzip it and move **Kids Computer.app** to `/Applications`.
3. The first open is blocked by Gatekeeper, because the app is not signed with an Apple Developer ID. Right-click the app, choose **Open**, then **Open** again. Or go to System Settings → Privacy & Security and click **Open Anyway**.
4. If macOS says the app is damaged, open Terminal and run:

```bash
xattr -cr "/Applications/Kids Computer.app"
```

Then open the app again.

After that, follow [docs/SETUP.md](docs/SETUP.md). That guide is the click-by-click for the child's Standard account, Screen Time, opening the launcher at login, and the parent password. You do not need to know Swift to do it.

## The six starter tiles

| Order | Tile | Opens | Until it is installed |
| --- | --- | --- | --- |
| 1 | Race Time | `com.racetime.fsae` | Coming soon |
| 2 | Typing Tutor | `com.kidscomputer.typingtutor` | Coming soon |
| 3 | Chess | `com.apple.Chess` | Ready on a normal Mac |
| 4 | Math Quiz | `com.kidscomputer.mathquiz` | Coming soon |
| 5 | Reading | `com.kidscomputer.reading` | Coming soon |
| 6 | Drawing Helper | `com.kidscomputer.drawing` | Coming soon |

How to add another activity, and what each field in the tile list means, is in [docs/ADDING_APPS.md](docs/ADDING_APPS.md).

## Parent mode

Open parent mode with **Control-Option-Command-P** (hold Control, Option, and Command, then press P), or by tapping the small star in the top-left corner five times within four seconds. The first time, the launcher asks you to create a password. It stores a salted hash, not the password itself.

From there you can add, remove, and reorder tiles, set a daily limit, change the greeting, pause the desktop lock, install the login items, and quit.

If you forget the password while logged in as that user:

```bash
./scripts/reset-parent-password.sh
```

Or, if you only have the installed app:

```bash
"/Applications/Kids Computer.app/Contents/MacOS/KidsComputer" --reset-parent-password
```

## Build from source

You need a Mac with macOS 14 or later and Xcode 15 or later. Open Xcode once so it can finish setup.

```bash
./build.sh
```

That writes `build/Kids Computer.app` and `dist/KidsComputer-mac-universal.zip`. Copy the app to `/Applications`, then use the Gatekeeper steps above and [docs/SETUP.md](docs/SETUP.md). `./build.sh` is the build to use. Opening the raw `swift run` binary skips the app bundle, so the Dock lock and the login item will not behave.

The parts that decide what is allowed, how time limits work, and how the password is stored do not need a Mac. They live in `KidsComputerCore` and have unit tests. On a Mac, or on another computer that has Swift:

```bash
./build.sh test
```

GitHub Actions builds and runs those tests on a Mac for every push and pull request. A version tag such as `v1.0.0`, or a manual run of the workflow with a tag filled in, publishes the zip and `README-mac.txt` on the releases page.

## What the lock does and does not do

While Kids Computer is the front app, it asks macOS to hide the Dock and the menu bar, and to block Command-Tab, Force Quit, Hide, and logout. Inside Chess or Race Time those blocks do not stick. The watcher then closes anything that is not on the list, and the launcher comes back when the activity quits. Screen Time is the backstop for the web and for the times the launcher is not in front. [docs/SETUP.md](docs/SETUP.md) says that plainly.

Settings, usage, and the log for each Mac account live in `~/Library/Application Support/Kids Computer/`. The login watchdog, if you turn it on, is `~/Library/LaunchAgents/com.kidscomputer.launcher.plist`.

A Standard account, an administrator password the child does not know, and Screen Time matter more than this app. Someone with the administrator account can remove all of it.
