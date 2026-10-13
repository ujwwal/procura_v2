const LIMITATIONS = [
  'The approval_flags view reports issues for the whole requisition, across all linked approval records. Evidence identifies the source approval for each issue.',
  'over_limit and inactive_approver are checked only for recorded statuses that normalize to approved. Pending approvals can have no flags even when an employee is inactive or their limit is insufficient.',
  'unresolved_approver is checked for every linked approval status. Employees are matched by exact name, not by employee ID; multiple matches do not establish a unique identity.',
  'Approval status and entity type are normalized using PostgreSQL lower(trim(...)). An amount equal to the recorded limit is not over_limit.',
  'The view compares recorded numeric limits and requisition amounts without currency conversion, departmental authority, delegation rules, or historical employee snapshots.',
  'No issues detected does not establish approval, budget availability, compliance, or payment eligibility. Recorded statuses are historical data, not decisions made by this assistant.'
];

function validApprovalId(value) {
  return (typeof value === 'number' || typeof value === 'string') &&
    /^[1-9]\d*$/.test(String(value)) && Number(value) <= 2147483647;
}

class ApprovalContextError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

// Keep view-level scope: an approval ID chooses a requisition, not a filter on its flags.
function assembleApprovalContext(approval, requisition, lines, departments, requesters, approvals, contexts, recorded) {
  const evidence = [], derived = [];
  for (const row of contexts) {
    for (const category of ['over_limit', 'inactive_approver', 'unresolved_approver']) {
      if (!row[category]) continue;
      const detail = row[category + '_detail'];
      derived.push({flag_type: category, detail});
      evidence.push({
        evidence_id: category + ':approval:' + row.approval_id + ':employee:' + (row.employee_id ?? 'unresolved'),
        category,
        facts: {
          requisition_id: requisition.id, source_approval_id: row.approval_id,
          selected_approval: row.approval_id === approval.id, recorded_approval_status: row.status,
          normalized_approval_status: row.normalized_status, recorded_approver_name: row.approver,
          employee_id: row.employee_id, employee_name: row.employee_name,
          employee_is_active: row.is_active, employee_approval_limit: row.approval_limit,
          requisition_amount: requisition.amount, requisition_currency: requisition.currency,
          limit_currency: null, employee_match_method: 'exact_name'
        }
      });
    }
  }
  const sortedRows = rows => rows.map(r => JSON.stringify([r.flag_type, r.detail])).sort();
  if (JSON.stringify(sortedRows(recorded)) !== JSON.stringify(sortedRows(derived)))
    throw new Error('Recorded flags and supporting evidence do not agree');
  if (new Set(evidence.map(e => e.evidence_id)).size !== evidence.length)
    throw new Error('Ambiguous evidence references');
  const categories = [...new Set(recorded.map(r => r.flag_type))].sort();
  const missing = [];
  if (!lines.length) missing.push('No requisition line records were found.');
  if (requisition.amount === null) missing.push('Requisition amount is not recorded.');
  if (requesters.length !== 1) missing.push('Requester name matches ' + requesters.length + ' employee records; unique requester identity is not established.');
  if (departments.length !== 1) missing.push('Department name matches ' + departments.length + ' department records; unique department identity is not established.');
  for (const a of approvals) {
    const matches = contexts.filter(c => c.approval_id === a.id && c.employee_id !== null);
    if (matches.length !== 1) missing.push('Approval ' + a.id + ' has ' + matches.length + ' exact-name employee matches; unique approver identity is not established.');
    if (matches.some(c => c.approval_limit === null)) missing.push('Approval ' + a.id + ' has a matched employee without a recorded limit.');
  }
  return {
    approval, requisition, requisition_lines: lines,
    department_matches: departments, requester_matches: requesters,
    related_approvals: approvals, approver_matches: contexts.map(row => ({
      approval_id: row.approval_id, employee_id: row.employee_id, employee_name: row.employee_name,
      department_id: row.department_id, role: row.role,
      approval_limit: row.approval_limit, is_active: row.is_active, match_method: 'exact_name'
    })),
    flags_scope: 'requisition_all_linked_approvals',
    flags: categories.map(category => ({
      category, details: recorded.filter(r => r.flag_type === category).map(r => r.detail),
      evidence_ids: evidence.filter(e => e.category === category).map(e => e.evidence_id),
      source_approval_ids: [...new Set(evidence.filter(e => e.category === category).map(e => e.facts.source_approval_id))]
    })),
    evidence, missing_information: missing, check_limitations: LIMITATIONS
  };
}

async function readApprovalContext(pool, id) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
    await client.query("SET LOCAL TIME ZONE 'UTC'");
    const header = await client.query(
      'SELECT id,entity_type,entity_id,action,approver,status,comment,created_at,lower(trim(entity_type)) AS normalized_entity_type,lower(trim(status)) AS normalized_status FROM public.approvals WHERE id=$1', [id]);
    if (!header.rows.length) { await client.query('COMMIT'); return null; }
    const approval = header.rows[0];
    if (approval.normalized_entity_type !== 'requisition')
      throw new ApprovalContextError(422, 'This review supports requisition approvals only.');
    const req = await client.query(
      'SELECT id,req_no,title,requester,department,amount::text,status,created_at,currency,delivery_location,needed_by::text,justification FROM public.requisitions WHERE id=$1', [approval.entity_id]);
    if (!req.rows.length) throw new ApprovalContextError(409, 'Linked requisition is missing. No review result was produced.');
    const requisition = req.rows[0];
    const lines = await client.query(
      'SELECT id,requisition_id,line_no,catalog_item_id,supplier_id,description,quantity::text,unit,unit_price::text,line_total::text,created_at FROM public.requisition_lines WHERE requisition_id=$1 ORDER BY line_no,id', [requisition.id]);
    const departments = await client.query('SELECT department_id,name FROM public.departments WHERE name=$1 ORDER BY department_id', [requisition.department]);
    const requesters = await client.query('SELECT employee_id,name,department_id,role,is_active FROM public.employees WHERE name=$1 ORDER BY employee_id', [requisition.requester]);
    const approvals = await client.query(
      "SELECT id,entity_type,entity_id,action,approver,status,comment,created_at,lower(trim(entity_type)) AS normalized_entity_type,lower(trim(status)) AS normalized_status FROM public.approvals WHERE entity_id=$1 AND lower(trim(entity_type))='requisition' ORDER BY id", [requisition.id]);
    // These predicates and detail strings mirror the inspected view. The view remains authoritative:
    // a mismatch makes retrieval fail rather than creating a new interpretation of its flags.
    const contexts = await client.query(
      "SELECT a.id AS approval_id,a.approver,a.status,lower(trim(a.status)) AS normalized_status,e.employee_id,e.name AS employee_name,e.department_id,e.role,e.approval_limit::text,e.is_active," +
      "(lower(trim(a.status))='approved' AND e.approval_limit<r.amount) AS over_limit," +
      "(lower(trim(a.status))='approved' AND e.is_active=false) AS inactive_approver," +
      "(e.employee_id IS NULL) AS unresolved_approver," +
      "format('Approval limit %s below requisition amount %s',e.approval_limit,r.amount) AS over_limit_detail," +
      "'Approved by an inactive employee' AS inactive_approver_detail," +
      "format('Approver name \"%s\" matches no employee record',a.approver) AS unresolved_approver_detail " +
      "FROM public.requisitions r JOIN public.approvals a ON a.entity_id=r.id AND lower(trim(a.entity_type))='requisition' " +
      "LEFT JOIN public.employees e ON e.name=a.approver WHERE r.id=$1 ORDER BY a.id,e.employee_id", [requisition.id]);
    const flags = await client.query('SELECT flag_type,detail FROM public.approval_flags WHERE requisition_id=$1 ORDER BY flag_type,detail', [requisition.id]);
    const result = assembleApprovalContext(approval, requisition, lines.rows, departments.rows, requesters.rows, approvals.rows, contexts.rows, flags.rows);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {});
    throw error;
  } finally { client.release(); }
}

function approvalReviewHandler(pool) {
  return async (req, res) => {
    res.set('Cache-Control', 'no-store');
    if (!validApprovalId(req.params.id)) return res.status(400).json({error: 'Invalid approval ID'});
    try {
      const result = await readApprovalContext(pool, Number(req.params.id));
      return result ? res.json(result) : res.status(404).json({error: 'Approval not found'});
    } catch (error) {
      if (error instanceof ApprovalContextError) return res.status(error.status).json({error: error.message});
      return res.status(503).json({error: 'Approval evidence unavailable. No review result was produced.'});
    }
  };
}
module.exports = {LIMITATIONS, validApprovalId, assembleApprovalContext, readApprovalContext, approvalReviewHandler};
