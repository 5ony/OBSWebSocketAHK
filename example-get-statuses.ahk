#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {

	AfterIdentified() {
		this.ReadAllStatuses()
	}

	GetVirtualCamStatusResponse(data) {
		this.virtualCamActive := data.d.responseData.outputActive
		this.ShowEveryStatus()
	}

	GetRecordStatusResponse(data) {
		this.recordActive := data.d.responseData.outputActive
		this.ShowEveryStatus()
	}

	GetStreamStatusResponse(data) {
		this.streamActive := data.d.responseData.outputActive
		this.ShowEveryStatus()
	}

	ReadAllStatuses() {
		this.virtualCamActive := -1
		this.streamActive := -1
		this.recordActive := -1		
		this.GetVirtualCamStatus()
		this.GetRecordStatus()
		this.GetStreamStatus()
	}

	ShowEveryStatus() {
		if (this.virtualCamActive > -1 && this.streamActive > -1 && this.recordActive > -1) {
			MsgBox("virtualCam: " . this.virtualCamActive . ", stream: " . this.streamActive . ", record: " . this.recordActive)
		}
	}

}

obsc := MyOBSController("ws://127.0.0.1:4455/")

F12::obsc.ReadAllStatuses()
