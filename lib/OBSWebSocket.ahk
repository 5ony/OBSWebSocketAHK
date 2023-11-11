/**
 * Lib: OBSWebSocket.ahk
 *     OBS Studio WebScocket library for AutoHotkey
 * Version:
 *     v1.1.1 [updated 2023-11-10 (YYYY-MM-DD)]
 * Requirements:
 *     AutoHotkey v1.1+
 *     WebSocket.ahk - https://github.com/G33kDude/WebSocket.ahk
 *     JSON.ahk - https://github.com/cocobelgica/AutoHotkey-JSON
 *     libcrypt.ahk - https://github.com/ahkscript/libcrypt.ahk
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
	_requestId := 1 ; a simple id
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
		if (value.op = this.WebSocketOpCode.RequestResponse) {
			if (value.d.requestStatus.code != this.RequestStatus.Success) {
				MsgBox, % "Error, RequestStatus " value.d.requestStatus.code " | " value.d.requestStatus.comment
				return
			}
			; if the requestId starts with __, then it is an "internal" call
			if (InStr(value.d.requestId,"__") = 1) {
				this["__" . value.d.requestType . "Response"](value)	
			} else {				
				this[value.d.requestType . "Response"](value)
			}
		} else if (value.op = this.WebSocketOpCode.Event) {
			this[value.d.eventType . "Event"](value)
		} else if (value.op = this.WebSocketOpCode.Hello) {
			this._rpcVersion := value.d.rpcVersion

			helloAnswer := {op: this.WebSocketOpCode.Identify,d: {rpcVersion: this._rpcVersion, eventSubscriptions: this._eventSubscriptions}}
			if (value.d.authentication) {
				helloAnswer.d.authentication := this.__GenerateSecretHash(value.d.authentication)
			}
			this.Send(this.__ReplaceBooleanValuesInJSON(helloAnswer))
		} else if (value.op = this.WebSocketOpCode.Identified) {
			this["AfterIdentified"]()
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
		string := RegExReplace(string, "(""(-*\d+\.*\d*)"")", "$2")
		return string
	}

	__GetFunctionName(funcName) {
		return StrReplace(funcName, "OBSWebSocket.", "")
	}

	Boolean(booleanValue) {
 		return booleanValue ? "true" : "false"
	}

	SendRequestToObs(requestTypeParam := "", requestId := 0, requestData := 0, requestType := 0) {
		if (requestType = 0) {
			requestType := this.__GetFunctionName(requestTypeParam)
		}
		if (!requestId) {
			requestId := this.GetRequestId()
		}
		request := { op: this.WebSocketOpCode.Request, d: { requestType: requestType, requestId: requestId }}
		if (requestData != 0) {
			request.d.requestData := requestData
		}
		this.Send(this.__ReplaceBooleanValuesInJSON(request))
	}

	GetRequestId() {
		this._requestId := this._requestId + 1
		return this._requestId
	}

	;------------ OBS WebSocket handling messages
	GetVersion(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	GetStats(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	BroadcastCustomEvent(eventData, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, eventData)
	}
	CallVendorRequest(vendorName, requestType, requestData := 0, requestId := 0) {
		data := {vendorName: vendorName, requestType: requestType}
		if (requestData) {
			data.requestData := requestData
		}
		this.SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetHotkeyList(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	TriggerHotkeyByName(hotkeyName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {hotkeyName: hotkeyName})
	}
	TriggerHotkeyByKeySequence(keyId, shiftKey := "false", controlKey := "false", altKey := "false", commandKey := "false", requestId := 0) {
		data := { keyId: keyId, shiftKey: shiftKey, controlKey: controlKey, altKey: altKey, commandKey: commandKey }
		this.SendRequestToObs(A_ThisFunc, requestId, data)
	}
	Sleep(sleepTime, inFrames := "false", requestId := 0) {
		data := { sleepMillis: sleepTime }
		if (inFrames) {
			data := { sleepFrames: sleepTime }
		}
		this.SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetPersistentData(realm, slotName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {realm: realm, slotName: slotName})
	}
	SetPersistentData(realm, slotName, slotValue, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {realm: realm, slotName: slotName, slotValue: slotValue})
	}
	GetSceneCollectionList(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	SetCurrentSceneCollection(sceneCollectionName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneCollectionName: sceneCollectionName})
	}
	CreateSceneCollection(sceneCollectionName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneCollectionName: sceneCollectionName})
	}
	GetProfileList(currentProfileName, profiles, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {currentProfileName: currentProfileName, profiles: profiles})
	}
	SetCurrentProfile(profileName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {profileName: profileName})
	}
	CreateProfile(profileName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {profileName: profileName})
	}
	RemoveProfile(profileName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {profileName: profileName})
	}
	GetProfileParameter(parameterCategory, parameterName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {parameterCategory: parameterCategory, parameterName: parameterName})
	}
	SetProfileParameter(parameterCategory, parameterName, parameterValue, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {parameterCategory: parameterCategory, parameterName: parameterName, parameterValue: parameterValue})
	}
	GetVideoSettings(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
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
		this.SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetStreamServiceSettings(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	SetStreamServiceSettings(streamServiceType, streamServiceSettings, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {streamServiceType: streamServiceType, streamServiceSettings: streamServiceSettings})
	}
	GetRecordDirectory(recordDirectory, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {recordDirectory: recordDirectory})
	}
	GetSourceActive(sourceName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName})
	}
	GetSourceScreenshot(sourceName, imageFormat, imageWidth := 0, imageHeight := 0, imageCompressionQuality := 0, requestId := 0) {
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
		this.SendRequestToObs(A_ThisFunc, requestId, data)
	}
	SaveSourceScreenshot(sourceName, imageFormat, imageFilePath, imageWidth := 0, imageHeight := 0, imageCompressionQuality := 0, requestId := 0) {
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
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	GetSceneList(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	GetGroupList(groups, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {groups: groups})
	}
	GetCurrentProgramScene(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	SetCurrentProgramScene(sceneName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	GetCurrentPreviewScene(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	SetCurrentPreviewScene(sceneName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	CreateScene(sceneName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	RemoveScene(sceneName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	SetSceneName(sceneName, newSceneName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, newSceneName: newSceneName})
	}
	GetSceneSceneTransitionOverride(sceneName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	SetSceneSceneTransitionOverride(sceneName, transitionName := 0, transitionDuration := 0, requestId := 0) {
		data := {sceneName: sceneName}
		if (transitionName) {
			data.transitionName := transitionName
		}
		if (transitionDuration) {
			data.transitionDuration := transitionDuration
		}
		this.SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetInputList(inputKind := "", requestId := 0) {
		if (inputKind) {
			this.SendRequestToObs(A_ThisFunc, requestId, {inputKind: inputKind})
		} else {
			this.SendRequestToObs(A_ThisFunc, requestId)
		}
	}
	GetInputKindList(unversioned := "false", requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {unversioned: unversioned})
	}
	GetSpecialInputs(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	CreateInput(sceneName, inputName, inputKind, inputSettings := 0, sceneItemEnabled := 0, requestId := 0) {
		data := {sceneName: sceneName, inputName: inputName, inputKind: inputKind}
		if (inputSettings) {
			data.inputSettings := inputSettings
		}
		if (sceneItemEnabled) {
			data.sceneItemEnabled := sceneItemEnabled
		}
		this.SendRequestToObs(A_ThisFunc, requestId, data)
	}
	RemoveInput(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputName(inputName, newInputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, newInputName: newInputName})
	}
	GetInputDefaultSettings(inputKind, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputKind: inputKind})
	}
	GetInputSettings(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputSettings(inputName, inputSettings, overlay := 0, requestId := 0) {
		data := {inputName: inputName, inputSettings: inputSettings}
		if (overlay) {
			data.overlay := overlay
		}
		this.SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetInputMute(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputMute(inputName, inputMuted, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, inputMuted: inputMuted})
	}
	ToggleInputMute(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	GetInputVolume(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputVolume(inputName, inputVolumeMul:=-1, inputVolumeDb:=0, requestId := 0) {
		data := {inputName: inputName}
		if (inputVolumeMul > -1) {
			data.inputVolumeMul := inputVolumeMul
		}
		if (inputVolumeDb) {
			data.inputVolumeDb := inputVolumeDb
		}
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	GetInputAudioBalance(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputAudioBalance(inputName, inputAudioBalance, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, inputAudioBalance: inputAudioBalance})
	}
	GetInputAudioSyncOffset(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputAudioSyncOffset(inputName, inputAudioSyncOffset, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, inputAudioSyncOffset: inputAudioSyncOffset})
	}
	GetInputAudioMonitorType(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputAudioMonitorType(inputName, monitorType, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, monitorType: monitorType})
	}
	GetInputAudioTracks(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetInputAudioTracks(inputName, inputAudioTracks, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, inputAudioTracks: inputAudioTracks})
	}
	GetInputPropertiesListPropertyItems(inputName, propertyName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, propertyName: propertyName})
	}
	PressInputPropertiesButton(inputName, propertyName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, propertyName: propertyName})
	}
	GetTransitionKindList(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	GetSceneTransitionList(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	GetCurrentSceneTransition(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	SetCurrentSceneTransition(transitionName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {transitionName: transitionName})
	}
	SetCurrentSceneTransitionDuration(transitionDuration, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {transitionDuration: transitionDuration})
	}
	SetCurrentSceneTransitionSettings(transitionSettings, overlay:="true", requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {transitionSettings: transitionSettings, overlay: overlay})
	}
	GetCurrentSceneTransitionCursor(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	TriggerStudioModeTransition(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	SetTBarPosition(position, release:="true", requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {position: position, release: release})
	}
	GetSourceFilterList(sourceName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName})
	}
	GetSourceFilterDefaultSettings(filterKind, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {filterKind: filterKind})
	}
	CreateSourceFilter(sourceName, filterName, filterKind, filterSettings:=0, requestId := 0) {
		data := {sourceName: sourceName, filterName: filterName, filterKind: filterKind}
		if (filterSettings) {
			data.filterSettings := filterSettings
		}
		this.SendRequestToObs(A_ThisFunc, requestId, data)
	}
	RemoveSourceFilter(sourceName, filterName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName, filterName: filterName})
	}
	SetSourceFilterName(sourceName, filterName, newFilterName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName, filterName: filterName, newFilterName: newFilterName})
	}
	GetSourceFilter(sourceName, filterName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName, filterName: filterName})
	}
	SetSourceFilterIndex(sourceName, filterName, filterIndex, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName, filterName: filterName, filterIndex: filterIndex})
	}
	SetSourceFilterSettings(sourceName, filterName, filterSettings, overlay:="true", requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName, filterName: filterName, filterSettings: filterSettings, overlay: overlay})
	}
	SetSourceFilterEnabled(sourceName, filterName, filterEnabled, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sourceName: sourceName, filterName: filterName, filterEnabled: filterEnabled})
	}
	GetSceneItemList(sceneName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	GetGroupSceneItemList(sceneName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName})
	}
	GetSceneItemId(sceneName, sourceName, searchOffset := 0, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sourceName: sourceName, searchOffset: searchOffset})
	}
	CreateSceneItem(sceneName, sourceName, sceneItemEnabled := "true", requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sourceName: sourceName, sceneItemEnabled: sceneItemEnabled})
	}
	RemoveSceneItem(sceneName, sceneItemId, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	DuplicateSceneItem(sceneName, sceneItemId, destinationSceneName := 0, requestId := 0) {
		data := {sceneName: sceneName, sceneItemId: sceneItemId}
		if (destinationSceneName) {
			data.destinationSceneName := destinationSceneName
		}
		this.SendRequestToObs(A_ThisFunc, requestId, data)
	}
	GetSceneItemTransform(sceneName, sceneItemId, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	SetSceneItemTransform(sceneName, sceneItemId, sceneItemTransform, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: sceneItemId, sceneItemTransform: sceneItemTransform})
	}
	GetSceneItemEnabled(sceneName, sceneItemId, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	SetSceneItemEnabled(sceneName, sceneItemId, sceneItemEnabled, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: sceneItemId, sceneItemEnabled: sceneItemEnabled})
	}
	GetSceneItemLocked(sceneName, sceneItemId, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	SetSceneItemLocked(sceneName, sceneItemId, sceneItemLocked, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: sceneItemId, sceneItemLocked: sceneItemLocked})
	}
	GetSceneItemIndex(sceneName, sceneItemId, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	SetSceneItemIndex(sceneName, sceneItemId, sceneItemIndex, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: sceneItemId, sceneItemIndex: sceneItemIndex})
	}
	GetSceneItemBlendMode(sceneName, sceneItemId, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: sceneItemId})
	}
	SetSceneItemBlendMode(sceneName, sceneItemId, sceneItemBlendMode, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {sceneName: sceneName, sceneItemId: sceneItemId, sceneItemBlendMode: sceneItemBlendMode})
	}
	GetVirtualCamStatus(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	ToggleVirtualCam(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	StartVirtualCam(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	StopVirtualCam(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	GetReplayBufferStatus(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	ToggleReplayBuffer(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	StartReplayBuffer(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	StopReplayBuffer(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	SaveReplayBuffer(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	GetLastReplayBufferReplay(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	GetOutputList(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	GetOutputStatus(outputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {outputName: outputName})
	}
	ToggleOutput(outputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {outputName: outputName})
	}
	StartOutput(outputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {outputName: outputName})
	}
	StopOutput(outputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {outputName: outputName})
	}
	GetOutputSettings(outputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {outputName: outputName})
	}
	SetOutputSettings(outputName, outputSettings, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {outputName: outputName, outputSettings: outputSettings})
	}
	GetStreamStatus(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	ToggleStream(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	StartStream(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	StopStream(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	SendStreamCaption(captionText, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {captionText: captionText})
	}
	GetRecordStatus(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	ToggleRecord(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	StartRecord(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	StopRecord(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	ToggleRecordPause(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	PauseRecord(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	ResumeRecord(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	GetMediaInputStatus(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	SetMediaInputCursor(inputName, mediaCursor, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, mediaCursor: mediaCursor})
	}
	OffsetMediaInputCursor(inputName, mediaCursorOffset, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, mediaCursorOffset: mediaCursorOffset})
	}
	TriggerMediaInputAction(inputName, mediaAction, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName, mediaAction: mediaAction})
	}
	GetStudioModeEnabled(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	SetStudioModeEnabled(studioModeEnabled, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {studioModeEnabled: studioModeEnabled})
	}
	OpenInputPropertiesDialog(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	OpenInputFiltersDialog(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	OpenInputInteractDialog(inputName, requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId, {inputName: inputName})
	}
	GetMonitorList(requestId := 0) {
		this.SendRequestToObs(A_ThisFunc, requestId)
	}
	OpenVideoMixProjector(videoMixType, monitorIndex := -2, projectorGeometry := 0, requestId := 0) {
		data := {videoMixType: videoMixType}
		if (monitorIndex > -2) {
			data.monitorIndex := monitorIndex
		}
		if (projectorGeometry) {
			data.projectorGeometry := projectorGeometry
		}
		this.SendRequestToObs(A_ThisFunc, requestId, data)
	}
	OpenSourceProjector(sourceName, monitorIndex := -2, projectorGeometry := 0, requestId := 0) {
		data := {sourceName: sourceName}
		if (monitorIndex > -2) {
			data.monitorIndex := monitorIndex
		}
		if (projectorGeometry) {
			data.projectorGeometry := projectorGeometry
		}
		this.SendRequestToObs(A_ThisFunc, requestId)
	}

	; Implementations which are not in OBSProject

	; get all the scene items and group items under one scene (groups have to be requested separately)
	__GetFullSceneItemListResponseData := 0 ; full response data this script will emit
	__GetFullSceneItemListWaitingForResponse := {} ; housekeeping about sent and received messages
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
		if (this.__GetFullSceneItemListWaitingForResponse.Count() = 0) {
			this["GetFullSceneItemListResponse"](this.__GetFullSceneItemListResponseData)
		}
	}
}
