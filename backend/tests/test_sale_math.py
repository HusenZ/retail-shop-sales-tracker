from decimal import Decimal

import pytest

from app.core.errors import BusinessRuleError
from app.services.sale_math import LineInput, calculate_sale


def line(price: str, cost: str, quantity: int = 1) -> LineInput:
    return LineInput(quantity=quantity, unit_price=Decimal(price), unit_cost=Decimal(cost))


def test_discount_reduces_revenue_and_profit() -> None:
    totals = calculate_sale([line("1000", "800")], discount=Decimal("100"))

    assert totals.total == Decimal("900.00")
    assert totals.total_cost == Decimal("800.00")
    assert totals.profit == Decimal("100.00")


def test_prd_phone_example() -> None:
    totals = calculate_sale([line("15999", "14200")], discount=Decimal("500"))

    assert totals.total == Decimal("15499.00")
    assert totals.total_cost == Decimal("14200.00")
    assert totals.profit == Decimal("1299.00")
    assert totals.amount_due == Decimal("15499.00")


def test_quantity_multiplies_price_and_cost() -> None:
    totals = calculate_sale([line("499", "300", quantity=2)], discount=Decimal("0"))

    assert totals.subtotal == Decimal("998.00")
    assert totals.total_cost == Decimal("600.00")
    assert totals.profit == Decimal("398.00")


def test_exchange_reduces_amount_due_but_not_revenue() -> None:
    totals = calculate_sale(
        [line("55000", "50000")], discount=Decimal("0"), exchange_value=Decimal("18000")
    )

    assert totals.total == Decimal("55000.00")
    assert totals.profit == Decimal("5000.00")
    assert totals.exchange_value == Decimal("18000.00")
    assert totals.amount_due == Decimal("37000.00")


def test_selling_below_cost_gives_negative_profit() -> None:
    totals = calculate_sale([line("900", "1000")], discount=Decimal("0"))

    assert totals.profit == Decimal("-100.00")


def test_paise_are_kept_exactly() -> None:
    totals = calculate_sale([line("0.10", "0.05", quantity=3)], discount=Decimal("0.10"))

    assert totals.subtotal == Decimal("0.30")
    assert totals.total == Decimal("0.20")
    assert totals.profit == Decimal("0.05")


def test_discount_is_split_across_lines_and_adds_up_exactly() -> None:
    totals = calculate_sale(
        [line("100", "50"), line("100", "50"), line("100", "50")], discount=Decimal("100")
    )

    assert sum(result.discount for result in totals.lines) == Decimal("100")
    assert sorted(result.discount for result in totals.lines) == [
        Decimal("33.33"),
        Decimal("33.33"),
        Decimal("33.34"),
    ]
    assert sum(result.revenue for result in totals.lines) == totals.total
    assert sum(result.profit for result in totals.lines) == totals.profit


def test_discount_split_never_makes_a_line_negative() -> None:
    totals = calculate_sale(
        [line("0.01", "0"), line("0.01", "0"), line("999.98", "0")], discount=Decimal("1000.00")
    )

    assert all(result.revenue >= 0 for result in totals.lines)
    assert totals.total == Decimal("0.00")


def test_discount_larger_than_sale_is_rejected() -> None:
    with pytest.raises(BusinessRuleError):
        calculate_sale([line("1000", "800")], discount=Decimal("1000.01"))


def test_exchange_value_larger_than_sale_is_rejected() -> None:
    with pytest.raises(BusinessRuleError):
        calculate_sale([line("1000", "800")], discount=Decimal("0"), exchange_value=Decimal("1001"))
