extends Component
## Runtime-only reverse lookup for an actor operating a transport cart.
class_name C_CartDriver

## Derived/rebuildable cache. R_CartDrivenBy on the cart is the sole authority.
var cart: Entity = null
