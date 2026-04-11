# How to Grant Peekaboo Permissions

Peekaboo needs two macOS permissions to capture screenshots and automate UI.

## Quick Steps

1. **Open System Settings**
   - Click Apple menu () → System Settings

2. **Grant Screen Recording:**
   - Go to **Privacy & Security** → **Screen Recording**
   - Find **Peekaboo** or **Terminal** in the list
   - Toggle it **ON**
   - If not listed, click **+** and add `/opt/homebrew/bin/peekaboo`

3. **Grant Accessibility:**
   - Go to **Privacy & Security** → **Accessibility**
   - Find **Peekaboo** or **Terminal** in the list
   - Toggle it **ON**
   - If not listed, click **+** and add `/opt/homebrew/bin/peekaboo`

4. **Restart Terminal** (required for permissions to take effect)

5. **Test:**
   ```bash
   peekaboo list apps --json
   ```

## If Peekaboo Isn't Listed

The app might appear under different names:

- **Peekaboo**
- **Terminal** (if running from Terminal)
- **iTerm** (if using iTerm2)
- **OpenClaw** (if running via OpenClaw)

**Add manually:**
1. Click the **+** button in the permission panel
2. Navigate to `/opt/homebrew/bin/`
3. Select `peekaboo`
4. Click **Open**

## After Granting Permissions

Once granted, I can automatically:
- ✅ Capture screenshots at exact App Store sizes
- ✅ Open PathFatter and navigate through screens
- ✅ Capture all required screenshots in sequence
- ✅ Save them with proper naming for App Store Connect

## App Store Screenshot Requirements

**macOS App Store needs:**
- 13" display: 1440×900 or 2880×1800 (Retina)
- 15" display: 1680×1050 or 3024×1964 (Retina)
- Minimum 1 screenshot per display size
- Recommended 3-5 screenshots per display size

**Recommended shots:**
1. Main conversion screen (with sample path)
2. History panel open
3. Settings → Drive Mappings
4. Settings → SharePoint Mappings
5. Onboarding screen (if accessible)

---

**Once permissions are granted, just say "permissions granted" and I'll capture all screenshots automatically!**
