#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {
	AfterIdentified() {
		this.OpenSourceProjector("Video Capture Device")
	}

	OpenSourceProjectorResponse(data) {
		MsgBox("Window is opened")
	}
}

obsc := MyOBSController("ws://127.0.0.1:4455/")
F11:: MsgBox("") ; this is here only for keeping the script running

