// Processes Server-Sent Event (SSE) chunks inside TargetEndpoint EventFlow (ES5/Rhino).
context.setVariable("flow.stream_done", "false");
context.setVariable("flow.stream_buff_ready", "false");
context.removeVariable("flow.stream_partial_text");

try {
  var rawContent = context.getVariable("response.event.current.content") || "";
  if (rawContent) {
    var lines = String(rawContent).split(/\r?\n/);
    var chunkText = "";
    var isFinished = false;

    for (var l = 0; l < lines.length; l++) {
      var trimmed = lines[l].trim();
      if (trimmed.indexOf("data:") !== 0) {
        continue;
      }
      var payloadStr = trimmed.substring(5).trim();
      if (!payloadStr || payloadStr === "[DONE]") {
        continue;
      }

      var parsed = null;
      try {
        parsed = JSON.parse(payloadStr);
      } catch (e) {
        continue;
      }
      if (!parsed || typeof parsed !== "object") {
        continue;
      }

      if (parsed.candidates && Array.isArray(parsed.candidates) && parsed.candidates.length > 0) {
        var cand = parsed.candidates[0];
        if (cand && cand.content && cand.content.parts && Array.isArray(cand.content.parts)) {
          for (var p = 0; p < cand.content.parts.length; p++) {
            if (cand.content.parts[p] && cand.content.parts[p].text) {
              chunkText += cand.content.parts[p].text;
            }
          }
        }
        if (cand && cand.finishReason) {
          isFinished = true;
        }
      }

      if (parsed.usageMetadata) {
        var pTok = parsed.usageMetadata.promptTokenCount || 0;
        var cTok = parsed.usageMetadata.candidatesTokenCount || 0;
        var tTok = parsed.usageMetadata.totalTokenCount || (pTok + cTok);
        if (tTok > 0) {
          context.setVariable("flow.promptTokenCount", String(pTok));
          context.setVariable("flow.candidatesTokenCount", String(cTok));
          context.setVariable("flow.totalTokenCount", String(tTok));
        }
      }
    }

    if (chunkText) {
      var prev = context.getVariable("flow.responseText") || "";
      context.setVariable("flow.responseText", prev + chunkText);
      context.setVariable("flow.stream_partial_text", chunkText);
      context.setVariable("flow.stream_buff_ready", "true");
    }

    if (isFinished && context.getVariable("flow.totalTokenCount")) {
      context.setVariable("flow.stream_done", "true");
    }
  }
} catch (err) {
  // Never break SSE streaming on telemetry parsing errors
}
