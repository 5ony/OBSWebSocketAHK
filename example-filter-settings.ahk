#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

obsc := OBSWebSocket("ws://127.0.0.1:4455/")

F12:: {
	; you need to have a source "Desktop" and a Color Correction and a Sharpen filter applied already
	filterSettings := {brightness: 0.0, color_add: 0, color_multiply: 16777215, contrast: 4.0, gamma: 0.0, hue_shift: 180, opacity: 1.0, saturation: 0.0}
	obsc.SetSourceFilterSettings("Desktop", "Color Correction", filterSettings)

	filterSettings := {sharpness: 1.0}
	obsc.SetSourceFilterSettings("Desktop", "Sharpen", filterSettings)
}