#Requires AutoHotkey >=2.0-
#Include lib/ObsWebSocket.ahk

class MyOBSController extends ObsWebSocket {
	sceneList := []
	sourceList := []
	filterList := []
	filterSettings := 0
	filterSettingsDefault := 0
	inputSettings := 0
	inputSettingsDefault := 0

	AfterIdentified() {
		this.GetInputKindList()
		this.GetSourceFilterKindList()
		this.GetSceneList()
		this.GetSpecialInputs()
	}

	GetInputKindListResponse(data) {
		inputKindsControl.Value := join(data.d.responseData.inputKinds)
	}	

	GetSourceFilterKindListResponse(data) {
		filterKindsControl.Value := join(data.d.responseData.sourceFilterKinds)
	}

	GetSpecialInputsResponse(data) {
		specialInputsControl.Value := JSON.stringify(data.d.responseData)
	}

	GetSceneListResponse(data) {
		this.sceneList := []
		for index,val in data.d.responseData.scenes
			this.sceneList.Push(val.sceneName)
		sceneListControl.Delete()
		sceneListControl.Add(this.sceneList)
	}

	GetSceneItemListResponse(data) {
		this.sourceList := []
		for index,val in data.d.responseData.sceneItems
			this.sourceList.Push(val.sourceName)
		sourceListControl.Delete()
		sourceListControl.Add(this.sourceList)
	}

	GetSourceFilterListResponse(data) {
		this.filterList := []
		filterListNames := []
		for index,val in data.d.responseData.filters {
			this.filterList.Push(val)
			filterListNames.Push(val.filterName)
		}
		filterListControl.Delete()
		filterListControl.Add(filterListNames)
	}

	GetSourceFilterSettings(sourceName, filterName, filterKind) {
		this.filterSettings := 0
		this.filterSettingsDefault := 0
		this.GetSourceFilter(sourceName, filterName)
		this.GetSourceFilterDefaultSettings(filterKind)
	}

	GetSourceFilterDefaultSettingsResponse(data) {
		this.filterSettingsDefault := data.d.responseData.defaultFilterSettings
		this.combineFilterSettings()
	}

	GetSourceFilterResponse(data) {
		this.filterSettings := data.d.responseData.filterSettings
		this.combineFilterSettings()
	}

	combineFilterSettings() {
		if (!this.filterSettings || !this.filterSettingsDefault) {
			return
		}
		fc := this.filterSettings
		fcd := this.filterSettingsDefault
		For Name, Value in fc.OwnProps() {
			fcd.%Name% := Value
		}

		filterSettingsControl.Value := JSON.stringify(fcd)
	}

	GetSourceSettings(inputName) {
		this.inputSettings := 0
		this.inputSettingsDefault := 0
		this.GetInputSettings(inputName)
	}

	GetInputSettingsResponse(data) {
		this.inputSettings := data.d.responseData.inputSettings
		this.GetInputDefaultSettings(data.d.responseData.inputKind)
	}

	GetInputDefaultSettingsResponse(data) {
		this.inputSettingsDefault := data.d.responseData.defaultInputSettings || {}
		this.combineSourceSettings()
	}

	combineSourceSettings() {
		inps := this.inputSettings
		inpsd := this.inputSettingsDefault
		For Name, Value in inps.OwnProps() {
			inpsd.%Name% := Value
		}
		sourceSettingsControl.Value := JSON.stringify(inpsd)
	}
	
	SceneNameChanged(data) {
		this.startRereadSceneList()
	}
	SceneCreated(data) {
		this.startRereadSceneList()
	}
	SceneRemoved(data) {
		this.startRereadSceneList()
	}

	startRereadSceneList() {
		sourceListControl.Delete()
		filterListControl.Delete()
		sourceSettingsControl.Value := ""
		filterSettingsControl.Value := ""
		this.GetSceneList()		
	}
}

calcPosText(x, y := 22, w := 1, h := 23) {
	return "x" . (8+x*128) . " y" . y . " w" . (w * 120 + (w-1)*8) . " h" . h . " +0x200"
}

calcPosInput(x, y := 46, w := 1, h := 488) {
	return "x" . (8+x*128) . " y" . y . " w" . (w * 120 + (w-1)*8) . " h" . h
}

join(arr, sep := "`n") {
	str := ""
	for index,val in arr
		str := str . val . sep
	return str
}

if A_LineFile = A_ScriptFullPath && !A_IsCompiled
{
	myGui := Gui()
	Tab := myGui.Add("Tab3", "x0 y0 w993 h541", ["Scene item settings", "WebSocket messages", "Object types"])
	Tab.UseTab(1)

	myGui.Add("Text", calcPosText(0), "Scenes")
	sceneListControl := myGui.Add("ListBox", calcPosInput(0))
	sceneListControl.OnEvent("Change", sceneListEventHandler)
	sceneListEventHandler(*) {
		filterListControl.Delete()
		filterSettingsControl.Value := ""
		sourceSettingsControl.Value := ""
		obsc.GetSceneItemList(obsc.sceneList.Get(sceneListControl.Value))
	}

	myGui.Add("Text", calcPosText(1), "Sources")
	sourceListControl := myGui.Add("ListBox", calcPosInput(1))
	sourceListControl.OnEvent("Change", sourceListEventHandler)
	sourceListEventHandler(*) {
		filterListControl.Delete()
		filterSettingsControl.Value := ""
		sourceSettingsControl.Value := ""
		obsc.GetSourceFilterList(obsc.sourceList[sourceListControl.Value])
		obsc.GetSourceSettings(obsc.sourceList[sourceListControl.Value])
	}

	myGui.Add("Text", calcPosText(2,,2), "Source settings")
	sourceSettingsControl := myGui.Add("Edit", calcPosInput(2,,2))

	myGui.Add("Text", calcPosText(4), "Filters")
	filterListControl := myGui.Add("ListBox", calcPosInput(4))
	filterListControl.OnEvent("Change", filterListEventHandler)
	filterListEventHandler(*) {
		filterSettingsControl.Value := ""
		obsc.GetSourceFilterSettings(obsc.sourceList[sourceListControl.Value], obsc.filterList[filterListControl.Value].filterName, obsc.filterList[filterListControl.Value].filterKind)
	}
	
	myGui.Add("Text", calcPosText(5,,2), "Filter settings")
	filterSettingsControl := myGui.Add("Edit", calcPosInput(5,,2))

	Tab.UseTab(2)
	myGui.Add("Text", calcPosText(0,,2), "Websocket messages (newest message on top)")
	messagesControl := myGui.Add("Edit", calcPosInput(0,,6))
	messagesClearButtonControl := myGui.Add("Button", "x816 y45 w80", "Clear")
	messagesClearButtonControl.OnEvent("Click", messagesClearButtonClick)
	messagesClearButtonClick(*) {
		messagesControl.Value := ""
	}

	Tab.UseTab(3)
	myGui.Add("Text", calcPosText(0,,2), "Input kinds")
	inputKindsControl := myGui.Add("Edit", calcPosInput(0,,2))

	myGui.Add("Text", calcPosText(2,,2), "Special inputs")
	specialInputsControl := myGui.Add("Edit", calcPosInput(2,,2))

	myGui.Add("Text", calcPosText(4,,2), "Filter kinds")
	filterKindsControl := myGui.Add("Edit", calcPosInput(4,,2))

	Tab.UseTab()


	myGui.OnEvent('Close', (*) => ExitApp())
	myGui.Title := "OBSWebSocketAHK helper (beta)"
	
	myGui.Show("w904 h541")
}

obsc := MyOBSController("ws://127.0.0.1:4455/", "", MyOBSController.EventSubscription.Scenes)
obsc.StartDebugConsole(messagesControl)
