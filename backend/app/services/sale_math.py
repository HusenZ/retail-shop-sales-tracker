"""Sale arithmetic, kept free of I/O so every rule can be unit tested directly.

Revenue = selling price × quantity − discount
Cost    = purchase price × quantity
Profit  = revenue − cost
Amount due (what the customer pays) = revenue − exchange value of their old phone
"""

from dataclasses import dataclass
from decimal import Decimal

from app.core.errors import BusinessRuleError
from app.core.money import ZERO, to_money


@dataclass(frozen=True)
class LineInput:
    quantity: int
    unit_price: Decimal
    unit_cost: Decimal


@dataclass(frozen=True)
class LineResult:
    subtotal: Decimal
    discount: Decimal
    revenue: Decimal
    cost: Decimal
    profit: Decimal


@dataclass(frozen=True)
class SaleTotals:
    lines: list[LineResult]
    subtotal: Decimal
    discount: Decimal
    total: Decimal
    total_cost: Decimal
    profit: Decimal
    exchange_value: Decimal
    amount_due: Decimal


def calculate_sale(
    lines: list[LineInput], discount: Decimal, exchange_value: Decimal = ZERO
) -> SaleTotals:
    discount, exchange_value = to_money(discount), to_money(exchange_value)
    subtotals = [to_money(line.unit_price * line.quantity) for line in lines]
    subtotal = sum(subtotals, ZERO)
    if discount > subtotal:
        raise BusinessRuleError("Discount cannot be more than the sale amount")

    total = subtotal - discount
    if exchange_value > total:
        raise BusinessRuleError("Exchange value cannot be more than the sale amount")

    line_discounts = _allocate_discount(discount, subtotals)
    results = []
    for line, line_subtotal, line_discount in zip(lines, subtotals, line_discounts, strict=True):
        revenue = line_subtotal - line_discount
        cost = to_money(line.unit_cost * line.quantity)
        results.append(
            LineResult(
                subtotal=line_subtotal,
                discount=line_discount,
                revenue=revenue,
                cost=cost,
                profit=revenue - cost,
            )
        )

    total_cost = sum((result.cost for result in results), ZERO)
    return SaleTotals(
        lines=results,
        subtotal=subtotal,
        discount=discount,
        total=total,
        total_cost=total_cost,
        profit=total - total_cost,
        exchange_value=exchange_value,
        amount_due=total - exchange_value,
    )


def _allocate_discount(discount: Decimal, subtotals: list[Decimal]) -> list[Decimal]:
    """Split the sale discount across lines in proportion to their value.

    Per-line discounts let category reports add up exactly to the sale total. Rounding
    leftovers go to the largest line so no line is discounted below zero.
    """
    total = sum(subtotals, ZERO)
    if discount == ZERO or total == ZERO:
        return [ZERO for _ in subtotals]

    shares = [to_money(discount * line / total) for line in subtotals]
    largest = max(range(len(subtotals)), key=lambda index: subtotals[index])
    shares[largest] += discount - sum(shares, ZERO)
    return shares
