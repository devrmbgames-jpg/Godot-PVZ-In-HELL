# Cart transport

The warehouse cart is a QoL transport, separate from puzzle Push. `push_cart.tscn` keeps its authored visuals and collision shapes but uses `CharacterBody3D`, `E_TransportCart` and `C_CartTransport`. `S_Push`, its relationships and its forward-only/reverse-to-release behavior are unchanged. Its regression fixture lives in `tests/fixtures/push_test_body.tscn`.

## Controls and ownership

The cart's contextual E action takes the handle. W/S drive forward/reverse, A/D turn and E releases. S never detaches the driver. Hands and Carry keep their existing ownership and lower out of view. F can invoke another available target action. The TRANSPORT token is between PUSH and DRAWING; modal UI brakes transport without releasing its token. Camera direction follows the cart and jump/crouch are suppressed while driving.

`C_CartTransport.driver` is session authority; `C_CartDriver` is a lazily created runtime lookup. Removal, disable, defeat, excessive separation and tree exit clean up the session. Neither body is reparented or teleported to follow the other.

## Grounded movement

`E_TransportCart._physics_process` forwards to `S_CartTransport.step`. CharacterBody move-and-slide, gravity and floor snapping own translation. The deck remains upright, removing rigid suspension bounce. W/S use distinct speed limits and acceleration. Small steps require clear upward and forward sweeps plus a walkable surface probe; walls and large steps remain blocking. Yaw is checked for blocking contacts before applying it. Body transforms are changed only on the physics step through the cart controller.

The driver remains a RigidBody3D. A narrow S_Motion hook supplies bounded handle-following velocity and a short terrain probe helps the feet onto small rises; collision response remains active. If the driver cannot keep up, the cart stops moving farther away but can reverse toward the driver. Transport is intended for walkable ramps and small floor discontinuities, not stairs of arbitrary height or off-road suspension.

## Cargo assistance

`CargoArea` discovers grabbable rigid bodies. A body must settle at low relative speed on the cart or already loaded cargo before `S_CartCargo` adds `C_CartCargo`. Passing through the volume or holding a box does not load it. Stacking is supported.

Loaded cargo retains its parent and physical body. A bounded velocity/angular-velocity controller in `E_GrabbableBody._integrate_forces` follows the settled cart-local pose. This documented transport restraint uses custom integration rather than friction to keep boxes aboard during turning and acceleration. It suppresses gravity for the loaded interval, disables sleep, and excludes only the owning cart from collisions. Other cargo, walls and external objects remain collidable. If an obstruction causes excessive pose error, the restraint releases instead of teleporting the load through it.

S_Grab releases cargo only after pickup validation succeeds, so ordinary carrying resumes immediately. Lost membership, destroyed parcels and cart removal/disable also release cargo. Cleanup restores the previous custom-integration/sleep settings and removes only the collision exception added by transport. Ending the driver session leaves settled cargo on the parked cart. Runtime cargo bindings are not save records; future persistence should restore bodies and let settled support reacquire them.

## Validation

`tests/smoke/cart_transport_smoke.tscn` uses real bodies for forward/reverse, steering, stacked load retention, pickup, ramps, a 12 cm uneven patch, walls and reversing away from a blocked route. Generic Push regressions stay in the existing GUT suite. Require PASS and no assertion/script errors; frame limits alone are not success. Visual/game-feel validation remains with the user.
