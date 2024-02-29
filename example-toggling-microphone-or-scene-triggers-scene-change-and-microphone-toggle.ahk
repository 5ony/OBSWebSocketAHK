#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

; You will need two scenes "Be right back" and "Gaming"
; There should be a "Mic/Aux" input device in the Audio Mixer

class MyOBSController extends OBSWebSocket {

	muted := false
	beRightBackSceneName := "Be right back"
	gamingSceneName := "Gaming"

	CurrentProgramSceneChanged(data) {
		; check if the scene change should change the microphone too
		if ((data.d.eventData.sceneName = this.beRightBackSceneName && !this.muted) || (data.d.eventData.sceneName = this.gamingSceneName && this.muted)) {
			this.muted := !this.muted
			this.SetInputMute("Mic/Aux", this.Boolean(this.muted))
		}
	}

	InputMuteStateChanged(data) {
		; check if the mute change is about the microphone
		if (data.d.eventData.inputName = "Mic/Aux") {
			; update global muted variable, so AHK have the same muted state as OBS
			this.muted := data.d.eventData.inputMuted
			this.SetCurrentProgramScene(this.muted ? this.beRightBackSceneName : this.gamingSceneName)
		}
	}
}

obsc := MyOBSController("ws://127.0.0.1:4455/", 0, MyOBSController.EventSubscription.Inputs | MyOBSController.EventSubscription.Scenes)

F12::obsc.SetInputMute("Mic/Aux", obsc.Boolean(!obsc.muted))
