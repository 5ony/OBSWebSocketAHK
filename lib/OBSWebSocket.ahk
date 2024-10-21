/**
 * Lib: OBSWebSocket.ahk
 *     OBS Studio WebScocket library for AutoHotkey
 * Version:
 *     v2.0.7 [updated 2024-06-09 (YYYY-MM-DD)]
 * Requirements:
 *     AutoHotkey v2.0+
 *     JSON.ahk - https://github.com/thqby/ahk2_lib/blob/master/JSON.ahk
 *     Class_CNG.ahk - https://github.com/jNizM/AHK_CNG
 * OBS WebSocket specifications:
 *     https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md
 * Installation:
 *     Copy this file with the required libraries to a "lib" subdirectory
 *     Use #Include lib/OBSWebSocket.ahk
 * Links:
 *     GitHub:		- https://github.com/5ony/OBSWebSocketAHK
 */

#Requires AutoHotkey >=2.0-
#Include JSON.ahk
#Include Class_CNG.ahk

class OBSWebSocket {
	static WebSocketOpCode := {
		Hello: 0,
		Identify: 1,
		Identified: 2,
		Reidentify: 3,
		Event: 5,
		Request: 6,
		RequestResponse: 7,
		RequestBatch: 8,
		RequestBatchResponse: 9
	}

	static WebSocketCloseCode := {
		DontClose: 0,
		UnknownReason: 4000,
		MessageDecodeError: 4002,
		MissingDataField: 4003,
		InvalidDataFieldType: 4004,
		InvalidDataFieldValue: 4005,
		UnknownOpCode: 4006,
		NotIdentified: 4007,
		AlreadyIdentified: 4008,
		AuthenticationFailed: 4009,
		UnsupportedRpcVersion: 4010,
		SessionInvalidated: 4011,
		UnsupportedFeature: 4012
	}

	static RequestStatus := { Unknown: 0,
		NoError: 10,
		Success: 100,
		MissingRequestType: 203,
		UnknownRequestType: 204,
		GenericError: 205,
		UnsupportedRequestBatchExecutionType: 206,
		NotReady: 207,
		MissingRequestField: 300,
		MissingRequestData: 301,
		InvalidRequestField: 400,
		InvalidRequestFieldType: 401,
		RequestFieldOutOfRange: 402,
		RequestFieldEmpty: 403,
		TooManyRequestFields: 404,
		OutputRunning: 500,
		OutputNotRunning: 501,
		OutputPaused: 502,
		OutputNotPaused: 503,
		OutputDisabled: 504,
		StudioModeActive: 505,
		StudioModeNotActive: 506,
		ResourceNotFound: 600,
		ResourceAlreadyExists: 601,
		InvalidResourceType: 602,
		NotEnoughResources: 603,
		InvalidResourceState: 604,
		InvalidInputKind: 605,
		ResourceNotConfigurable: 606,
		InvalidFilterKind: 607,
		ResourceCreationFailed: 700,
		ResourceActionFailed: 701,
		RequestProcessingFailed: 702,
		CannotAct: 703
	}

	static EventSubscription := {
		None: 0,
		General: 1 << 0,
		Config: 1 << 1,
		Scenes: 1 << 2,
		Inputs: 1 << 3,
		Transitions: 1 << 4,
		Filters: 1 << 5,
		Outputs: 1 << 6,
		SceneItems: 1 << 7,
		MediaInputs: 1 << 8,
		Vendors: 1 << 9,
		Ui: 1 << 10,
		InputVolumeMeters: 1 << 16,
		InputActiveStateChanged: 1 << 17,
		InputShowStateChanged: 1 << 18,
		SceneItemTransformChanged: 1 << 19,
		All: 1 << 1 | 1 << 2 | 1 << 3 | 1 << 4 | 1 << 5 | 1 << 6 | 1 << 7 | 1 << 8 | 1 << 9 | 1 << 10 | 1 << 16 | 1 << 17 | 1 << 18 | 1 << 19
	}

	_rpcVersion := 0
	_requestId := 1 ; a simple id
	_eventSubscriptions := 0
	_pwd := 0
	_IEGui := 0
	_hasWS := 0
	_websocketUrl := ""
	_isSilent := 1
	_console := false

	__New(websocketUrl, pwd := 0, subscriptions := 0, isSilent := 1) {
		this._eventSubscriptions := subscriptions
		this._pwd := pwd
		this._isSilent := 0
		this._websocketUrl := websocketUrl
		this.__CreateBasicWS()
	}

	StartDebugConsole(control := 0) {
		if (!this._console) {
			this._console := DebugConsole(control)
		}
	}

	__CreateBasicWS() {
		this._IEGui := Gui()
		this.explorer := this._IEGui.Add("ActiveX", "", "Shell.Explorer").Value
		this.explorer.Navigate("about:<!DOCTYPE html><meta http-equiv='X-UA-Compatible' content='IE=edge'><body></body>")
		while (this.explorer.ReadyState < 4)
			Sleep(50)
		this.document := this.explorer.document
		this.document.parentWindow.ahk_event := this.__WSEvent.Bind(this)
		this.document.parentWindow.ahk_ws_url := this._websocketUrl
		Script := this.document.createElement("script")
		Script.text := "ws = new WebSocket(ahk_ws_url);`n"
		. "ws.onopen = function(event){ ahk_event('OnOpen', event); };`n"
		. "ws.onclose = function(event){ ahk_event('OnClose', event); };`n"
		. "ws.onerror = function(event){ ahk_event('OnError', event); };`n"
		. "ws.onmessage = function(event){ ahk_event('OnMessage', event); };`n"
		. "sendData = function(data) { try { ws.send(data); } catch(e) { ahk_event('OnError', e); } }`n"

		this.document.body.appendChild(Script)
	}

	__CallFunction(functionName, arg:="") {
		if (this.HasMethod(functionName)) {
			if (arg)
				this.%functionName%(arg)
			else
				this.%functionName%()
		}
	}

	__GetStatusCode(statusCodeObject, valueToMatch) {
		for (key, value in statusCodeObject.OwnProps()) {
			if (value = valueToMatch) {
				return key
			}
		}
		return ""
	}

	__WSEvent(EventName, Event)	{
		if (this.HasMethod(EventName))
			this.%EventName%(Event)
	}

	__TrayTipMsg(msg, title, icon, mute := true) {
		if (!this._isSilent) {
			TrayTip(msg, title, icon | (mute ? 16 : 0))
		}
	}

	__Min(a, b) {
		return a < b ? a : b
	}

	__Max(a, b) {
		return a > b ? a : b
	}

	__MinMax(v, min, max) {
		return this.__Max(this.__Min(v, max), min)
	}

	__Debug(obj) {
		MsgBox(JSON.stringify(obj))
	}

	OnOpen(Event) {
		this._hasWS := 1
	}

	OnMessage(Event) {
		value := MapToObject(JSON.parse(Event.data))
		if (this._console) {
			this._console.log("Received:`n" . JSON.stringify(value))
		}
		if (value.op = OBSWebSocket.WebSocketOpCode.RequestResponse) {
			if (value.d.requestStatus.code != OBSWebSocket.RequestStatus.Success) {
				errorTxt := "Error, RequestStatus: "
				errorTxt := errorTxt . this.__GetStatusCode(OBSWebSocket.RequestStatus, value.d.requestStatus.code)
				errorTxt := errorTxt . " (" . value.d.requestStatus.code . ")"
				if (value.d.requestStatus.HasOwnProp("comment")) {
					errorTxt := errorTxt . " | " . value.d.requestStatus.comment
				}
				this.__TrayTipMsg(errorTxt, "OBSWebSocket", "Icon!")
				return
			}
			; if the requestId starts with __, then it is an "internal" call
			if (InStr(value.d.requestId,"__") = 1) {
				this.__CallFunction("__" . value.d.requestType . "Response", value)
			} else {
				this.__CallFunction(value.d.requestType . "Response", value)
			}
		} else if (value.op = OBSWebSocket.WebSocketOpCode.Event) {
			if (this.HasMethod(value.d.eventType)) {
				this.__CallFunction(value.d.eventType, value)
			} else {
				this.__CallFunction(value.d.eventType . "Event", value)
			}
		} else if (value.op = OBSWebSocket.WebSocketOpCode.Hello) {
			this._rpcVersion := value.d.rpcVersion

			helloAnswer := {op: OBSWebSocket.WebSocketOpCode.Identify,d: {rpcVersion: this._rpcVersion, eventSubscriptions: this._eventSubscriptions}}
			if (value.d.HasOwnProp("authentication")) {
				helloAnswer.d.authentication := this.__GenerateSecretHash(value.d.authentication)
			}
			this.Send(this.__ReplaceBooleanValuesInJSON(helloAnswer))
		} else if (value.op = OBSWebSocket.WebSocketOpCode.Identified) {
			this.__CallFunction("AfterIdentified")
		}
	}

	OnClose(Event) {
		this.__TrayTipMsg("Websocket Closed", "OBSWebSocket", "Iconi")
		this.__DestroyWS()
	}

	OnError(Event) {
		this.__TrayTipMsg("Websocket Error " . Event, "OBSWebSocket", "Iconx")
		this.__DestroyWS()
	}

	Send(Data)
	{
		state := this.GetWebSocketState()
		if (state = 1) {
			this.document.parentWindow.sendData(Data)
			return
		}
		stateText := this.__GetWebSocketStateString(state)
		this.__TrayTipMsg("Websocket state is " . stateText, "OBSWebSocket", "Iconi")
		if (this.RetryConnection() = 1) {
			this.document.parentWindow.sendData(Data)
		}
	}

	RetryConnection() {
		; retry
		this.__CreateBasicWS()
		state := 0

		while (state = 0) {
			state := this.GetWebSocketState()
			Sleep(3000)
		}
		return state
	}

	IsWebSocketAlive() {
		return this.GetWebSocketState() = 1
	}

	GetWebSocketState() {
		if(!this._IEGui || !this.document || !this.document.parentWindow || !this._hasWS) {
			return 3 ;WebSocket.readyState.CLOSED
		}
		return this.document.parentWindow.ws.readyState
	}

	SetSilentMode(mode := 1) {
		this._isSilent := mode
	}

	Boolean(booleanValue) {
		return booleanValue ? "true" : "false"
	}


	__Delete() {
		this.__TrayTipMsg("Exiting...", "OBSWebSocket", "Iconi")
		this.__DestroyWS()
		ExitApp
	}

	__GetWebSocketStateString(readyState) {
		return ["connecting","open","closing","closed"][readyState+1]
	}

	__DestroyWS()
	{
		if this._IEGui
		{
			this.document.close()
			this._IEGui.Destroy()
		}
		this._hasWS := 0
	}

	__StringToBase64(String, Encoding := "UTF-8")
	{
		static CRYPT_STRING_BASE64 := 0x00000001
		static CRYPT_STRING_NOCRLF := 0x40000000

		Binary := Buffer(StrPut(String, Encoding))
		StrPut(String, Binary, Encoding)
		if !(DllCall("crypt32\CryptBinaryToStringW", "Ptr", Binary, "UInt", Binary.Size - 1, "UInt", (CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF), "Ptr", 0, "UInt*", &Size := 0))
			throw OSError()

		Base64 := Buffer(Size << 1, 0)
		if !(DllCall("crypt32\CryptBinaryToStringW", "Ptr", Binary, "UInt", Binary.Size - 1, "UInt", (CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF), "Ptr", Base64, "UInt*", Size))
			throw OSError()

		return StrGet(Base64)
	}

	__GenerateSecretHash(helloResult) {
		hex := Hash.String("SHA256", this._pwd . helloResult.salt)
		b64Secret := Hex2Bin(hex)
		b64SecretChallenge := Base64Encode(b64Secret, StrLen(hex) >> 1)

		hex := Hash.String("SHA256", b64SecretChallenge . helloResult.challenge)
		b64Secret := Hex2Bin(hex)
		authentication := Base64Encode(b64Secret, StrLen(hex) >> 1)
		return authentication
	}

	__ReplaceBooleanValuesInJSON(obj) {
		string := JSON.stringify(obj)
		; TODO: check whether this conversion is still needed
		string := StrReplace(string, '"true"', "true")
		string := StrReplace(string, '"false"', "false")
		string := RegExReplace(string, '("(-*\d+\.*\d*)")', "$2")
		return string
	}

	__ConvertUuid(&obj, propName) {
		if (obj.HasOwnProp(propName)) {
			value := obj.%propName%

			; check if name is a uuid
			if (RegExMatch(value, "^[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}$")) {
				obj.DeleteProp(propName)
				propName := StrReplace(propName, "Name","Uuid")
				obj.%propName% := value
			}
		}
	}

	__ConvertAllUuids(&obj) {
		for key in ["sceneName", "sourceName", "inputName", "destinationSceneName", "transitionName", "currentProgramSceneName", "currentPreviewSceneName", "currentSceneTransitionName"] {
			this.__ConvertUuid(&obj, key)
		}
	}

	__GetFunctionName(funcName) {
		return StrReplace(funcName, "OBSWebSocket.Prototype.", "")
	}

	__CreateRequestId() {
		this._requestId := this._requestId + 1
		return this._requestId
	}

	__SendRequestToObs(requestTypeParam := "", requestId := 0, requestData := 0, requestType := 0) {
		if (requestType = 0) {
			requestType := this.__GetFunctionName(requestTypeParam)
		}
		if (!requestId) {
			requestId := this.__CreateRequestId()
		}
		request := { op: OBSWebSocket.WebSocketOpCode.Request, d: { requestType: requestType, requestId: requestId }}
		if (requestData != 0) {
			this.__ConvertAllUuids(&requestData)
			request.d.requestData := requestData
		}

		valueToSend := this.__ReplaceBooleanValuesInJSON(request)
		this.Send(valueToSend)
		if(this._console) {
			this._console.log("Sent:`n" . valueToSend)
		}
	}

	;------------ OBS WebSocket handling messages
	GetVersion(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	GetStats(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	BroadcastCustomEvent(eventData, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, eventData)
	}
	CallVendorRequest(vendorName, requestType, requestData := 0, requestId := 0) {
		data := {vendorName: vendorName, requestType: requestType}
		if (requestData) {
			data.requestData := requestData
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetHotkeyList(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	TriggerHotkeyByName(hotkeyName, contextName := 0, requestId := 0) {
		data := {hotkeyName: hotkeyName}
		if (contextName) {
			data.contextName := contextName
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	TriggerHotkeyByKeySequence(keyId, shiftKey := "false", controlKey := "false", altKey := "false", commandKey := "false", requestId := 0) {
		data := { keyId: keyId, shiftKey: shiftKey, controlKey: controlKey, altKey: altKey, commandKey: commandKey }
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	Sleep(sleepTime, inFrames := "false", requestId := 0) {
		data := { sleepMillis: sleepTime }
		if (inFrames) {
			data := { sleepFrames: sleepTime }
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetPersistentData(realm, slotName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {realm: realm, slotName: slotName})
	}
	SetPersistentData(realm, slotName, slotValue, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {realm: realm, slotName: slotName, slotValue: slotValue})
	}
	GetSceneCollectionList(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	SetCurrentSceneCollection(sceneCollectionName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneCollectionName: sceneCollectionName})
	}
	CreateSceneCollection(sceneCollectionName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneCollectionName: sceneCollectionName})
	}
	GetProfileList(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	SetCurrentProfile(profileName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {profileName: profileName})
	}
	CreateProfile(profileName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {profileName: profileName})
	}
	RemoveProfile(profileName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {profileName: profileName})
	}
	GetProfileParameter(parameterCategory, parameterName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {parameterCategory: parameterCategory, parameterName: parameterName})
	}
	SetProfileParameter(parameterCategory, parameterName, parameterValue, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {parameterCategory: parameterCategory, parameterName: parameterName, parameterValue: parameterValue})
	}
	GetVideoSettings(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	SetVideoSettings(fpsNumerator := 0, fpsDenominator := 0, baseWidth := 0, baseHeight := 0, outputWidth := 0, outputHeight := 0, requestId := 0) {
		data := {}
		if (fpsNumerator > 0) {
			data.fpsNumerator := fpsNumerator
		}
		if (fpsDenominator > 0) {
			data.fpsDenominator := fpsDenominator
		}
		if (baseWidth > 0) {
			data.baseWidth := this.__MinMax(baseWidth, 1, 4096)
		}
		if (baseHeight > 0) {
			data.baseHeight := this.__MinMax(baseHeight, 1, 4096)
		}
		if (outputWidth > 0) {
			data.outputWidth := this.__MinMax(outputWidth, 1, 4096)
		}
		if (outputHeight > 0) {
			data.outputHeight := this.__MinMax(outputHeight, 1, 4096)
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetStreamServiceSettings(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	SetStreamServiceSettings(streamServiceType, streamServiceSettings, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {streamServiceType: streamServiceType, streamServiceSettings: streamServiceSettings})
	}
	GetRecordDirectory(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	SetRecordDirectory(recordDirectory, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {recordDirectory: recordDirectory})
	}
	GetSourceActive(sourceName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName})
	}
	GetSourceScreenshot(sourceName, imageFormat, imageWidth := 0, imageHeight := 0, imageCompressionQuality := 0, requestId := 0) {
		data := {sourceName: sourceName, imageFormat: imageFormat}
		if (imageWidth) {
			data.imageWidth := this.__MinMax(imageWidth, 8, 4096)
		}
		if (imageHeight) {
			data.imageHeight := this.__MinMax(imageHeight, 8, 4096)
		}
		if (imageCompressionQuality) {
			data.imageCompressionQuality := this.MinMax(imageCompressionQuality, -1, 100)
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	SaveSourceScreenshot(sourceName, imageFormat, imageFilePath, imageWidth := 0, imageHeight := 0, imageCompressionQuality := 0, requestId := 0) {
		data := {sourceName: sourceName, imageFormat: imageFormat, imageFilePath: imageFilePath}
		if (imageWidth) {
			data.imageWidth := this.__MinMax(imageWidth, 8, 4096)
		}
		if (imageHeight) {
			data.imageHeight := this.__MinMax(imageHeight, 8, 4096)
		}
		if (imageCompressionQuality) {
			data.imageCompressionQuality := this.MinMax(imageCompressionQuality, -1, 100)
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetSceneList(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	GetGroupList(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	GetCurrentProgramScene(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	SetCurrentProgramScene(sceneName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	GetCurrentPreviewScene(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	SetCurrentPreviewScene(sceneName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	CreateScene(sceneName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	RemoveScene(sceneName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	SetSceneName(sceneName, newSceneName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, newSceneName: newSceneName})
	}
	GetSceneSceneTransitionOverride(sceneName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	SetSceneSceneTransitionOverride(sceneName, transitionName := 0, transitionDuration := 0, requestId := 0) {
		data := {sceneName: sceneName}
		if (transitionName) {
			data.transitionName := transitionName
		}
		if (transitionDuration) {
			data.transitionDuration := this.__MinMax(transitionDuration, 50, 20000)
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetInputList(inputKind := "", requestId := 0) {
		if (inputKind) {
			this.__SendRequestToObs(A_ThisFunc, requestId, {inputKind: inputKind})
		} else {
			this.__SendRequestToObs(A_ThisFunc, requestId)
		}
	}
	GetInputKindList(unversioned := "false", requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {unversioned: unversioned})
	}
	GetSpecialInputs(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	CreateInput(sceneName, inputName, inputKind, inputSettings := 0, sceneItemEnabled := 0, requestId := 0) {
		data := {sceneName: sceneName, inputName: inputName, inputKind: inputKind}
		if (inputSettings) {
			data.inputSettings := inputSettings
		}
		if (sceneItemEnabled) {
			data.sceneItemEnabled := sceneItemEnabled
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	RemoveInput(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputName(inputName, newInputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, newInputName: newInputName})
	}
	GetInputDefaultSettings(inputKind, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputKind: inputKind})
	}
	GetInputSettings(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputSettings(inputName, inputSettings, overlay := 0, requestId := 0) {
		data := {inputName: inputName, inputSettings: inputSettings}
		if (overlay) {
			data.overlay := overlay
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetInputMute(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputMute(inputName, inputMuted, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, inputMuted: inputMuted})
	}
	ToggleInputMute(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	GetInputVolume(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputVolume(inputName, inputVolumeMul:=-200, inputVolumeDb:=-200, requestId := 0) {
		data := {inputName: inputName}
		if (inputVolumeMul != -200) {
			data.inputVolumeMul := this.__MinMax(inputVolumeMul, 0, 20) || 0
		}
		if (inputVolumeDb != -200) {
			data.inputVolumeDb := this.__MinMax(inputVolumeDb, -100, 26)
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetInputAudioBalance(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputAudioBalance(inputName, inputAudioBalance, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, inputAudioBalance: inputAudioBalance})
	}
	GetInputAudioSyncOffset(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputAudioSyncOffset(inputName, inputAudioSyncOffset, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, inputAudioSyncOffset: inputAudioSyncOffset})
	}
	GetInputAudioMonitorType(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputAudioMonitorType(inputName, monitorType, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, monitorType: monitorType})
	}
	GetInputAudioTracks(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputAudioTracks(inputName, inputAudioTracks, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, inputAudioTracks: inputAudioTracks})
	}
	GetInputPropertiesListPropertyItems(inputName, propertyName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, propertyName: propertyName})
	}
	PressInputPropertiesButton(inputName, propertyName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, propertyName: propertyName})
	}
	GetTransitionKindList(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	GetSceneTransitionList(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	GetCurrentSceneTransition(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	SetCurrentSceneTransition(transitionName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {transitionName: transitionName})
	}
	SetCurrentSceneTransitionDuration(transitionDuration, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {transitionDuration: transitionDuration})
	}
	SetCurrentSceneTransitionSettings(transitionSettings, overlay:="true", requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {transitionSettings: transitionSettings, overlay: overlay})
	}
	GetCurrentSceneTransitionCursor(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	TriggerStudioModeTransition(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}	
	SetTBarPosition(position, release:="true", requestId := 0) {
		; Very important note: This will be deprecated and replaced in a future version of obs-websocket.
		this.__SendRequestToObs(A_ThisFunc, requestId, {position: this.__MinMax(position, 0.0, 1.0), release: release})
	}
	GetSourceFilterKindList(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	GetSourceFilterList(sourceName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName})
	}
	GetSourceFilterDefaultSettings(filterKind, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {filterKind: filterKind})
	}
	CreateSourceFilter(sourceName, filterName, filterKind, filterSettings:=0, requestId := 0) {
		data := {sourceName: sourceName, filterName: filterName, filterKind: filterKind}
		if (filterSettings) {
			data.filterSettings := filterSettings
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	RemoveSourceFilter(sourceName, filterName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName, filterName: filterName})
	}
	SetSourceFilterName(sourceName, filterName, newFilterName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName, filterName: filterName, newFilterName: newFilterName})
	}
	GetSourceFilter(sourceName, filterName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName, filterName: filterName})
	}
	SetSourceFilterIndex(sourceName, filterName, filterIndex, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName, filterName: filterName, filterIndex: this.__Max(filterIndex, 0)})
	}
	SetSourceFilterSettings(sourceName, filterName, filterSettings, overlay:="true", requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName, filterName: filterName, filterSettings: filterSettings, overlay: overlay})
	}
	SetSourceFilterEnabled(sourceName, filterName, filterEnabled, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName, filterName: filterName, filterEnabled: filterEnabled})
	}
	GetSceneItemList(sceneName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	GetGroupSceneItemList(sceneName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	GetSceneItemId(sceneName, sourceName, searchOffset := 0, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sourceName: sourceName, searchOffset: this.__Max(searchOffset, -1)})
	}
	GetSceneItemSource(sceneName, sceneItemId, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	CreateSceneItem(sceneName, sourceName, sceneItemEnabled := "true", requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sourceName: sourceName, sceneItemEnabled: sceneItemEnabled})
	}
	RemoveSceneItem(sceneName, sceneItemId, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: this.__Max(0, sceneItemId)})
	}
	DuplicateSceneItem(sceneName, sceneItemId, destinationSceneName := 0, requestId := 0) {
		data := {sceneName: sceneName, sceneItemId: sceneItemId}
		if (destinationSceneName) {
			data.destinationSceneName := destinationSceneName
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetSceneItemTransform(sceneName, sceneItemId, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: this.__Max(0, sceneItemId)})
	}
	SetSceneItemTransform(sceneName, sceneItemId, sceneItemTransform, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: this.__Max(0, sceneItemId), sceneItemTransform: sceneItemTransform})
	}
	GetSceneItemEnabled(sceneName, sceneItemId, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: this.__Max(0, sceneItemId)})
	}
	SetSceneItemEnabled(sceneName, sceneItemId, sceneItemEnabled, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: this.__Max(0, sceneItemId), sceneItemEnabled: sceneItemEnabled})
	}
	GetSceneItemLocked(sceneName, sceneItemId, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: this.__Max(0, sceneItemId)})
	}
	SetSceneItemLocked(sceneName, sceneItemId, sceneItemLocked, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: this.__Max(0, sceneItemId), sceneItemLocked: sceneItemLocked})
	}
	GetSceneItemIndex(sceneName, sceneItemId, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: this.__Max(0, sceneItemId)})
	}
	SetSceneItemIndex(sceneName, sceneItemId, sceneItemIndex, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: this.__Max(0, sceneItemId), sceneItemIndex: sceneItemIndex})
	}
	GetSceneItemBlendMode(sceneName, sceneItemId, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: this.__Max(0, sceneItemId)})
	}
	SetSceneItemBlendMode(sceneName, sceneItemId, sceneItemBlendMode, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: this.__Max(0, sceneItemId), sceneItemBlendMode: sceneItemBlendMode})
	}
	GetVirtualCamStatus(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	ToggleVirtualCam(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	StartVirtualCam(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	StopVirtualCam(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	GetReplayBufferStatus(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	ToggleReplayBuffer(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	StartReplayBuffer(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	StopReplayBuffer(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	SaveReplayBuffer(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	GetLastReplayBufferReplay(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	GetOutputList(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	GetOutputStatus(outputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {outputName: outputName})
	}
	ToggleOutput(outputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {outputName: outputName})
	}
	StartOutput(outputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {outputName: outputName})
	}
	StopOutput(outputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {outputName: outputName})
	}
	GetOutputSettings(outputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {outputName: outputName})
	}
	SetOutputSettings(outputName, outputSettings, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {outputName: outputName, outputSettings: outputSettings})
	}
	GetStreamStatus(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	ToggleStream(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	StartStream(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	StopStream(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	SendStreamCaption(captionText, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {captionText: captionText})
	}
	GetRecordStatus(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	ToggleRecord(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	StartRecord(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	StopRecord(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	ToggleRecordPause(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	PauseRecord(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	ResumeRecord(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	SplitRecordFile(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	CreateRecordChapter(chapterName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {chapterName: chapterName})
	}
	GetMediaInputStatus(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetMediaInputCursor(inputName, mediaCursor, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, mediaCursor: mediaCursor})
	}
	OffsetMediaInputCursor(inputName, mediaCursorOffset, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, mediaCursorOffset: mediaCursorOffset})
	}
	TriggerMediaInputAction(inputName, mediaAction, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, mediaAction: mediaAction})
	}
	GetStudioModeEnabled(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	SetStudioModeEnabled(studioModeEnabled, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {studioModeEnabled: studioModeEnabled})
	}
	OpenInputPropertiesDialog(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	OpenInputFiltersDialog(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	OpenInputInteractDialog(inputName, requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	GetMonitorList(requestId := 0) {
		this.__SendRequestToObs(A_ThisFunc, requestId)
	}
	OpenVideoMixProjector(videoMixType, monitorIndex := -2, projectorGeometry := 0, requestId := 0) {
		data := {videoMixType: videoMixType}
		if (monitorIndex > -2) {
			data.monitorIndex := monitorIndex
		}
		if (projectorGeometry) {
			data.projectorGeometry := projectorGeometry
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}
	OpenSourceProjector(sourceName, monitorIndex := -2, projectorGeometry := "", requestId := 0) {
		data := {sourceName: sourceName}
		if (monitorIndex > -2) {
			data.monitorIndex := monitorIndex
		}
		if (projectorGeometry) {
			data.projectorGeometry := projectorGeometry
		}
		this.__SendRequestToObs(A_ThisFunc, requestId, data)
	}

	; Extra implementations which are not in OBSProject

	; get all the scene items and group items under one scene (groups have to be requested separately)
	__GetFullSceneItemListResponseData := 0 ; full response data this script will emit
	__GetFullSceneItemListWaitingForResponse := Map() ; housekeeping about sent and received messages
	GetFullSceneItemList(sceneName, requestId := 0) {
		this.__GetFullSceneItemListWaitingForResponse[sceneName] := 1
		this.GetSceneItemList(sceneName, "__" . sceneName . "#" . requestId)
	}
	__GetSceneItemListResponse(data) {
		this.__handleGetFullSceneItemListResponses(data)
	}

	__GetGroupSceneItemListResponse(data) {
		this.__handleGetFullSceneItemListResponses(data)
	}

	__handleGetFullSceneItemListResponses(data) {
		; 3 is the position after __ and length of __ and # (faster than to use regexp)
		sceneName := SubStr(data.d.requestId, 3, InStr(data.d.requestId, "#") - 3)
		requestId := SubStr(data.d.requestId, InStr(data.d.requestId, "#") + 1)
		this.__GetFullSceneItemListWaitingForResponse.Delete(sceneName)

		For Key, sceneItemData in data.d.responseData.sceneItems {
			sceneItemData.sceneName := sceneName
			if (sceneItemData.isGroup = 1) {
				this.__GetFullSceneItemListWaitingForResponse[sceneItemData.sourceName] := 1
				this.GetGroupSceneItemList(sceneItemData.sourceName, "__" . sceneItemData.sourceName . "#" . requestId)
			}
		}

		if (!this.__GetFullSceneItemListResponseData) {
			this.__GetFullSceneItemListResponseData := data
		} else {
			For Key, sceneItemData in data.d.responseData.sceneItems
			{
				this.__GetFullSceneItemListResponseData.d.responseData.sceneItems.push(sceneItemData)
			}
		}
		if (this.__GetFullSceneItemListWaitingForResponse.Count = 0) {
			this.__CallFunction("GetFullSceneItemListResponse", this.__GetFullSceneItemListResponseData)
		}
	}
}

; ---------- UTILITIES
class DebugConsole {

	__New(control := 0) {
		if (control) {
			this.Textarea := control
		} else {
			this.DebugGui := Gui("+Resize")
			this.Textarea := this.DebugGui.AddEdit("w400 h600")
			this.DebugGui.Show
			this.DebugGui.Title := "OBSWebSocketAHK messages (beta)"
		}
	}
	
	log(newText) {
		NewLine := "`n-------------------------------------------------------------------------`n"
		this.Textarea.value := newText . NewLine . this.Textarea.value
	}

}

MapToObject(mapPart) {
	objPart := {}
	For Key, Value in mapPart {
		if (Value.base.__Class = "Map") {
			objPart.%key% := MapToObject(Value)
		} else if (Value.base.__Class = "Array") {
			objPart.%key% := MapToArray(Value)
		} else {
			objPart.%key% := Value
		}
	}
	return objPart
}

MapToArray(mapPart) {
	arrPart := []
	For Key, Value in mapPart {
		if (Value.base.__Class = "Map") {
			arrPart.Push(MapToObject(Value))
		} else if (Value.base.__Class = "Array") {
			arrPart.Push(MapToArray(Value))
		} else {
			arrPart.Push(Value)
		}
	}
	return arrPart
}

Hex2Bin(hex) {
	inLength := StrLen(hex)
	outLength := inLength >> 1
	out := ""
	VarSetStrCapacity(&out, outLength)
	DllCall("Crypt32.dll\CryptStringToBinary", "Ptr", StrPtr(hex), "UInt", inLength, "UInt", 0x8, "Str", out, "UInt*", outLength, "Ptr", 0, "Ptr", 0)
	return out
}

Base64Encode(text, inLength) {
	outLength := inLength << 1
	out := ""
	VarSetStrCapacity(&out, outLength)
	DllCall("Crypt32\CryptBinaryToStringW", "Ptr", StrPtr(text), "UInt", inLength, "UInt", 0x40000001, "Str", out, "UInt*", outLength)
	return out
}
