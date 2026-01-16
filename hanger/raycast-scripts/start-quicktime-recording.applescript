#!/usr/bin/osascript

# @raycast.schemaVersion 1
# @raycast.title iPhone Mirroring (QuickTime)
# @raycast.mode silent
# @raycast.packageName Media Tools
# @raycast.icon 📱

tell application "QuickTime Player"
    activate
    set n to new movie recording
    
    -- iPhoneが認識されている場合、ソースをiPhoneに切り替える
    try
        -- "iPhone"という名前が含まれるビデオデバイスを探す
        set iphoneDevice to (first video recording device whose name contains "iPhone")
        set current camera of n to iphoneDevice
    on error
        -- iPhoneが見つからない場合は何もしない（デフォルトカメラのまま）
    end try
end tell