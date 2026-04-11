-- PathFatter App Store Screenshot Capturer
-- Run this in Script Editor or save as .app and run

tell application "System Events"
    -- Check if PathFatter is running
    set pathFatterRunning to exists process "PathFatter"
    
    if not pathFatterRunning then
        tell application "/Users/claws/Library/Developer/Xcode/DerivedData/PathFatter-atlrvhplgothykgmcgdlgflfuhkj/Build/Products/Release/PathFatter.app" to activate
        delay 2
    end if
    
    tell application "PathFatter" to activate
    delay 1
end tell

-- Create screenshots directory
do shell script "mkdir -p /Users/claws/.openclaw/workspace/PathFatter/screenshots"

-- Screenshot 1: Main screen (13")
tell application "System Events"
    tell process "PathFatter"
        set frontmost to true
        set position of window 1 to {100, 100}
        set size of window 1 to {1440, 900}
    end tell
end tell
delay 1
do shell script "screencapture -x -W -o /Users/claws/.openclaw/workspace/PathFatter/screenshots/13inch_main.png"

-- Screenshot 2: History panel
tell application "System Events"
    tell process "PathFatter"
        -- Click history button (adjust coordinates as needed)
        click button 3 of toolbar 1 of window 1
    end tell
end tell
delay 1
do shell script "screencapture -x -W -o /Users/claws/.openclaw/workspace/PathFatter/screenshots/13inch_history.png"

-- Screenshot 3: Settings (13")
tell application "System Events"
    tell process "PathFatter"
        keystroke "," using command down
    end tell
end tell
delay 1
do shell script "screencapture -x -W -o /Users/claws/.openclaw/workspace/PathFatter/screenshots/13inch_settings.png"

-- Close settings
tell application "System Events"
    tell process "PathFatter"
        keystroke "w" using command down
    end tell
end tell
delay 0.5

-- Resize for 15"
tell application "System Events"
    tell process "PathFatter"
        set position of window 1 to {100, 100}
        set size of window 1 to {1680, 1050}
    end tell
end tell
delay 1

-- Screenshot 4: Main screen (15")
do shell script "screencapture -x -W -o /Users/claws/.openclaw/workspace/PathFatter/screenshots/15inch_main.png"

-- Screenshot 5: Drive Mappings
tell application "System Events"
    tell process "PathFatter"
        keystroke "," using command down
    end tell
end tell
delay 1
do shell script "screencapture -x -W -o /Users/claws/.openclaw/workspace/PathFatter/screenshots/15inch_settings.png"

-- Close settings
tell application "System Events"
    tell process "PathFatter"
        keystroke "w" using command down
    end tell
end tell

display notification "Screenshots captured! Check ~/openclaw/workspace/PathFatter/screenshots/" with title "PathFatter"
