#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

; You will need two scenes "Gaming - muted" and "Gaming"
; There should be a "Mic/Aux" input device in the Audio Mixer

class MyOBSController extends OBSWebSocket {
	muted := false

	InputMuteStateChangedEvent(data) {
		; check if the mute change is about the microphone
		if (data.d.eventData.inputName = "Mic/Aux") {
			this.muted := data.d.eventData.inputMuted
			this.SetCurrentProgramScene(this.muted ? "Gaming - muted" : "Gaming")
		}
	}
}

obsc := MyOBSController("ws://127.0.0.1:4455/", 0, MyOBSController.EventSubscription.Inputs)

F12::obsc.SetInputMute("Mic/Aux", obsc.Boolean(!obsc.muted))
