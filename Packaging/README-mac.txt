Kids Computer
=============

This is the full-screen launcher for a family Mac. The zip is an unsigned
universal app (Apple silicon and Intel) for macOS 14 or later.

Install
-------

1. Unzip KidsComputer-mac-universal.zip.
2. Move "Kids Computer.app" to /Applications.
3. The first time you open it, macOS may say it is from an unidentified
   developer, or that it is damaged. That is Gatekeeper. This app is not
   signed with an Apple Developer ID, and it is not on the App Store.

   Right-click the app, choose Open, then Open again.

   Or open System Settings, go to Privacy & Security, and click Open Anyway.

4. If macOS still says the app is damaged, open Terminal and run:

   xattr -cr "/Applications/Kids Computer.app"

   Then open the app again.

Next
----

The full setup (a separate Standard account for the child, Screen Time,
the login item, and the parent password) is here:

https://github.com/matjns/kids-computer/blob/main/docs/SETUP.md

Parent settings: hold Control, Option, and Command, then press P.
There is no default password. The first time, you create one.

Chess opens the Chess app that came with the Mac. Race Time, Typing Tutor,
Math Quiz, Reading, and Drawing Helper say Coming soon until those apps
are installed. Installing an app with the matching bundle id wakes the
tile up. You do not rebuild the launcher for that.
