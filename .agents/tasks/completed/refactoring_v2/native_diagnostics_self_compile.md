# Native diagnostics — executing-handler compilation

Status: **DONE**

Owner: companion `addons/pvz_ai_tools/style_script_validation_tool.gd`.
Discovered while validating task65; keep separate from mechanical gameplay style edits.

Evidence: task65 native batch disconnected twice and the editor process disappeared.
Focused GUT self-compilation reproduces `Internal script error! Opcode: 28` at the
executing handler's ResourceLoader call; log `gut-20261010-100215496` under
`.artifacts/godot_agent/`. This is a live tool defect, not deferred shutdown retention.

Repair: never reload/compile the executing handler. Check its existing compiled Script
only when its exact source matches disk; otherwise return unavailable/ERR_BUSY and
require a native registry reload. Other paths use ResourceLoader with CACHE_IGNORE
and explicit native `reload(true)` diagnostics. Non-tool scripts cannot be
instantiated inside the editor; their reload result proves compilation instead.
No Nodes, gameplay instances or authored state mutation.

Acceptance: focused GUT including own-handler and EditorPlugin compilation PASS;
live task65 first batch compiles safely and keeps the same editor alive;
full native diagnostics/parser checks and immutable review before DONE.

Current validation: focused own-handler/EditorPlugin GUT 9 tests,23 assertions PASS;
live native task65 compilation330/330 PASS with editor PID3360 remaining alive;
registry hot-swap uses native MCP script_create. Focused CLI ParseFiles PASS,
logs `parsefiles-20261010-101902583`. Independent review base
`3f0499aab47bf2ad0a93e69b29ec2b40ac26db0a` to source
`287933e0c19c141ade715503063844fb7606a75f`: ARCHITECTURE/STYLE PASS, no
material findings; reviewer VALIDATION NOT_RUN. Main ran actual checks above.
