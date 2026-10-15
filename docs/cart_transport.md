# Cart transport

The warehouse cart is a QoL transport, separate from puzzle Push. `push_cart.tscn` keeps its authored visuals and collision shapes but uses `CharacterBody3D`, `E_TransportCart` and `C_CartTransport`. `S_Push`, its relationships and its forward-only/reverse-to-release behavior are unchanged. Its regression fixture lives in `tests/fixtures/push_test_body.tscn`.

## Controls and ownership

The cart's contextual E action takes the handle. W/S drive forward/reverse, A/D turn and E releases. S never detaches the driver. Hands and Carry keep their existing ownership and lower out of view. F can invoke another available target action. The TRANSPORT token is between PUSH and DRAWING; modal UI brakes transport without releasing its token. Camera direction follows the cart and jump/crouch are suppressed while driving.

`cart --R_CartDrivenBy--> actor` is session authority; `C_CartDriver.cart` is a checked reverse cache. `CartTransportService` starts/ends participation and applies reversible lifecycle effects, with `O_CartLifecycle` reacting to native relationship/World events. Removal, disable, excessive separation and tree exit clean up participation; driver validity uses the ordinary actor availability contract. Neither body is reparented or teleported to follow the other.

## Grounded movement

`E_TransportCart._physics_process` forwards native physics delta to `CartDriveSolver.step`. CharacterBody move-and-slide, gravity and floor snapping own translation. The deck remains upright, removing rigid suspension bounce. W/S use distinct speed limits and acceleration. Small steps require clear upward and forward sweeps plus a walkable surface probe; walls and large steps remain blocking. Yaw is checked for blocking contacts before applying it. Body transforms are changed only on the physics step through the cart controller.

The driver remains a RigidBody3D. `E_RigidBodyCharacter` calls `CartDriverSolver.integrate` in its native callback to supply bounded handle-following velocity; a short terrain probe helps the feet onto small rises and collision response remains active. If the driver cannot keep up, the cart stops moving farther away but can reverse toward the driver. Transport is intended for walkable ramps and small floor discontinuities.

## Cargo assistance

`CargoArea` supplies physical candidates. `S_CartCargo` owns membership sampling and GamePlay-second settling, rejecting stale or duplicate physical-frame samples. A grabbable rigid body must settle at low relative speed on the cart or already loaded cargo before `CartCargoService.load_supported` creates `cargo --R_CartCargo--> cart`. `C_CartTransport.cargo` is only a reverse cache. Passing through the volume or holding a box does not load it. Stacking is supported.

Loaded cargo retains its parent and physical body. A bounded velocity/angular-velocity controller in `E_GrabbableBody._integrate_forces` follows the settled cart-local pose. This documented transport restraint uses custom integration rather than friction to keep boxes aboard during turning and acceleration. It suppresses gravity for the loaded interval, disables sleep, and excludes only the owning cart from collisions. Other cargo, walls and external objects remain collidable. If an obstruction causes excessive pose error, the restraint releases instead of teleporting the load through it.

`GrabService` releases cargo after pickup preflight. Lost membership, destroyed parcels and cart removal/disable also release cargo. Cleanup restores previous custom-integration/sleep settings and removes only the collision exception added by transport. Ending the driver session leaves settled cargo on the parked cart. Closed persistence stores supported cargo links by stable endpoints and local pose; restore rebuilds R_CartCargo and its effects after actor construction. Driver participation remains transient. See [persistence.md](persistence.md).

## Validation

`tests/smoke/cart_transport_smoke.tscn` uses real bodies for forward/reverse, steering, stacked load retention, pickup, ramps, a 12 cm uneven patch, walls and reversing away from a blocked route. Generic Push regressions stay in the existing GUT suite. Require PASS and no assertion/script errors; frame limits alone are not success. Visual/game-feel validation remains with the user.
