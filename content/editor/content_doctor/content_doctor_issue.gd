extends RefCounted
## Detached content diagnostic; it never retains an actor or owns gameplay state.
class_name ContentDoctorIssue

enum Severity {
	ERROR,
	REVIEW_REQUIRED,
}

## Error blocks authoring acceptance; unsupported static analysis requires explicit review.
var severity: Severity = Severity.ERROR
## Stable diagnostic category for CLI output and focused regression fixtures.
var code: StringName = &""
## Resource or scene path being inspected, including caller supplied in-memory provenance.
var source: String = ""
## Scene instance and/or resource field within the source.
var field: String = ""
## Actionable explanation of the violated authored contract.
var message: String = ""


#region Diagnostic construction
static func error(
	issue_code: StringName,
	issue_source: String,
	issue_field: String,
	issue_message: String,
) -> ContentDoctorIssue:
	var issue: ContentDoctorIssue = ContentDoctorIssue.new()
	issue.code = issue_code
	issue.source = issue_source
	issue.field = issue_field
	issue.message = issue_message
	return issue


func data() -> Dictionary[String, Variant]:
	return {
		"severity": Severity.keys()[severity],
		"code": String(code),
		"source": source,
		"field": field,
		"message": message,
	}
#endregion
