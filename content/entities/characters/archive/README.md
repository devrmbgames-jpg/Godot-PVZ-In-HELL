# Archived rigid player

`rigid_player.tscn` preserves the main level's authored RigidBody3D player at the
CharacterBody migration boundary, including component tuning, camera, hands and
belt slots. It can be instantiated independently for comparison or rollback.

The shared `E_RigidBodyCharacter` script and its original prefab remain active
dependencies of rigid NPCs and regression fixtures. Their head/interaction API
now comes from `E_PhysicalCharacter`; their native rigid movement is unchanged.

Main and primitive gameplay scenes use `character_body_player.tscn`. Saved
authored player records bind to the existing `Entityes/Player`, preserving the
player identity, pose, health, inventory and slot links across this migration.
