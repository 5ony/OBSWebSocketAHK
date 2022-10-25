#Include lib/OBSWebSocket.ahk

obsc := new OBSWebSocket("ws://192.168.1.100:4455/")
return

Numpad1::
obsc.SetCurrentProgramScene("Gaming with camera")
return

Numpad2::
obsc.SetCurrentProgramScene("Be right back")
return
