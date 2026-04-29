// CodexAPI Proxy v3 - Streaming + Tool Support
// Translates Codex /responses → 9router /chat/completions (streaming)
const http = require('http');

const REAL_HOST = '20.196.67.130';
const REAL_PORT = 20128;
const LOCAL_PORT = 20129;
const API_KEY = '<API_KEY_CỦA_BẠN>';

const VALID_MODELS = [
  { id: 'gpt-5.5',           full: 'cx/gpt-5.5' },
  { id: 'gpt-5.4',           full: 'cx/gpt-5.4' },
  { id: 'gpt-5.3-codex',     full: 'cx/gpt-5.3-codex' },
  { id: 'gpt-5.3-codex-high',full: 'cx/gpt-5.3-codex-high' },
  { id: 'gpt-5.2',           full: 'cx/gpt-5.2' },
  { id: 'gpt-5.1',           full: 'cx/gpt-5.1-codex-mini' },
  { id: 'gpt-5',             full: 'cx/gpt-5.5' },
  { id: 'o3',                full: 'cx/gpt-5.3-codex-xhigh' },
  { id: 'o3-mini',           full: 'cx/gpt-5.3-codex-high' },
  { id: 'o4-mini',           full: 'cx/gpt-5.3-codex-high' },
  { id: 'grok-4',            full: 'xai/grok-4' },
  { id: 'grok-3',            full: 'xai/grok-3' },
  { id: 'gemini-2.5-pro',    full: 'gemini/gemini-2.5-pro' },
];

function mapModel(model) {
  if (model.includes('/')) return model;
  const found = VALID_MODELS.find(m => m.id === model);
  return found ? found.full : 'cx/gpt-5.5';
}

// ═══════════════════════════════════════════
// INPUT CONVERSION
// ═══════════════════════════════════════════

function convertInputToMessages(input) {
  if (!Array.isArray(input)) return [{ role: 'user', content: String(input) }];
  const messages = [];
  for (const item of input) {
    if (item.type === 'function_call_output') {
      messages.push({
        role: 'tool',
        tool_call_id: item.call_id,
        content: typeof item.output === 'string' ? item.output : JSON.stringify(item.output)
      });
    } else if (item.type === 'function_call') {
      const toolCall = {
        id: item.call_id || item.id || `call_${Date.now()}`,
        type: 'function',
        function: { name: item.name, arguments: typeof item.arguments === 'string' ? item.arguments : JSON.stringify(item.arguments) }
      };
      const last = messages[messages.length - 1];
      if (last && last.role === 'assistant' && last.tool_calls) {
        last.tool_calls.push(toolCall);
      } else {
        messages.push({ role: 'assistant', content: null, tool_calls: [toolCall] });
      }
    } else {
      const role = item.role || 'user';
      let content = '';
      if (Array.isArray(item.content)) {
        content = item.content.map(c => typeof c === 'string' ? c : (c.text || JSON.stringify(c))).join('');
      } else {
        content = item.content || '';
      }
      messages.push({ role, content });
    }
  }
  return messages;
}

function convertTools(tools) {
  if (!tools || !Array.isArray(tools) || tools.length === 0) return undefined;
  const converted = [];
  for (const tool of tools) {
    if (tool.type === 'function') {
      converted.push({
        type: 'function',
        function: tool.function || { name: tool.name, description: tool.description || '', parameters: tool.parameters || { type: 'object', properties: {} } }
      });
    } else if (tool.name) {
      converted.push({
        type: 'function',
        function: { name: tool.name, description: tool.description || '', parameters: tool.parameters || tool.input_schema || { type: 'object', properties: {} } }
      });
    }
  }
  return converted.length > 0 ? converted : undefined;
}

// ═══════════════════════════════════════════
// SSE HELPERS
// ═══════════════════════════════════════════

function sseEvent(event, data) {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

// ═══════════════════════════════════════════
// STREAMING HANDLER
// ═══════════════════════════════════════════

function handleStreamingResponse(model, messages, tools, clientRes) {
  const payload = { model, messages, max_tokens: 8096, stream: true };
  if (tools) { payload.tools = tools; payload.tool_choice = 'auto'; }
  
  const body = JSON.stringify(payload);
  const respId = `resp_${Date.now()}`;
  const msgId = `msg_${Date.now()}`;
  let seq = 0;
  let headersSent = false;
  let fullText = '';
  let toolCalls = {}; // indexed by tool call index
  let hasToolCalls = false;
  let headerWritten = false;
  let buffer = '';

  function sendHeaders() {
    if (headerWritten) return;
    headerWritten = true;
    clientRes.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Transfer-Encoding': 'chunked'
    });
    // Send response.created
    clientRes.write(sseEvent('response.created', {
      type: 'response.created', sequence_number: seq++,
      response: { id: respId, object: 'response', created_at: Math.floor(Date.now()/1000), status: 'in_progress', model }
    }));
  }

  function sendTextStart() {
    if (headersSent) return;
    headersSent = true;
    sendHeaders();
    clientRes.write(sseEvent('response.output_item.added', {
      type: 'response.output_item.added', sequence_number: seq++, output_index: 0,
      item: { type: 'message', id: msgId, status: 'in_progress', role: 'assistant', content: [] }
    }));
    clientRes.write(sseEvent('response.content_part.added', {
      type: 'response.content_part.added', sequence_number: seq++, output_index: 0, content_index: 0,
      part: { type: 'output_text', text: '' }
    }));
  }

  function sendTextDelta(delta) {
    sendTextStart();
    fullText += delta;
    clientRes.write(sseEvent('response.output_text.delta', {
      type: 'response.output_text.delta', sequence_number: seq++, output_index: 0, content_index: 0, delta
    }));
  }

  function finishText() {
    sendTextStart();
    clientRes.write(sseEvent('response.output_text.done', {
      type: 'response.output_text.done', sequence_number: seq++, output_index: 0, content_index: 0, text: fullText
    }));
    clientRes.write(sseEvent('response.content_part.done', {
      type: 'response.content_part.done', sequence_number: seq++, output_index: 0, content_index: 0,
      part: { type: 'output_text', text: fullText }
    }));
    clientRes.write(sseEvent('response.output_item.done', {
      type: 'response.output_item.done', sequence_number: seq++, output_index: 0,
      item: { type: 'message', id: msgId, status: 'completed', role: 'assistant',
              content: [{ type: 'output_text', text: fullText, annotations: [] }] }
    }));
  }

  function finishToolCalls() {
    sendHeaders();
    const outputItems = [];
    let outIdx = 0;

    // If there was text content, emit it
    if (fullText) {
      const textItem = {
        type: 'message', id: msgId, status: 'completed', role: 'assistant',
        content: [{ type: 'output_text', text: fullText, annotations: [] }]
      };
      outputItems.push(textItem);
      outIdx++;
    }

    // Emit each tool call
    for (const idx of Object.keys(toolCalls).sort((a,b) => a-b)) {
      const tc = toolCalls[idx];
      const callId = tc.id || `call_${Date.now()}_${idx}`;
      const fnName = tc.name || 'unknown';
      const fnArgs = tc.arguments || '{}';

      const fcItem = {
        type: 'function_call', id: callId, call_id: callId,
        name: fnName, arguments: fnArgs, status: 'completed'
      };

      clientRes.write(sseEvent('response.output_item.added', {
        type: 'response.output_item.added', sequence_number: seq++, output_index: outIdx,
        item: { type: 'function_call', id: callId, call_id: callId, name: fnName, arguments: '', status: 'in_progress' }
      }));
      clientRes.write(sseEvent('response.function_call_arguments.delta', {
        type: 'response.function_call_arguments.delta', sequence_number: seq++, output_index: outIdx,
        item_id: callId, delta: fnArgs
      }));
      clientRes.write(sseEvent('response.function_call_arguments.done', {
        type: 'response.function_call_arguments.done', sequence_number: seq++, output_index: outIdx,
        item_id: callId, arguments: fnArgs
      }));
      clientRes.write(sseEvent('response.output_item.done', {
        type: 'response.output_item.done', sequence_number: seq++, output_index: outIdx,
        item: fcItem
      }));
      outputItems.push(fcItem);
      outIdx++;
    }

    return outputItems;
  }

  function finishResponse() {
    let outputItems;
    if (hasToolCalls) {
      outputItems = finishToolCalls();
    } else {
      finishText();
      outputItems = [{ type: 'message', id: msgId, status: 'completed', role: 'assistant',
                       content: [{ type: 'output_text', text: fullText, annotations: [] }] }];
    }

    clientRes.write(sseEvent('response.completed', {
      type: 'response.completed', sequence_number: seq++,
      response: {
        id: respId, object: 'response', created_at: Math.floor(Date.now()/1000),
        status: 'completed', model, output: outputItems,
        usage: { input_tokens: 0, output_tokens: fullText.length, total_tokens: fullText.length }
      }
    }));
    clientRes.write('data: [DONE]\n\n');
    clientRes.end();
    
    if (hasToolCalls) {
      const names = Object.values(toolCalls).map(tc => tc.name).join(', ');
      console.log(`[CodexAPI] ✓ Tool calls: ${names}`);
    } else {
      console.log(`[CodexAPI] ✓ Text (${fullText.length} chars): ${fullText.substring(0, 60)}...`);
    }
  }

  // Parse SSE chunks from backend
  function processChunk(chunk) {
    buffer += chunk;
    const parts = buffer.split('\n');
    buffer = parts.pop() || ''; // Keep incomplete line in buffer

    for (const line of parts) {
      if (!line.startsWith('data: ')) continue;
      const payload = line.slice(6).trim();
      if (payload === '[DONE]') {
        finishResponse();
        return;
      }
      try {
        const json = JSON.parse(payload);
        const delta = json.choices?.[0]?.delta;
        if (!delta) continue;

        // Text content streaming
        if (delta.content) {
          sendTextDelta(delta.content);
        }

        // Tool calls streaming
        if (delta.tool_calls) {
          hasToolCalls = true;
          for (const tc of delta.tool_calls) {
            const idx = tc.index ?? 0;
            if (!toolCalls[idx]) {
              toolCalls[idx] = { id: tc.id || '', name: '', arguments: '' };
            }
            if (tc.id) toolCalls[idx].id = tc.id;
            if (tc.function?.name) toolCalls[idx].name += tc.function.name;
            if (tc.function?.arguments) toolCalls[idx].arguments += tc.function.arguments;
          }
        }
      } catch(e) { /* skip malformed chunks */ }
    }
  }

  // Make request to backend
  const opts = {
    hostname: REAL_HOST, port: REAL_PORT,
    path: '/v1/chat/completions', method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${API_KEY}`,
      'Content-Length': Buffer.byteLength(body)
    }
  };

  const req = http.request(opts, res => {
    if (res.statusCode !== 200) {
      let errData = '';
      res.on('data', c => errData += c);
      res.on('end', () => {
        console.log(`[CodexAPI] ✗ Backend ${res.statusCode}: ${errData.substring(0, 200)}`);
        if (!headerWritten) {
          clientRes.writeHead(res.statusCode, { 'Content-Type': 'application/json' });
          clientRes.end(errData);
        } else {
          finishResponse();
        }
      });
      return;
    }
    res.setEncoding('utf8');
    res.on('data', chunk => processChunk(chunk));
    res.on('end', () => {
      // Process remaining buffer
      if (buffer.trim()) processChunk('\n');
      if (!clientRes.writableEnded) finishResponse();
    });
  });

  req.on('error', e => {
    console.log(`[CodexAPI] ✗ Error: ${e.message}`);
    if (!headerWritten) {
      clientRes.writeHead(502);
      clientRes.end(JSON.stringify({ error: { message: e.message } }));
    }
  });
  req.setTimeout(300000); // 5 min timeout
  req.write(body);
  req.end();
}

// ═══════════════════════════════════════════
// SERVER
// ═══════════════════════════════════════════

const server = http.createServer((clientReq, clientRes) => {
  let body = '';
  clientReq.on('data', chunk => { body += chunk; });
  clientReq.on('end', () => {

    if (clientReq.url.includes('/models') && clientReq.method === 'GET') {
      const now = Math.floor(Date.now() / 1000);
      clientRes.writeHead(200, { 'Content-Type': 'application/json' });
      clientRes.end(JSON.stringify({
        object: 'list',
        data: VALID_MODELS.map(m => ({ id: m.id, object: 'model', created: now, owned_by: m.full.split('/')[0] }))
      }));
      return;
    }

    if (clientReq.url.includes('/responses') && clientReq.method === 'POST') {
      let parsed;
      try { parsed = JSON.parse(body); } catch(e) {
        clientRes.writeHead(400);
        clientRes.end(JSON.stringify({ error: { message: 'Invalid JSON' } }));
        return;
      }

      const rawModel = parsed.model || 'cx/gpt-5.5';
      const model = mapModel(rawModel);
      const messages = convertInputToMessages(parsed.input || []);
      const tools = convertTools(parsed.tools);

      console.log(`[CodexAPI] ${rawModel} → ${model} | ${messages.length} msgs | tools: ${tools ? tools.length : 0}`);

      handleStreamingResponse(model, messages, tools, clientRes);
      return;
    }

    // Forward other requests
    const proxyOpts = {
      hostname: REAL_HOST, port: REAL_PORT,
      path: clientReq.url, method: clientReq.method,
      headers: { ...clientReq.headers, host: REAL_HOST, 'authorization': `Bearer ${API_KEY}`, 'content-length': Buffer.byteLength(body) }
    };
    const proxyReq = http.request(proxyOpts, proxyRes => {
      let d = '';
      proxyRes.on('data', c => d += c);
      proxyRes.on('end', () => { clientRes.writeHead(proxyRes.statusCode, proxyRes.headers); clientRes.end(d); });
    });
    proxyReq.on('error', e => { clientRes.writeHead(502); clientRes.end(JSON.stringify({ error: { message: e.message } })); });
    proxyReq.setTimeout(180000);
    if (body) proxyReq.write(body);
    proxyReq.end();
  });
});

server.listen(LOCAL_PORT, '127.0.0.1', () => {
  console.log(`CodexAPI Proxy v3 (Streaming): http://127.0.0.1:${LOCAL_PORT} -> http://${REAL_HOST}/v1`);
  console.log(`Models: ${VALID_MODELS.map(m => m.id).join(', ')}`);
});
