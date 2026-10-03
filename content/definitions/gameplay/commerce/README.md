# Trader profiles

Assign `C_Trader.profile` to a separate `DEF_TraderProfile` resource per store. Its catalog overrides the legacy `C_Trader.catalog`; a null profile preserves the legacy daily Evening catalog. Store catalogs are independent from the terminal's `C_Commerce.catalog`.

- `first_day`, `repeat_days`, `open_phases`: first available day, recurrence and allowed Morning/Day/Evening phases. Night always closes stores. The overhead label and panel show the actual schedule.
- `home_delivery_enabled`, `delivery_fee`, `delivery_delay_days`: a separate courier purchase charges the item plus fee once and queues physical delivery in the existing Morning `OrderReceiving` area. Occupied areas defer delivery; payment is not repeated. Only supported physical prefabs can be ordered.
- `def_trader_default.tres`: daily Evening, food/medicine/wrap/large shelf; courier fee30, next morning.
- `def_trader_medical.tres`: example medicine store, Morning every second day from day2; fee15. Copy/configure trader scenes to use different profiles.

Furniture uses the appended `DEF_InventoryItem.Kind.FURNITURE`, `maximum_stack = 1` and a `world_pickup_scene` with an Entity/RigidBody root and usable colliders. Furniture cannot enter inventory. The large shelf is3×3×1.5m,75kg and uses existing physical carrying and hammer anchoring.

`C_Trader.furniture_pickup_path` points to an authored `FurniturePickup` marker. Purchases try four nearby positions at3.5m horizontal/2.5m depth spacing, projecting the actual prefab bounds onto support and checking the entire volume before payment. Move the marker to designate another area. Goods spawn as siblings of the trader and receive a persistent operation identity; they do not follow the NPC. Blocked/unsupported placement does not charge. Courier furniture uses the same placement contract at the existing home receiving area.

Receipt modes preserve old numeric IDs. Optional `delivery_fee` defaults to zero for older records. Pending deliveries and physical identities use the existing save contract; fulfilled orders do not replay after consumption or loading.
