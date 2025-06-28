import 'package:flutter/material.dart';
import 'package:my_app/eider/services/api_service.dart';

enum RequestState {
  idle,
  recording,
  loading,
  incomplete,
  success,
  error,
}

class RequestViewModel extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  RequestState _state = RequestState.idle;
  String? _pendingRequestId;
  String? _clarificationPrompt;
  String? _errorMessage;

  RequestState get state => _state;
  String? get pendingRequestId => _pendingRequestId;
  String? get clarificationPrompt => _clarificationPrompt;
  String? get errorMessage => _errorMessage;

  void _setState(RequestState newState) {
    print("✅ [ViewModel] State changing from '$_state' to '$newState'");
    _state = newState;
    notifyListeners();
  }

  Future<void> processInitialRequest(String userId, String audioFilePath) async {
    print("✅ [ViewModel] Starting initial request process.");
    _setState(RequestState.loading);
    try {
      final response = await _apiService.sendInitialVoiceRequest(
        userId: userId,
        audioFilePath: audioFilePath,
      );
      print("✅ [ViewModel] Received response for initial request: $response");

      if (response['status'] == 'success') {
        _setState(RequestState.success);
      } else if (response['status'] == 'incomplete') {
        _pendingRequestId = response['pending_request_id'];
        _clarificationPrompt = response['clarification_prompt_text'];
        _setState(RequestState.incomplete);
        print("✅ [ViewModel] Prompt for user: $_clarificationPrompt");
      } else {
        throw Exception('Unknown server response status.');
      }
    } catch (e) {
      _errorMessage = e.toString();
      _setState(RequestState.error);
      print("❌ [ViewModel] Error during initial request: $_errorMessage");
    }
  }

  Future<void> processContinuationRequest(String userId, String audioFilePath) async {
    print("✅ [ViewModel] Starting continuation request process.");
    if (_pendingRequestId == null) {
      _errorMessage = "Missing pending_request_id for continuation.";
      _setState(RequestState.error);
      print("❌ [ViewModel] Error: $_errorMessage");
      return;
    }

    _setState(RequestState.loading);
    try {
      final response = await _apiService.sendContinuationVoiceRequest(
        userId: userId,
        audioFilePath: audioFilePath,
        pendingRequestId: _pendingRequestId!,
      );
      print("✅ [ViewModel] Received response for continuation request: $response");

      if (response['status'] == 'success') {
        _pendingRequestId = null;
        _clarificationPrompt = null;
        _setState(RequestState.success);
      } else if (response['status'] == 'incomplete') {
        _pendingRequestId = response['pending_request_id'];
        _clarificationPrompt = response['clarification_prompt_text'];
        _setState(RequestState.incomplete);
        print("✅ [ViewModel] New prompt for user: $_clarificationPrompt");
      } else {
        throw Exception('Unknown server response status.');
      }
    } catch (e) {
      _errorMessage = e.toString();
      _setState(RequestState.error);
      print("❌ [ViewModel] Error during continuation request: $_errorMessage");
    }
  }

  void reset() {
    print("✅ [ViewModel] Resetting state to idle.");
    _pendingRequestId = null;
    _clarificationPrompt = null;
    _errorMessage = null;
    _setState(RequestState.idle);
  }
}