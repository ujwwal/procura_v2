const {test} = require('node:test');
const assert = require('node:assert/strict');
const {parseExecution, nodeItems} = require('../scripts/n8n-execution');

test('execution parsing handles noisy logs, nested objects and escaped string content', () => {
  const execution = {
    id: 'execution-1',
    data: {resultData: {runData: {}, message: 'Braces { } with "quotes" and a \\ backslash'}}
  };
  const output = 'Starting n8n\n{"log":"not an execution"}\n{unfinished log\n' +
    JSON.stringify(execution) + '\nDone\n';
  assert.deepEqual(parseExecution(output), execution);
});

test('missing or malformed execution output fails without echoing private log content', () => {
  for (const output of ['PRIVATE_LOG', '{"data":{"other":true}}', '{"data":{"resultData":']) {
    assert.throws(() => parseExecution(output), {
      message: 'n8n returned no parseable execution data; inspect private log'
    });
  }
});

test('node outputs retain all runs in order and use only the first main output', () => {
  const runData = {
    'Validate extraction': [
      {data: {main: [[{json: {bid_id: 4000}}, {json: {bid_id: 4001}}], [{json: {other_branch: true}}]]}},
      {data: {main: [[{json: {bid_id: 4002}}]]}},
      {},
      {data: {main: []}}
    ]
  };
  assert.deepEqual(nodeItems(runData, 'Validate extraction'), [
    {bid_id: 4000}, {bid_id: 4001}, {bid_id: 4002}
  ]);
  assert.deepEqual(nodeItems(runData, 'Missing node'), []);
});
