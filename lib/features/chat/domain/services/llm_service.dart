
/// Represents an action parsed from the LLM response.
class LlmAction {
  final String type;
  final Map<String, dynamic> params;

  LlmAction({
    required this.type,
    required this.params,
  });

  factory LlmAction.fromJson(Map<String, dynamic> json) {
    return LlmAction(
      type: json['type'] as String? ?? '',
      params: Map<String, dynamic>.from(json['params'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'params': params,
      };

  @override
  String toString() => 'LlmAction(type: $type, params: $params)';
}

/// Represents the structured response from the LLM containing a text message
/// and an optional list of executable actions.
class LlmResponse {
  final String message;
  final List<LlmAction> actions;
  final String provider; // 'gemini' or 'local'

  LlmResponse({
    required this.message,
    required this.actions,
    required this.provider,
  });

  factory LlmResponse.fromJson(Map<String, dynamic> json, {String provider = 'local'}) {
    final rawActions = json['actions'] as List? ?? [];
    final actionsList = rawActions
        .map((a) => LlmAction.fromJson(Map<String, dynamic>.from(a as Map)))
        .toList();

    return LlmResponse(
      message: json['message'] as String? ?? '',
      actions: actionsList,
      provider: provider,
    );
  }

  Map<String, dynamic> toJson() => {
        'message': message,
        'actions': actions.map((a) => a.toJson()).toList(),
        'provider': provider,
      };

  @override
  String toString() => 'LlmResponse(provider: $provider, message: $message, actions: $actions)';
}

/// Abstract contract for LLM communication.
abstract class LlmService {
  /// Generates a structured response from the user prompt.
  ///
  /// [message] is the current user input.
  /// [history] is the list of previous chat messages (role: user/model).
  /// [systemContext] is additional contextual information (like list of alarms, logs, etc.).
  Future<LlmResponse> generateResponse(
    String message, {
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? systemContext,
  });
}
