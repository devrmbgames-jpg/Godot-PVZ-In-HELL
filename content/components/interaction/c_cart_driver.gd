extends Component
## Runtime-only lookup, created when an actor first operates a transport cart.
class_name C_CartDriver

## Derived cache; the cart's C_CartTransport.driver remains authoritative.
var cart: Entity = null
