// n8n mixes log messages with JSON output; quoted braces must stay inside strings.
function parseExecution(output) {
  for (let start = output.indexOf('{'); start >= 0; start = output.indexOf('{', start + 1)) {
    let depth = 0, quoted = false, escaped = false;
    for (let end = start; end < output.length; end++) {
      const character = output[end];
      if (quoted) {
        if (escaped) escaped = false;
        else if (character === '\\') escaped = true;
        else if (character === '"') quoted = false;
      } else if (character === '"') quoted = true;
      else if (character === '{') depth++;
      else if (character === '}' && --depth === 0) {
        try {
          const result = JSON.parse(output.slice(start, end + 1));
          if (result.data?.resultData) return result;
        } catch {}
        break;
      }
    }
  }
  throw new Error('n8n returned no parseable execution data; inspect private log');
}

function nodeItems(runData, name) {
  return (runData[name] ?? []).flatMap(run => run.data?.main?.[0] ?? []).map(item => item.json);
}

module.exports = {parseExecution, nodeItems};
