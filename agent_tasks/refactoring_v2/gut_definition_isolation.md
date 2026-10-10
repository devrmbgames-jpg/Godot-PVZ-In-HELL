# GUT immutable Definition isolation

Status: **IN_PROGRESS**

Owner: GUT fixtures mutating authored Definitions; dependency of final task66.
Production Definition sharing remains intentional and must not change.

Evidence: all112 suites in one process at4eca294128c4acd78f4d53cf0ec1b4616c970bcc
loaded1641 tests; four failed. Startup reports package return affordance executor=null,
slot_id=missing after test_smart_objects negative schema case. That fixture duplicates
the Trait but retains its immutable Definition reference, then changes it. Running the
startup/persistence suites in a fresh process passes8/8 (334 assertions); raw full-suite
failure and logs are preserved. A separate golden persistence failure still needs diagnosis.

Acceptance: detach only mutated fixture Definition/affordance references, retain useful
negative provider assertions, prove authored source unchanged and ordering regressions;
full GUT passes, formatter/native parser pass and immutable repair review before DONE.
No authored scene/resource or production ownership change is authorized by this repair.

Current repair: Smart Object negative fixture detaches its Definition, affordance array
and the exact mutated affordance. Assertions prove the original authored slot/executor
remain unchanged. The old mutation is also present at source
`3f0499aab47bf2ad0a93e69b29ec2b40ac26db0a`, confirming a pre-style fixture defect.
Ordered native-tool/persistence/Smart Object/startup regression PASS32 tests/453 assertions.
Ten authoring/package/compiler predecessor suites plus golden persistence PASS123/1378.
Golden contamination is independently localized to the NPC target-loss fixture:
it shallow-copies the District Definition, erases a shared places-array portal, then
replaces only the fixture's array. Other retained Definition aliases keep the deletion.
DistrictSnapshotRules rejects the golden portal, correctly. The original shallow-copy
operation is present at source3f0499aab47bf2ad0a93e69b29ec2b40ac26db0a.
Repair clones the array before erase and asserts the original Definition places unchanged.
The failing combined predecessor batch now PASS325/325,3041 assertions, stderr empty.
First46 suites PASS689/5930; split predecessor batches PASS118/1519 and211/1834 alone
proved resource-lifetime-sensitive contamination. Raw initial full and second-prefix FAIL
logs remain preserved. Golden assertion now includes valid-data diagnostics.
All temporary production traces removed; git diff of both persistence validators empty,
native MCP validates both paths cleanly. Production/save/authoring contracts unchanged.
Style3 fixtures PASS; full112-suite repaired run and immutable repair review pending.
