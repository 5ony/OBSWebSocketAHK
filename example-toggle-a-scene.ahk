#Include lib/OBSWebSocket.ahk

obsc := new OBSWebSocket("ws://127.0.0.1:4455/")
return

Numpad1::
obsc.SetCurrentProgramScene("Gaming with camera")
return

Numpad2::
obsc.SetCurrentProgramScene("Be right back")
return
