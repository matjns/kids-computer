# Set up Kids Computer

This is the click-by-click setup for a family Mac. You do not need to know Swift. You do need an administrator account for yourself, and a separate Standard account for the child. The steps below say "the child" on purpose. The launcher does not show a name unless you type one.

Kids Computer is not an App Store app. Closing other apps is not allowed inside the App Sandbox, so this build is a direct download. macOS will ask you to confirm the first open. That is expected.

The easiest copy is the universal zip on [GitHub Releases](https://github.com/matjns/kids-computer/releases): `KidsComputer-mac-universal.zip`, plus `README-mac.txt` in the same release. Unzip it, move **Kids Computer** to `/Applications`, and if macOS blocks it, use the Open Anyway steps in section 1. Building from source is the second half of that section.

Plan on doing the Mac account and Screen Time steps from your administrator account first, then logging in as the child once to set the parent password and the login item.

## What you are turning on

The launcher fills the screen with six tiles:

1. **Race Time**, the Electron racing game, if `RaceTime.app` is in `/Applications`
2. **Typing Tutor**
3. **Chess** (the Chess app that comes with the Mac)
4. **Math Quiz**
5. **Reading**
6. **Drawing Helper**

Typing Tutor, Math Quiz, Reading, and Drawing Helper are not built yet. Their tiles say **Coming soon**. Tapping one shows a short message. It does not pop up an error. When you later install an app with the matching bundle id, that tile starts working without a new build of the launcher.

Chess should be ready immediately. Race Time is ready after you install that app.

## What the launcher cannot do by itself

Read this before you rely on it.

- The Dock, menu bar, Command-Tab, Force Quit, and logout blocks apply while the launcher is the front app. They do not stick while Chess or Race Time is in front. Command-Tab from inside a game can flash another app. The launcher then closes apps that are not on the list and comes back.
- YouTube in Safari is not on the list, so the launcher tries to close Safari. That is not a web filter. A site inside an app you approved would still load. Do not put a browser on the tile list. Use Screen Time's web limits as well.
- A full-screen game can cover the "five minutes left" note. The Mac beeps, and the launcher still closes the game when the time is used up.
- Finder is hidden, not quit. macOS starts Finder again the moment it is quit, and quitting it in a loop flashes the desktop.
- Tiny background helpers are left alone. A normal app the child launches is not. Do not install extra menu-bar apps on the child's account.
- If you quit the launcher from parent mode, the desktop is available until the next login. The crash watchdog does not restart a deliberate quit.
- The parent password stops a child who does not know it. It does not stop an administrator. The file `tiles.json` holds a hash, not the password. Someone who can edit that account's files and the Keychain can clear it. The Standard account and the Screen Time passcode are the real fence.
- Safe mode, Recovery, and your own administrator account can bypass the launcher. That is normal. Do not share your administrator password.

Screen Time is the part macOS enforces even when this app is not the front window. Set it up. Do not skip it.

## 1. Put the app on the Mac

You need macOS 14 Sonoma or anything newer.

### Download a built app

1. Open [the releases page](https://github.com/matjns/kids-computer/releases) and download `KidsComputer-mac-universal.zip`.
2. Unzip it. You get **Kids Computer.app** and a short `README-mac.txt`.
3. Move **Kids Computer.app** to `/Applications`. Finder is enough.

The zip is unsigned. macOS checks apps that came from the internet, so the first open can say the app is from an unidentified developer, or that it is damaged.

1. Right-click the app and choose **Open**, then **Open** again. Or open System Settings → Privacy & Security and click **Open Anyway**.
2. If it still says damaged, run this once in Terminal:

```bash
xattr -cr "/Applications/Kids Computer.app"
```

Then open the app again.

### Or build it yourself

You only need this if you are changing the launcher. Install Xcode 15 or newer from the App Store, open Xcode once so it can finish setup, and if Terminal says `swift` is missing, run `xcode-select --install`.

```bash
cd /path/to/this/project
./build.sh
```

That compiles a universal app (Apple silicon and Intel) and writes:

```text
build/Kids Computer.app
dist/KidsComputer-mac-universal.zip
```

Copy `build/Kids Computer.app` to `/Applications`. The same Open Anyway steps apply. `./build.sh` is the build to use. Opening the raw `swift run` binary skips the app bundle, so the Dock lock and the login item will not behave.

Check the logic tests if you want. This command also works on a computer that is not a Mac, as long as Swift is installed:

```bash
./build.sh test
```

Replacing the app in `/Applications` can make an old Keychain item unreadable. The copy of the password hash in `tiles.json` still works. You can also reset the password with the script in step 6.

## 2. Install Race Time

Race Time is a separate app. Its Mac build is `RaceTime.app`, and the bundle id in that project's `build.sh` is `com.racetime.fsae`.

1. Put `RaceTime.app` in `/Applications`.
2. Open it once from your account and get past the Gatekeeper prompt, the same way as the launcher.
3. Confirm the id:

```bash
mdls -name kMDItemCFBundleIdentifier /Applications/RaceTime.app
```

You want `com.racetime.fsae`. If you later change Race Time's `--app-bundle-id`, edit the Race Time tile so the bundle id matches. The path `/Applications/RaceTime.app` is the fallback when the id is not found.

Helpers inside Race Time (the Electron GPU and renderer processes) are allowed automatically. You do not add them as tiles.

## 3. Make the child's account a Standard account

Stay logged in as the administrator.

1. System Settings → Users & Groups.
2. If the padlock or the Add Account button is locked, unlock it with your administrator password.
3. Add Account. Set New Account to **Standard**, not Administrator.
4. Pick a name and a password the child can use. Do not reuse your administrator password.
5. Create the user.
6. Check the list. The new user must say Standard.
7. Set Automatic login to **Off**. You do not want the Mac to boot straight into your administrator session, and you do not have to turn on automatic login for the child either. The launcher starts when that account logs in.

Turn Guest off:

1. System Settings → Users & Groups → Guest User.
2. Turn off **Allow guests to log in to this computer**.

Hide Fast User Switching so the child cannot flip to your account from the menu bar without logging out:

1. System Settings → Control Center.
2. Fast User Switching → show it nowhere (menu bar off, Control Center off).

The login window still lets you log in as yourself after the child logs out. While the launcher is the front app it asks macOS to block logout. That request is dropped while a game is the front app, which is one reason the child must not know your password.

## 4. Screen Time

Still on the administrator account: System Settings → Screen Time. If there is a family member menu, choose the child. Turn Screen Time on for that user.

The names below match macOS Sonoma and Sequoia. Newer macOS keeps the same controls under Screen Time, sometimes with slightly different labels.

### Passcode

Choose **Use Screen Time Passcode** (or Lock Screen Time Settings). Use a code the child does not know. It is separate from the Mac login password and from the launcher's parent password. Write it down somewhere the child does not look.

### Always Allowed

Downtime and App Limits can quit apps. If they quit the launcher, the desktop shows up.

Put **Kids Computer** in Always Allowed. Also allow the activities you want usable during Downtime: Race Time, Chess, and later the other learning apps. Do not always-allow Safari or YouTube.

### Downtime

Turn Downtime on and set a bedtime, for example 8:00 PM to 7:00 AM. Turn on **Block at Downtime** so only Always Allowed apps open. The launcher should be one of those, so the child still lands in the launcher instead of an empty desktop.

### App Limits

Add a short limit for Safari, and for the YouTube app if it is installed. This is a backup for the moments when the launcher is not the front app. Do not put an App Limit on the launcher itself.

macOS Screen Time is not an iPhone-style "only these apps exist" list. App Limits and web limits are the useful pieces. The launcher is what hides the rest of the desktop.

### Web content, including YouTube

1. Content & Privacy → turn it on.
2. Content Restrictions → Web Content → **Limit Adult Websites**.
3. Under Never Allow, add:

   - `youtube.com`
   - `www.youtube.com`
   - `m.youtube.com`
   - `youtu.be`
   - `music.youtube.com`
   - `youtube-nocookie.com`

4. Add `youtubekids.com` as well if you do not want YouTube Kids either.

That is the part that still applies inside a browser if the launcher misses it. Content & Privacy on the Mac does not remove Safari the way an iPhone allow-list can. Combine it with the App Limit and with the launcher closing Safari.

## 5. First login as the child

Log out of your account. Log in as the child. Open **Kids Computer** from `/Applications` if it does not open itself. The first launch is before the login item exists, so you may see the desktop for a moment. Open the app yourself that once.

You should see the six tiles, a greeting with no name ("Good morning", "Good afternoon", "Good evening", or "Hello"), and the line "What do you want to do?" Chess looks ready. The apps that are not installed say Coming soon. Race Time says Coming soon until `RaceTime.app` is in `/Applications`.

### Create the parent password

There is no default password, and the screen never shows the key combination.

Press **Control-Option-Command-P** together (hold Control, Option, and Command, then press P). Option is the Alt key. Command is the ⌘ key.

You can also tap the small gold star in the top-left corner five times within four seconds.

The first time, the launcher asks you to create the parent password. Use at least 4 characters. Longer is better. Pick something the child will not guess. It is saved as a salted hash in the Keychain and in the settings file. The password text is not saved.

After that, the same keys ask for the password and then open parent settings.

If a game is already in front, Command-Q quits that game (the launcher cannot swallow that key while the game is active). You land back on the launcher, and then the key combination works. A beep and a note also appear over a game when a time limit is close. Check that on the real Mac; a full-screen game can cover the note.

### Make it open at login

In parent settings, under **Open at login**:

1. Click **Open at login**. This uses macOS's login-item API (`SMAppService`). It applies only to the account you are logged in as.
2. Click **Reopen if it crashes**. This installs a LaunchAgent for this account. A crash starts the launcher again. A quit from parent mode does not.
3. If the status says macOS wants approval, click **Allow it in Settings**. The desktop lock pauses for a few minutes so System Settings is not closed underneath you. Approve **Kids Computer** under System Settings → General → Login Items & Extensions. Then turn the desktop lock back on if you had switched it off. The pause ends on its own after five minutes.

Do these clicks while logged in as the child. Doing them on your administrator account would start the launcher for you, not for the child.

The same LaunchAgent can be installed from Terminal, still as the child:

```bash
./scripts/install-launch-agent.sh
```

Remove it, as the child, with:

```bash
./scripts/uninstall-launch-agent.sh
```

Log out and log back in as the child. The launcher should fill the screen without a trip through the desktop. If it does not, check Login Items for that user, and check that the app is still in `/Applications`.

The plist lives at `~/Library/LaunchAgents/com.kidscomputer.launcher.plist`. `KeepAlive` is set so a successful quit stays quit, and a crash starts again after about 10 seconds.

## 6. Parent settings

Control-Option-Command-P, then the password.

- **Greeting.** Type a name if you want "Good morning, Sam". Leave it blank and no name is shown. The launcher never fills this in for you.
- **Home screen look.** **Let the child customize the look** is on by default. It shows a **Make it mine** button on the home screen where the child picks a background color, a faint pattern, and tile colors. It changes colors only, never activities, limits, the lock, or files, and it doesn't need the password. Turn it off to hide the button. **Reset look** puts the original look back.
- **Desktop lock.** Leave this on. Turn it off while you install an app or change System Settings, then turn it on again. While it is off, a banner on the home screen says the lock is paused.
- **Warn minutes.** Default is 5. The Mac beeps and shows a note that many minutes before a daily limit runs out.
- **Activities.** Up and Down change the order. Edit changes the name, the bundle id, the path, the color, the picture, and the daily limit. Remove deletes a tile. Add an activity makes a new one. Restore the starter activities puts the six tiles back and saves the old file as `tiles.json.bak`. The greeting and the password stay.
- **Today.** Minutes counted for each tile since local midnight. Sleep time is not counted.
- **Change the parent password.** Sets a new hash.
- **Apps the lock should ignore.** One bundle id per line, for a system app the lock closed and should not have. End a line with `.*` to allow a family of ids, for example `com.example.tools.*`. The log names anything that was closed.
- **Quit the launcher.** Asks first. The desktop comes back until the next login.

Daily limits are optional. The starter tiles have no limit until you set one. A limit is for that local day. At midnight the tile works again. The child gets a warning, then the app closes and the tile goes grey and says "See you tomorrow."

Numbers 1 through 6 on the keyboard open the first six visible tiles. That is handy while you are testing.

### If you forget the password

Log in as the child (or use Terminal as that user) and run:

```bash
"/Applications/Kids Computer.app/Contents/MacOS/KidsComputer" --reset-parent-password
```

Or, from this project:

```bash
./scripts/reset-parent-password.sh
```

The next Control-Option-Command-P asks you to create a new password. This clears both the Keychain item and `parentPasswordHash` in `tiles.json`.

## 7. Add an activity

The field-by-field rules, the six starter bundle ids, and what "Coming soon" means are in [ADDING_APPS.md](ADDING_APPS.md). Short version: you can do this in parent settings, or by editing the file while the launcher is quit.

The file is:

```text
~/Library/Application Support/Kids Computer/tiles.json
```

A tile needs a `title` and an `id`, plus a `bundleIdentifier` or an `applicationPath` (or both). `dailyLimitMinutes` is optional. Leave it out for no limit. `enabled` set to false hides the tile. `accent` is one of `orange`, `teal`, `purple`, `blue`, `green`, `pink`, `yellow`, `red`. `symbolName` is an SF Symbol used when the app's own icon is not available. `customIconPath` is optional. Parent settings copies a picture you pick into the `icons` folder next to `tiles.json`.

Find a bundle id with:

```bash
mdls -name kMDItemCFBundleIdentifier "/Applications/Some App.app"
```

The four apps that are not built yet already have ids:

| App | Bundle id |
| --- | --- |
| Typing Tutor | `com.kidscomputer.typingtutor` |
| Math Quiz | `com.kidscomputer.mathquiz` |
| Reading | `com.kidscomputer.reading` |
| Drawing Helper | `com.kidscomputer.drawing` |

Build those apps with those ids, install them, and the Coming soon tiles become buttons. You can also point a tile at a path if the id is different.

`examples/tiles.json` is a copy of the starter list. The launcher writes its own file on first launch and does not overwrite your edits after that. A broken `tiles.json` is left in place and the home screen says a parent needs to fix it. Restoring the starter list saves the broken file as `tiles.json.bak`.

Usage is in `usage.json` beside it. The log is `launcher.log`. If the lock closes something it should not, the log has the app's name and bundle id. Add that id to the ignore list.

## 8. Check it on the Mac

This project was written on a machine that cannot compile AppKit. `./build.sh test` checks the logic. The following still has to be tried on the Mac. Do it before the child uses the account alone.

- The release zip or `./build.sh` produces **Kids Computer.app**, and it opens on macOS 14 or newer. `lipo -info` on the binary inside the app lists both `arm64` and `x86_64`.
- Gatekeeper: first open, Open Anyway, and `xattr -cr` if macOS calls it damaged.
- The window covers the whole screen, including a second display if you have one. The Dock and menu bar are gone while the launcher is in front.
- Command-Tab, Command-Option-Escape, Command-H, Command-W, and Command-Q do nothing on the launcher. Logout from the Apple menu is unavailable there too.
- The greeting has no name until you set one. None of the tiles say the child's name.
- Chess opens and, when you quit Chess, the launcher comes back to the front.
- Race Time opens from its tile, its icon shows on the tile, and its helper processes are not closed while it runs. Quit Race Time and the launcher returns.
- Typing Tutor, Math Quiz, Reading, and Drawing Helper say Coming soon and do not show an error. Install a dummy app with one of those bundle ids and confirm the tile wakes up.
- From inside Chess, Command-Tab toward Safari. Safari should be closed and the launcher, or Chess, should come back. Expect a short flash. This is the important YouTube case.
- Finder, if it comes forward, is hidden and the launcher returns. It should not be a quit-and-relaunch loop. Watch `launcher.log`.
- Set a 1 minute limit on Chess, leave the warning at 1 minute, and open Chess. You should get one warning, then Chess closes and the tile stays grey until tomorrow. Quit the launcher, open it again, and the tile is still grey. The minutes in parent settings survive the restart.
- Sleep the Mac for a minute during a timed app. That minute should not be added as play time.
- Create the parent password. Quit parent mode. The key combination asks for it. A wrong password does not open settings. Reset with the script and create a new one.
- Five taps on the star also opens parent mode.
- Turn the desktop lock off, open System Settings, turn the lock on, and confirm System Settings is closed.
- As the child, turn on Open at login and the crash watchdog. Log out and back in. The launcher should be there. Force-quit the launcher from your administrator tools, or `kill -9` its process, and it should come back. Quit from parent mode and it should stay quit.
- If Login Items says the item needs approval, approve it while the lock is paused.
- Screen Time: YouTube does not load in Safari, Downtime blocks a non-allowed app, and the launcher itself still opens during Downtime because it is Always Allowed.
- Guest login is off. Fast User Switching is hidden. The child's account is Standard. Your account is still an administrator.

## If something looks wrong

| What you see | What to try |
| --- | --- |
| The desktop is visible | The launcher is not running, or the lock is paused. Open the app, or log out and back in. Read `launcher.log`. |
| macOS closed a system window the child needs | Copy the bundle id from `launcher.log` into **Apps the lock should ignore**, or turn the lock off while you deal with it. |
| Login item does nothing | The app must live in `/Applications` as a real `.app` from `./build.sh`. Approve it in Login Items. Install the LaunchAgent as the child, not as you. |
| The launcher opens twice | It should notice the second copy and exit. If both stay, check for two LaunchAgents or a login item plus a copy you started by hand. The second one exits with a normal status so the watchdog does not fight itself. |
| Password always fails after you replace the app | Run the reset script as the child. A new copy of the app can orphan the Keychain item. The hash in `tiles.json` is the backup, and the reset clears both. |
| A tile stays on Coming soon | The app is not installed, or the bundle id does not match. `mdls -name kMDItemCFBundleIdentifier` on the `.app` is the source of truth. |
| You need the desktop yourself | Log in to your administrator account. The launcher is not a login item there unless you installed it while logged in as yourself. |
