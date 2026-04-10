# PathFatter (SwiftUI)

This folder now includes a ready-to-open Xcode project for PathFatter.

To open the macOS app in Xcode:
1. Open `PathFatter/PathFatter.xcodeproj` in Xcode.
2. Build and run.

Notes:
- Windows drive letters map to `/Volumes/<Drive>` on macOS (e.g., `C:\Temp` -> `/Volumes/C/Temp`).
- macOS `/Users/<name>` maps to `C:\Users\<name>`.
- UNC paths map to `smb://server/share/...` and back.
- Custom drive mappings can be edited in Settings (Cmd+,). Import/Export uses JSON like:
  [
    { "windowsPrefix": "A:\\", "macPrefix": "smb://server/share/Data" }
  ]
- SharePoint URLs can be mapped to local OneDrive folders using SharePoint Mappings in Settings.
