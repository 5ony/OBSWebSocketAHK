#Include lib/OBSWebSocket.ahk

class MyOBSController extends OBSWebSocket {
	muted := false

	InputMuteStateChangedEvent(data) {
		; check if the mute change is about the microphone
		if (data.d.eventData.inputName = 'Mic/Aux') {
			this.muted := data.d.eventData.inputMuted
			this.SetCurrentProgramScene(this.muted ? "Gaming - muted" : "Gaming")
		}
	}
}

obsc := new MyOBSController("ws://127.0.0.1:4455/", 0, MyOBSController.EventSubscription.Input)

F12::
	obsc.SetInputMute("Mic/Aux", obsc.Boolean(!obsc.muted))
	return
