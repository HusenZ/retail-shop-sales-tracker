from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from app.core.config import get_settings


def shop_timezone() -> ZoneInfo:
    return ZoneInfo(get_settings().shop_timezone)


def start_of_day(day: date) -> datetime:
    """Midnight at the start of `day` in the shop's timezone, as an aware datetime."""
    return datetime.combine(day, time.min, tzinfo=shop_timezone())


def day_range(
    first_day: date | None, last_day: date | None
) -> tuple[datetime | None, datetime | None]:
    """Half-open [start, end) bounds covering whole shop-local days, both ends inclusive."""
    start = start_of_day(first_day) if first_day else None
    end = start_of_day(last_day + timedelta(days=1)) if last_day else None
    return start, end


def shop_today() -> date:
    return datetime.now(shop_timezone()).date()
