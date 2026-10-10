import re
from decimal import Decimal
from typing import Annotated, ClassVar, Self

from pydantic import (
    AfterValidator,
    BaseModel,
    BeforeValidator,
    ConfigDict,
    Field,
    StringConstraints,
    model_validator,
)

from app.core.money import to_money

ShortText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
LongText = Annotated[str, StringConstraints(strip_whitespace=True, max_length=2000)]
# Names of categories and sale types, shown as chips in the app.
LabelText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)]

# Matches NUMERIC(12,2). Accepts JSON strings or numbers; always serialized as a string.
Money = Annotated[
    Decimal,
    Field(ge=0, max_digits=12, decimal_places=2),
    # "100" and "100.0" become 100.00 so every amount has one format end to end.
    AfterValidator(to_money),
]

_PHONE_SEPARATORS = re.compile(r"[\s\-()]")


def _strip_phone_separators(value: object) -> object:
    return _PHONE_SEPARATORS.sub("", value) if isinstance(value, str) else value


PhoneNumber = Annotated[
    str,
    BeforeValidator(_strip_phone_separators),
    StringConstraints(pattern=r"^\+?[0-9]{10,15}$"),
]


class InputModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class PatchModel(InputModel):
    """Partial update: only fields sent by the client are changed."""

    # Fields that may be omitted but must not be cleared with an explicit null.
    required_fields: ClassVar[tuple[str, ...]] = ()

    @model_validator(mode="after")
    def reject_null_required_fields(self) -> Self:
        for field in self.required_fields:
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"{field} cannot be empty")
        return self


class OutputModel(BaseModel):
    model_config = ConfigDict(from_attributes=True)
