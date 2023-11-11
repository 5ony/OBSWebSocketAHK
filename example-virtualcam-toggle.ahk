#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {
	virtualCamActive := 0

	AfterIdentified() {
		this.GetVirtualCamStatus()
	}

	GetVirtualCamStatusResponse(data) {
		this.virtualCamActive := data.d.responseData.outputActive
	}

	VirtualcamStateChangedEvent(data) {
		this.virtualCamActive := data.d.eventData.outputActive
	}
}

outputActive := 0
obsc := MyOBSController("ws://127.0.0.1:4455/", "", MyOBSController.EventSubscription.All)
Numpad1::obsc.toggleVirtualCam(!outputActive)
