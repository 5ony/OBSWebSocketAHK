#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

obsc := OBSWebSocket("ws://127.0.0.1:4455/")

Numpad1::obsc.SetCurrentProgramScene("SceneA")
Numpad2::obsc.SetCurrentProgramScene("SceneB")
