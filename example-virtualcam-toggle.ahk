#NoEnv
SetBatchLines, -1

#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {
	virtualCamActive := 0

	AfterIdentified() {
		obsc.GetVirtualCamStatus()
	}

	GetVirtualCamStatusResponse(data) {
		this.virtualCamActive := data.d.responseData.outputActive
	}

	VirtualcamStateChangedEvent(data) {
		this.virtualCamActive := data.d.eventData.outputActive
	}
}

obsc := new MyOBSController("ws://127.0.0.1:4455/", "", MyOBSController.EventSubscription.All)

Numpad1::
	obsc.toggleVirtualCam(!outputActive)
return
