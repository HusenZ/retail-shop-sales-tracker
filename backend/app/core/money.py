from decimal import ROUND_HALF_UP, Decimal

ZERO = Decimal("0.00")
PAISA = Decimal("0.01")


def to_money(value: Decimal) -> Decimal:
    """Round to whole paise the way a shopkeeper would (half up)."""
    return value.quantize(PAISA, rounding=ROUND_HALF_UP)
