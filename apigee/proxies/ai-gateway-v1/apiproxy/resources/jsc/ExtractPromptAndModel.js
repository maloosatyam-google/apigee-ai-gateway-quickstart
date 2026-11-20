// Extract prompt and model from Vertex AI Gemini request payload (ES5/Rhino)
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
    var prompt = "";

    if (payload.contents && Array.isArray(payload.contents) && payload.contents.length > 0) {
      var lastContent = payload.contents[payload.contents.length - 1];
      if (lastContent && lastContent.parts && Array.isArray(lastContent.parts)) {
        var partsText = [];
        for (var p = 0; p < lastContent.parts.length; p++) {
          if (lastContent.parts[p] && lastContent.parts[p].text) {
            partsText.push(lastContent.parts[p].text);
          }
        }
        prompt = partsText.join(" ");
      }
    } else if (payload.prompt) {
      prompt = (typeof payload.prompt === "string") ? payload.prompt : JSON.stringify(payload.prompt);
    }

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
