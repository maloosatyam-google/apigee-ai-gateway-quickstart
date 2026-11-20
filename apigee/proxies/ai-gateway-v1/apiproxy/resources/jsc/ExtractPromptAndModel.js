// Extract prompt (across all turns + systemInstruction) and model from Vertex AI Gemini request (ES5/Rhino)
var pathSuffix = context.getVariable("proxy.pathsuffix") || "";
var altParam = String(context.getVariable("request.queryparam.alt") || "").toLowerCase();
var isStreaming = /:streamGenerateContent$/i.test(pathSuffix) || altParam === "sse";

context.setVariable("flow.is_streaming", isStreaming ? "true" : "false");
context.setVariable("flow.gemini_method", isStreaming ? "streamGenerateContent?alt=sse" : "generateContent");

var extractedModel = context.getVariable("flow.model");
if (extractedModel) {
  var modelName = String(extractedModel).split(":")[0];
  context.setVariable("flow.model", modelName);
  context.setVariable("flow.target_model", modelName);
}

var reqContent = context.getVariable("request.content") || "";
if (reqContent) {
  try {
    var payload = JSON.parse(reqContent);
    var promptChunks = [];

    if (payload.systemInstruction && payload.systemInstruction.parts && Array.isArray(payload.systemInstruction.parts)) {
      for (var s = 0; s < payload.systemInstruction.parts.length; s++) {
        if (payload.systemInstruction.parts[s] && payload.systemInstruction.parts[s].text) {
          promptChunks.push(payload.systemInstruction.parts[s].text);
        }
      }
    }

    if (payload.contents && Array.isArray(payload.contents)) {
      for (var c = 0; c < payload.contents.length; c++) {
        var turn = payload.contents[c];
        if (turn && turn.parts && Array.isArray(turn.parts)) {
          for (var p = 0; p < turn.parts.length; p++) {
            if (turn.parts[p] && turn.parts[p].text) {
              promptChunks.push(turn.parts[p].text);
            }
          }
        }
      }
    } else if (payload.prompt) {
      promptChunks.push((typeof payload.prompt === "string") ? payload.prompt : JSON.stringify(payload.prompt));
    }

    var prompt = promptChunks.join("\n").trim();
    if (prompt) {
      context.setVariable("flow.userPrompt", prompt);
    }

    if (payload.model && !context.getVariable("flow.model")) {
      context.setVariable("flow.model", payload.model);
      context.setVariable("flow.target_model", payload.model);
    }
  } catch (e) {
    // Non-JSON or parsing error; continue flow
  }
}
