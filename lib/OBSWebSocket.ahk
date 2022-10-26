
/**
 * Lib: OBSWebSocket.ahk
 *     OBS Studio WebScocket library for AutoHotkey
 * Version:
 *     v1.0.0 [updated 2022-10-25 (YYYY-MM-DD)]
 * Requirements:
 *     Latest version of AutoHotkey (v1.1+ or v2.0-a+)
 *     WebSocket.ahk - https://github.com/G33kDude/WebSocket.ahk
 *     JSON.ahk - https://github.com/cocobelgica/AutoHotkey-JSON
 * OBS WebSocket specifications: 
 *     https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md
 * 
 * Installation:
 *     Use #Include OBSWebSocket.ahk or copy into a function library folder and then
 *     use #Include <OBSWebSocket>
 * Links:
 *     GitHub:		- https://github.com/5ony/OBSWebSocketAHK
 */

#Include ./lib/WebSocket.ahk
#Include ./lib/JSON.ahk
#Include ./lib/libcrypt.ahk

class OBSWebSocket extends WebSocket
{
	static WebSocketOpCode := { Hello: 0
		, Identify: 1
		, Identified: 2
		, Reidentify: 3
		, Event: 5
		, Request: 6
		, RequestResponse: 7
		, RequestBatch: 8
		, RequestBatchResponse: 9 }

	static WebSocketCloseCode := { DontClose: 0
		, UnknownReason: 4000
		, MessageDecodeError: 4002
		, MissingDataField: 4003
		, InvalidDataFieldType: 4004
		, InvalidDataFieldValue: 4005
		, UnknownOpCode: 4006
		, NotIdentified: 4007
		, AlreadyIdentified: 4008
		, AuthenticationFailed: 4009
		, UnsupportedRpcVersion: 4010
		, SessionInvalidated: 4011
		, UnsupportedFeature: 4012 }

	static RequestStatus := { Unknown: 0
		, NoError: 10
		, Success: 100
		, MissingRequestType: 203
		, UnknownRequestType: 204
		, GenericError: 205
		, UnsupportedRequestBatchExecutionType: 206
		, MissingRequestField: 300
		, MissingRequestData: 301
		, InvalidRequestField: 400
		, InvalidRequestFieldType: 401
		, RequestFieldOutOfRange: 402
		, RequestFieldEmpty: 403
		, TooManyRequestFields: 404
		, OutputRunning: 500
		, OutputNotRunning: 501
		, OutputPaused: 502
		, OutputNotPaused: 503
		, OutputDisabled: 504
		, StudioModeActive: 505
		, StudioModeNotActive: 506
		, ResourceNotFound: 600
		, ResourceAlreadyExists: 601
		, InvalidResourceType: 602
		, NotEnoughResources: 603
		, InvalidResourceState: 604
		, InvalidInputKind: 605
		, ResourceNotConfigurable: 606
		, InvalidFilterKind: 607
		, ResourceCreationFailed: 700
		, ResourceActionFailed: 701
		, RequestProcessingFailed: 702
		, CannotAct: 0 }

	static EventSubscription := { General: 1 << 0
		, Config: 1 << 1
		, Scenes: 1 << 2
		, Inputs: 1 << 3
		, Transitions: 1 << 4
		, Filters: 1 << 5
		, Outputs: 1 << 6
		, SceneItems: 1 << 7
		, MediaInputs: 1 << 8
		, Vendors: 1 << 9
		, Ui: 1 << 10
		, InputVolumeMeters: 1 << 16
		, InputActiveStateChanged: 1 << 17
		, InputShowStateChanged: 1 << 18
		, SceneItemTransformChanged: 1 << 19
		, All: 1 << 1 | 1 << 2 | 1 << 3 | 1 << 4 | 1 << 5 | 1 << 6 | 1 << 7 | 1 << 8 | 1 << 9 | 1 << 10 | 1 << 16 | 1 << 17 | 1 << 18 | 1 << 19 }

	_rpcVersion := 0
	_requestId := "OBSWebSocket-" . A_Now ; a simple id
	_eventSubscriptions := 0
	_pwd := 0

	__New(websocketUrl, pwd := 0, subscriptions := 0) {
		this._eventSubscriptions := subscriptions
		this._pwd := pwd
		base.__New(websocketUrl)
	}

	OnOpen(Event) {
	}
	
	OnMessage(Event) {
		value := JSON.Load( Event.data )
		if (value.op = this.WebSocketOpCode.Hello) {
			this._rpcVersion := value.d.rpcVersion
			msgBox, % Event.data

			helloAnswer := {op: this.WebSocketOpCode.Identify,d: {rpcVersion: this._rpcVersion, eventSubscriptions: this._eventSubscriptions}}
			if (value.d.authentication) {
				helloAnswer.d.authentication := this.__GenerateSecretHash(value.d.authentication)
			}
			this.Send(this.__ReplaceBooleanValuesInJSON(helloAnswer))
		}
		if (value.op = this.WebSocketOpCode.Identified) {
			this["AfterIdentified"]()
		}
		if (value.op = this.WebSocketOpCode.RequestResponse && this._requestId = value.d.requestId) {
			if (value.d.requestStatus.code != this.RequestStatus.Success) {
				MsgBox, % "Error, RequestStatus " value.d.requestStatus.code " | " value.d.requestStatus.comment
				return
			}
			this[value.d.requestType . "Response"](value)
		}		
		if (value.op = this.WebSocketOpCode.Event) {
			this[value.d.eventType . "Event"](value)
		}
	}

	OnClose(Event) {
		MsgBox, % "Websocket Closed: " Event.data
		this.Disconnect()
	}
	
	OnError(Event) {
		MsgBox, % "Websocket Error "
		ExitApp
	}
	
	__Delete() {
		MsgBox, Exiting
		ExitApp
	}

	__GenerateSecretHash(helloResult) {
		hex := LC_SHA256(this._pwd . helloResult.salt)
		LC_Hex2Bin(b64Secret, hex)
		LC_Base64_Encode(b64SecretChallenge, b64Secret, StrLen(hex) / 2)
		hex := LC_SHA256(b64SecretChallenge . helloResult.challenge)
		LC_Hex2Bin(b64Secret, hex)
		LC_Base64_Encode(authentication, b64Secret, StrLen(hex) / 2)
		return authentication
	}

	__ReplaceBooleanValuesInJSON(obj) {
		string := JSON.Dump(obj)
		string := StrReplace(string, """true""", "true")
		string := StrReplace(string, """false""", "false")
		string := RegExReplace(string, "(""(\d+\.*\d*)"")", "$2")
		return string
	}

	__GetFunctionName(funcName) {
		return StrReplace(funcName, "OBSWebSocket.", "")
	}

	Boolean(booleanValue) {
 		return booleanValue ? "true" : "false"
	}

	SendRequestToObs(requestTypeParam := "", requestData := 0) {
		requestType := this.__GetFunctionName(requestTypeParam)
		request := { op: this.WebSocketOpCode.Request, d: { requestType: requestType, requestId: this._requestId }}
		if (requestData != 0) {
			request.d.requestData := requestData
		}
		this.Send(this.__ReplaceBooleanValuesInJSON(request))
	}

	GetVersion() {
		this.SendRequestToObs(A_ThisFunc)
	}
	GetStats() {
		this.SendRequestToObs(A_ThisFunc)
	}
	BroadcastCustomEvent(eventData) {
		this.SendRequestToObs(A_ThisFunc, eventData)
	}
	CallVendorRequest(vendorName, requestType, requestData := 0) {
		data := {vendorName: vendorName, requestType: requestType}
		if (requestData) {
			data.requestData := requestData
		}
		this.SendRequestToObs(A_ThisFunc, data)
	}
	GetHotkeyList() {
		this.SendRequestToObs(A_ThisFunc)
	}
	TriggerHotkeyByName(hotkeyName) {
		this.SendRequestToObs(A_ThisFunc, {hotkeyName: hotkeyName})
	}
	TriggerHotkeyByKeySequence(keyId, shiftKey := "false", controlKey := "false", altKey := "false", commandKey := "false") {
		data := { keyId: keyId, shiftKey: shiftKey, controlKey: controlKey, altKey: altKey, commandKey: commandKey }
		this.SendRequestToObs(A_ThisFunc, data)
	}
	Sleep(sleepTime, inFrames := "false") {
		data := { sleepMillis: sleepTime }
		if (inFrames) {
			data := { sleepFrames: sleepTime }
		}
		this.SendRequestToObs(A_ThisFunc, data)
	}
	GetPersistentData(realm, slotName) {
		this.SendRequestToObs(A_ThisFunc, {realm: realm, slotName: slotName})
	}
	SetPersistentData(realm, slotName, slotValue) {
		this.SendRequestToObs(A_ThisFunc, {realm: realm, slotName: slotName, slotValue: slotValue})
	}
	GetSceneCollectionList() {
		this.SendRequestToObs(A_ThisFunc)
	}
	SetCurrentSceneCollection(sceneCollectionName) {
		this.SendRequestToObs(A_ThisFunc, {sceneCollectionName: sceneCollectionName})
	}
	CreateSceneCollection(sceneCollectionName) {
		this.SendRequestToObs(A_ThisFunc, {sceneCollectionName: sceneCollectionName})
	}
	GetProfileList(currentProfileName, profiles) {
		this.SendRequestToObs(A_ThisFunc, {currentProfileName: currentProfileName, profiles: profiles})
	}
	SetCurrentProfile(profileName) {
		this.SendRequestToObs(A_ThisFunc, {profileName: profileName})
	}
	CreateProfile(profileName) {
		this.SendRequestToObs(A_ThisFunc, {profileName: profileName})
	}
	RemoveProfile(profileName) {
		this.SendRequestToObs(A_ThisFunc, {profileName: profileName})
	}
	GetProfileParameter(parameterCategory, parameterName) {
		this.SendRequestToObs(A_ThisFunc, {parameterCategory: parameterCategory, parameterName: parameterName})
	}
	SetProfileParameter(parameterCategory, parameterName, parameterValue) {
		this.SendRequestToObs(A_ThisFunc, {parameterCategory: parameterCategory, parameterName: parameterName, parameterValue: parameterValue})
	}
	GetVideoSettings() {
		this.SendRequestToObs(A_ThisFunc)
	}
	SetVideoSettings(fpsNumerator := 0, fpsDenominator := 0, baseWidth := 0, baseHeight := 0, outputWidth := 0, outputHeight := 0) {
		data := {}
		if (fpsNumerator > 0) {
			data.fpsNumerator := fpsNumerator
		}
		if (fpsDenominator > 0) {
			data.fpsDenominator := fpsDenominator
		}
		if (baseWidth > 0) {
			data.baseWidth := baseWidth
		}
		if (baseHeight > 0) {
			data.baseHeight := baseHeight
		}
		if (outputWidth > 0) {
			data.outputWidth := outputWidth
		}
		if (outputHeight > 0) {
			data.outputHeight := outputHeight
		}
		this.SendRequestToObs(A_ThisFunc, data)
	}
	GetStreamServiceSettings() {
		this.SendRequestToObs(A_ThisFunc)
	}
	SetStreamServiceSettings(streamServiceType, streamServiceSettings) {
		this.SendRequestToObs(A_ThisFunc, {streamServiceType: streamServiceType, streamServiceSettings: streamServiceSettings})
	}
	GetRecordDirectory(recordDirectory) {
		this.SendRequestToObs(A_ThisFunc, {recordDirectory: recordDirectory})
	}
	GetSourceActive(sourceName) {
		this.SendRequestToObs(A_ThisFunc, {sourceName: sourceName})
	}
	GetSourceScreenshot(sourceName, imageFormat, imageWidth := 0, imageHeight := 0, imageCompressionQuality := 0) {
		data := {sourceName: sourceName, imageFormat: imageFormat}
		if (imageWidth) {
			data.imageWidth := imageWidth
		}
		if (imageHeight) {
			data.imageHeight := imageHeight
		}
		if (imageCompressionQuality) {
			data.imageCompressionQuality := imageCompressionQuality
		}
		this.SendRequestToObs(A_ThisFunc, data)
	}
	SaveSourceScreenshot(sourceName, imageFormat, imageFilePath, imageWidth := 0, imageHeight := 0, imageCompressionQuality := 0) {
		data := {sourceName: sourceName, imageFormat: imageFormat}
		if (imageWidth) {
			data.imageWidth := imageWidth
		}
		if (imageHeight) {
			data.imageHeight := imageHeight
		}
		if (imageCompressionQuality) {
			data.imageCompressionQuality := imageCompressionQuality
		}
		this.SendRequestToObs(A_ThisFunc)
	}
	GetSceneList() {
		this.SendRequestToObs(A_ThisFunc)
	}
	GetGroupList(groups) {
		this.SendRequestToObs(A_ThisFunc, {groups: groups})
	}
	GetCurrentProgramScene() {
		this.SendRequestToObs(A_ThisFunc)
	}
	SetCurrentProgramScene(sceneName) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName})
	}
	GetCurrentPreviewScene() {
		this.SendRequestToObs(A_ThisFunc)
	}
	SetCurrentPreviewScene(sceneName) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName})
	}
	CreateScene(sceneName) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName})
	}
	RemoveScene(sceneName) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName})
	}
	SetSceneName(sceneName, newSceneName) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, newSceneName: newSceneName})
	}
	GetSceneSceneTransitionOverride(sceneName) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName})
	}
	SetSceneSceneTransitionOverride(sceneName, transitionName := 0, transitionDuration := 0) {
		data := {sceneName: sceneName}
		if (transitionName) {
			data.transitionName := transitionName
		}
		if (transitionDuration) {
			data.transitionDuration := transitionDuration
		}
		this.SendRequestToObs(A_ThisFunc, data)
	}
	GetInputList(inputKind) {
		data := {}
		if (inputKind) data.inputKind := inputKind
		this.SendRequestToObs(A_ThisFunc, data)
	}
	GetInputKindList(unversioned := "false") {
		this.SendRequestToObs(A_ThisFunc, {unversioned: unversioned})
	}
	GetSpecialInputs() {
		this.SendRequestToObs(A_ThisFunc)
	}
	CreateInput(sceneName, inputName, inputKind, inputSettings := 0, sceneItemEnabled := 0) {
		data := {sceneName: sceneName, inputName: inputName, inputKind: inputKind}
		if (inputSettings) {
			data.inputSettings := inputSettings
		}
		if (sceneItemEnabled) {
			data.sceneItemEnabled := sceneItemEnabled
		}
		this.SendRequestToObs(A_ThisFunc)
	}
	RemoveInput(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	SetInputName(inputName, newInputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName, newInputName: newInputName})
	}
	GetInputDefaultSettings(inputKind) {
		this.SendRequestToObs(A_ThisFunc, {inputKind: inputKind})
	}
	GetInputSettings(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	SetInputSettings(inputName, inputSettings, overlay := 0) {
		data := {inputName: inputName, inputSettings: inputSettings}
		if (overlay) {
			data.overlay := overlay
		}
		this.SendRequestToObs(A_ThisFunc, data)
	}
	GetInputMute(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	SetInputMute(inputName, inputMuted) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName, inputMuted: inputMuted})
	}
	ToggleInputMute(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	GetInputVolume(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	SetInputVolume(inputName, inputVolumeMul:=-1, inputVolumeDb:=0) {
		if (inputVolumeMul > -1) {
			data.inputVolumeMul := inputVolumeMul
		}
		if (inputVolumeDb) {
			data.inputVolumeDb := inputVolumeDb
		}
		this.SendRequestToObs(A_ThisFunc)
	}
	GetInputAudioBalance(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	SetInputAudioBalance(inputName, inputAudioBalance) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName, inputAudioBalance: inputAudioBalance})
	}
	GetInputAudioSyncOffset(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	SetInputAudioSyncOffset(inputName, inputAudioSyncOffset) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName, inputAudioSyncOffset: inputAudioSyncOffset})
	}
	GetInputAudioMonitorType(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	SetInputAudioMonitorType(inputName, monitorType) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName, monitorType: monitorType})
	}
	GetInputAudioTracks(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	SetInputAudioTracks(inputName, inputAudioTracks) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName, inputAudioTracks: inputAudioTracks})
	}
	GetInputPropertiesListPropertyItems(inputName, propertyName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName, propertyName: propertyName})
	}
	PressInputPropertiesButton(inputName, propertyName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName, propertyName: propertyName})
	}
	GetTransitionKindList() {
		this.SendRequestToObs(A_ThisFunc, {transitionKinds: transitionKinds})
	}
	GetSceneTransitionList() {
		this.SendRequestToObs(A_ThisFunc)
	}
	GetCurrentSceneTransition() {
		this.SendRequestToObs(A_ThisFunc)
	}
	SetCurrentSceneTransition(transitionName) {
		this.SendRequestToObs(A_ThisFunc, {transitionName: transitionName})
	}
	SetCurrentSceneTransitionDuration(transitionDuration) {
		this.SendRequestToObs(A_ThisFunc, {transitionDuration: transitionDuration})
	}
	SetCurrentSceneTransitionSettings(transitionSettings, overlay:="true") {
		this.SendRequestToObs(A_ThisFunc, {transitionSettings: transitionSettings, overlay: overlay})
	}
	GetCurrentSceneTransitionCursor() {
		this.SendRequestToObs(A_ThisFunc)
	}
	TriggerStudioModeTransition() {
		this.SendRequestToObs(A_ThisFunc)
	}
	SetTBarPosition(position, release:="true") {
		this.SendRequestToObs(A_ThisFunc, {position: position, release: release})
	}
	GetSourceFilterList(sourceName) {
		this.SendRequestToObs(A_ThisFunc, {sourceName: sourceName})
	}
	GetSourceFilterDefaultSettings(filterKind) {
		this.SendRequestToObs(A_ThisFunc, {filterKind: filterKind})
	}
	CreateSourceFilter(sourceName, filterName, filterKind, filterSettings:=0) {
		data := {sourceName: sourceName, filterName: filterName, filterKind: filterKind}
		if (filterSettings) {
			data.filterSettings := filterSettings
		}
		this.SendRequestToObs(A_ThisFunc, data)
	}
	RemoveSourceFilter(sourceName, filterName) {
		this.SendRequestToObs(A_ThisFunc, {sourceName: sourceName, filterName: filterName})
	}
	SetSourceFilterName(sourceName, filterName, newFilterName) {
		this.SendRequestToObs(A_ThisFunc, {sourceName: sourceName, filterName: filterName, newFilterName: newFilterName})
	}
	GetSourceFilter(sourceName, filterName) {
		this.SendRequestToObs(A_ThisFunc, {sourceName: sourceName, filterName: filterName})
	}
	SetSourceFilterIndex(sourceName, filterName, filterIndex) {
		this.SendRequestToObs(A_ThisFunc, {sourceName: sourceName, filterName: filterName, filterIndex: filterIndex})
	}
	SetSourceFilterSettings(sourceName, filterName, filterSettings, overlay:="true") {
		this.SendRequestToObs(A_ThisFunc, {sourceName: sourceName, filterName: filterName, filterSettings: filterSettings, overlay: overlay})
	}
	SetSourceFilterEnabled(sourceName, filterName, filterEnabled) {
		this.SendRequestToObs(A_ThisFunc, {sourceName: sourceName, filterName: filterName, filterEnabled: filterEnabled})
	}
	GetSceneItemList(sceneName) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName})
	}
	GetGroupSceneItemList(sceneName) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName})
	}
	GetSceneItemId(sceneName, sourceName, searchOffset := 0) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sourceName: sourceName, searchOffset: searchOffset})
	}
	CreateSceneItem(sceneName, sourceName, sceneItemEnabled := "true") {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sourceName: sourceName, sceneItemEnabled: sceneItemEnabled})
	}
	RemoveSceneItem(sceneName, sceneItemId) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	DuplicateSceneItem(sceneName, sceneItemId, destinationSceneName := 0) {
		data := {sceneName: sceneName, sceneItemId: sceneItemId}
		if (destinationSceneName) {
			data.destinationSceneName := destinationSceneName
		}
		this.SendRequestToObs(A_ThisFunc, data)
	}
	GetSceneItemTransform(sceneName, sceneItemId) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	SetSceneItemTransform(sceneName, sceneItemId, sceneItemTransform) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sceneItemId: sceneItemId, sceneItemTransform: sceneItemTransform})
	}
	GetSceneItemEnabled(sceneName, sceneItemId) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	SetSceneItemEnabled(sceneName, sceneItemId, sceneItemEnabled) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sceneItemId: sceneItemId, sceneItemEnabled: sceneItemEnabled})
	}
	GetSceneItemLocked(sceneName, sceneItemId) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	SetSceneItemLocked(sceneName, sceneItemId, sceneItemLocked) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sceneItemId: sceneItemId, sceneItemLocked: sceneItemLocked})
	}
	GetSceneItemIndex(sceneName, sceneItemId) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	SetSceneItemIndex(sceneName, sceneItemId, sceneItemIndex) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sceneItemId: sceneItemId, sceneItemIndex: sceneItemIndex})
	}
	GetSceneItemBlendMode(sceneName, sceneItemId) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	SetSceneItemBlendMode(sceneName, sceneItemId, sceneItemBlendMode) {
		this.SendRequestToObs(A_ThisFunc, {sceneName: sceneName, sceneItemId: sceneItemId, sceneItemBlendMode: sceneItemBlendMode})
	}
	GetVirtualCamStatus() {
		this.SendRequestToObs(A_ThisFunc)
	}
	ToggleVirtualCam() {
		this.SendRequestToObs(A_ThisFunc)
	}
	StartVirtualCam() {
		this.SendRequestToObs(A_ThisFunc)
	}
	StopVirtualCam() {
		this.SendRequestToObs(A_ThisFunc)
	}
	GetReplayBufferStatus() {
		this.SendRequestToObs(A_ThisFunc)
	}
	ToggleReplayBuffer() {
		this.SendRequestToObs(A_ThisFunc)
	}
	StartReplayBuffer() {
		this.SendRequestToObs(A_ThisFunc)
	}
	StopReplayBuffer() {
		this.SendRequestToObs(A_ThisFunc)
	}
	SaveReplayBuffer() {
		this.SendRequestToObs(A_ThisFunc)
	}
	GetLastReplayBufferReplay() {
		this.SendRequestToObs(A_ThisFunc)
	}
	GetOutputList() {
		this.SendRequestToObs(A_ThisFunc)
	}
	GetOutputStatus(outputName) {
		this.SendRequestToObs(A_ThisFunc, {outputName: outputName})
	}
	ToggleOutput(outputName) {
		this.SendRequestToObs(A_ThisFunc, {outputName: outputName})
	}
	StartOutput(outputName) {
		this.SendRequestToObs(A_ThisFunc, {outputName: outputName})
	}
	StopOutput(outputName) {
		this.SendRequestToObs(A_ThisFunc, {outputName: outputName})
	}
	GetOutputSettings(outputName) {
		this.SendRequestToObs(A_ThisFunc, {outputName: outputName})
	}
	SetOutputSettings(outputName, outputSettings) {
		this.SendRequestToObs(A_ThisFunc, {outputName: outputName, outputSettings: outputSettings})
	}
	GetStreamStatus() {
		this.SendRequestToObs(A_ThisFunc)
	}
	ToggleStream() {
		this.SendRequestToObs(A_ThisFunc)
	}
	StartStream() {
		this.SendRequestToObs(A_ThisFunc)
	}
	StopStream() {
		this.SendRequestToObs(A_ThisFunc)
	}
	SendStreamCaption(captionText) {
		this.SendRequestToObs(A_ThisFunc, {captionText: captionText})
	}
	GetRecordStatus() {
		this.SendRequestToObs(A_ThisFunc)
	}
	ToggleRecord() {
		this.SendRequestToObs(A_ThisFunc)
	}
	StartRecord() {
		this.SendRequestToObs(A_ThisFunc)
	}
	StopRecord() {
		this.SendRequestToObs(A_ThisFunc)
	}
	ToggleRecordPause() {
		this.SendRequestToObs(A_ThisFunc)
	}
	PauseRecord() {
		this.SendRequestToObs(A_ThisFunc)
	}
	ResumeRecord() {
		this.SendRequestToObs(A_ThisFunc)
	}
	GetMediaInputStatus(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	SetMediaInputCursor(inputName, mediaCursor) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName, mediaCursor: mediaCursor})
	}
	OffsetMediaInputCursor(inputName, mediaCursorOffset) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName, mediaCursorOffset: mediaCursorOffset})
	}
	TriggerMediaInputAction(inputName, mediaAction) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName, mediaAction: mediaAction})
	}
	GetStudioModeEnabled() {
		this.SendRequestToObs(A_ThisFunc)
	}
	SetStudioModeEnabled(studioModeEnabled) {
		this.SendRequestToObs(A_ThisFunc, {studioModeEnabled: studioModeEnabled})
	}
	OpenInputPropertiesDialog(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	OpenInputFiltersDialog(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	OpenInputInteractDialog(inputName) {
		this.SendRequestToObs(A_ThisFunc, {inputName: inputName})
	}
	GetMonitorList() {
		this.SendRequestToObs(A_ThisFunc)
	}
	OpenVideoMixProjector(videoMixType, monitorIndex := -2, projectorGeometry := 0) {
		data := {videoMixType: videoMixType}
		if (monitorIndex > -2) {
			data.monitorIndex := monitorIndex
		}
		if (projectorGeometry) {
			data.projectorGeometry := projectorGeometry
		}
		this.SendRequestToObs(A_ThisFunc, data)
	}
	OpenSourceProjector(sourceName, monitorIndex := -2, projectorGeometry := 0) {
		data := {sourceName: sourceName}
		if (monitorIndex > -2) {
			data.monitorIndex := monitorIndex
		}
		if (projectorGeometry) {
			data.projectorGeometry := projectorGeometry
		}
		this.SendRequestToObs(A_ThisFunc)
	}
}
