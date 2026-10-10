"""Explicit offline migration of native authoring blocks; never runs during gameplay.

Run with the editor closed. Already migrated scenes are left untouched.
"""

from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[3]
BASE = "res://content/shared/entities/e_traited_entity.gd"
TRAIT_SCRIPT = "res://content/shared/authoring/entity_trait.gd"


def sections(text):
    matches = list(re.finditer(r"^\[(?:gd_scene|gd_resource|ext_resource|sub_resource|resource|node|connection)[^\n]*\]\n", text, re.M))
    return [text[m.start(): matches[i + 1].start() if i + 1 < len(matches) else len(text)] for i, m in enumerate(matches)]


def identity(block):
    match = re.search(r' id="([^"]+)"', block.splitlines()[0])
    return match[1] if match else None


def ext_map(blocks):
    return {identity(b): re.search(r' path="([^"]+)"', b)[1] for b in blocks if b.startswith('[ext_resource')}


def template_traits(template_path):
    path = ROOT / template_path.removeprefix("res://")
    blocks = sections(path.read_text(encoding="utf-8"))
    resources = {identity(b): b for b in blocks if b.startswith('[sub_resource')}
    external = ext_map(blocks)
    resource = next(b for b in blocks if b.startswith('[resource]'))
    declaration = re.search(r'^traits = (.*)$', resource, re.M)[1]
    array = declaration[declaration.index('([') + 2:-2] if '([' in declaration else declaration[1:-1]
    result = []
    for kind, ref in re.findall(r'(SubResource|ExtResource)\("([^"]+)"\)', array):
        if kind == "ExtResource":
            result.append(external[ref])
            continue
        selected = resources[ref]
        trait_id = re.search(r'^trait_id = &"([^"]+)"', selected, re.M)[1]
        destination = path.parent.parent / "authoring" / (path.stem.replace("def_entity_", "et_") + "_" + trait_id + ".tres")
        copied = ['[gd_resource type="Resource" format=3]\n\n']
        for block in blocks[1:]:
            if block.startswith('[resource]') or block == selected:
                continue
            if block.startswith('[ext_resource') and 'def_entity_template.gd' in block:
                continue
            copied.append(block)
        copied.append('[resource]\n' + selected.split('\n', 1)[1])
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(''.join(copied).rstrip() + '\n', encoding="utf-8")
        result.append("res://" + destination.relative_to(ROOT).as_posix())
    return result


def migrate(path):
    text = path.read_text(encoding="utf-8")
    if 'metadata/entity_composition' not in text:
        return None
    blocks = sections(text)
    external = ext_map(blocks)
    resources = {identity(b): b for b in blocks if b.startswith('[sub_resource')}
    additions = []

    def add_external(resource_path, resource_type="Resource"):
        for ref, existing_path in external.items():
            if existing_path == resource_path:
                return ref
        ref = "DirectTrait_%d" % len(additions)
        external[ref] = resource_path
        additions.append('[ext_resource type="%s" path="%s" id="%s"]\n\n' % (resource_type, resource_path, ref))
        return ref

    trait_script = add_external(TRAIT_SCRIPT, "Script")
    migrated = []
    removed_resources = set()
    replaced_blocks = []
    for block in blocks:
        match = re.search(r'^metadata/entity_composition = SubResource\("([^"]+)"\)\n', block, re.M)
        if match is None:
            replaced_blocks.append(block)
            continue
        authoring = resources[match[1]]
        removed_resources.add(match[1])
        template_match = re.search(r'^entity_template = ExtResource\("([^"]+)"\)', authoring, re.M)
        trait_paths = template_traits(external[template_match[1]]) if template_match else []
        refs = [add_external(p) for p in trait_paths]
        direct = 'traits = Array[ExtResource("%s")]([%s])\n' % (trait_script, ', '.join('ExtResource("%s")' % r for r in refs))
        fields = authoring.split('\n', 1)[1]
        fields = re.sub(r'^(?:script|entity_template) = .*\n', '', fields, flags=re.M).strip()
        if fields:
            direct += fields + '\n'
        block = block[:match.start()] + direct + block[match.end():]
        script_match = re.search(r'^script = ExtResource\("([^"]+)"\)', block, re.M)
        if script_match and external[script_match[1]] == "res://addons/gecs/ecs/entity.gd":
            base_ref = add_external(BASE, "Script")
            block = block.replace('script = ExtResource("%s")' % script_match[1], 'script = ExtResource("%s")' % base_ref)
        elif script_match is None and 'instance=' not in block.splitlines()[0]:
            base_ref = add_external(BASE, "Script")
            header, body = block.split('\n', 1)
            block = header + '\nscript = ExtResource("%s")\n' % base_ref + body
        # Script exports must exist before native loading applies their serialized values.
        script_line = re.search(r'^script = .*\n', block, re.M)
        if script_line:
            declaration = script_line[0]
            block = block[:script_line.start()] + block[script_line.end():]
            header, body = block.split('\n', 1)
            block = header + '\n' + declaration + body
        replaced_blocks.append(block)
        migrated.append({"node": block.splitlines()[0], "template": external[template_match[1]] if template_match else None, "traits": trait_paths, "advanced": fields})
    output = []
    for block in replaced_blocks:
        if block.startswith('[sub_resource') and identity(block) in removed_resources:
            continue
        if block.startswith('[ext_resource'):
            ref = identity(block)
            if 'entity_authoring.gd' in block:
                continue
            if 'def_entity_' in block and not any('ExtResource("%s")' % ref in b for b in replaced_blocks if b.startswith('[node')):
                continue
        output.append(block)
    first_non_ext = next(i for i, b in enumerate(output[1:], 1) if not b.startswith('[ext_resource'))
    output[first_non_ext:first_non_ext] = additions
    path.write_text(''.join(output), encoding="utf-8")
    return migrated


if __name__ == "__main__":
    manifest = {}
    for directory in (ROOT / "content", ROOT / "tests/fixtures"):
        for scene in sorted(directory.rglob("*.tscn")):
            result = migrate(scene)
            if result:
                manifest[scene.relative_to(ROOT).as_posix()] = result
    target = ROOT / "tests/fixtures/refactoring_v2/direct_traits_migration.json"
    if manifest:
        target.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n', encoding="utf-8")
    print("Migrated %d scenes" % len(manifest))
