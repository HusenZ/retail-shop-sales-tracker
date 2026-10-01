import re
from typing import Annotated, ClassVar, Self

from pydantic import BaseModel, BeforeValidator, ConfigDict, StringConstraints, model_validator

ShortText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
LongText = Annotated[str, StringConstraints(strip_whitespace=True, max_length=2000)]

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
