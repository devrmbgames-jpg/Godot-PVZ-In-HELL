extends RefCounted
## Versioned canonical decision seeds for the pinned Godot RNG; never consumes mutable RNG state.
class_name DecisionRandomRules

## UTF-8 length framing, SHA-256, eight big-endian digest bytes with the high bit cleared.
const ALGORITHM: String = "pvzh-decision-seed-v1"

#region Canonical deterministic seed
## Frames seed, stable actor, calendar day, action kind and committed sequence in fixed order.
static func key_bytes(world_seed: int, actor_id: String, day: int, kind: String,
		sequence: int = 0) -> PackedByteArray:
	assert(not actor_id.is_empty() and day >= 1 and not kind.is_empty() and sequence >= 0)
	var encoded: PackedByteArray = PackedByteArray()
	for field: String in [ALGORITHM, str(world_seed), actor_id, str(day), kind, str(sequence)]:
		var payload: PackedByteArray = field.to_utf8_buffer()
		encoded.append_array(str(payload.size()).to_utf8_buffer())
		encoded.append(58) # ASCII colon separates the decimal byte length from its payload.
		encoded.append_array(payload)
	return encoded


## Returns a nonnegative signed-64-bit seed; engine hash and dictionary iteration are excluded.
static func seed_for(world_seed: int, actor_id: String, day: int, kind: String,
		sequence: int = 0) -> int:
	var hashing: HashingContext = HashingContext.new()
	var start_error: Error = hashing.start(HashingContext.HASH_SHA256)
	assert(start_error == OK)
	var update_error: Error = hashing.update(key_bytes(world_seed, actor_id, day, kind, sequence))
	assert(update_error == OK)
	var digest: PackedByteArray = hashing.finish()

	var seed_value: int = int(digest[0]) & 127
	for index: int in range(1, 8):
		seed_value = (seed_value << 8) | int(digest[index])
	return seed_value


## Creates the pinned native generator for one explicit key; previews do not advance sequences.
static func generator(world_seed: int, actor_id: String, day: int, kind: String,
		sequence: int = 0) -> RandomNumberGenerator:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_for(world_seed, actor_id, day, kind, sequence)
	return random
#endregion
