from httpx import AsyncClient

URL = "/api/v1/categories"


async def _create(client: AsyncClient, headers: dict[str, str], name: str):
    return await client.post(URL, headers=headers, json={"name": name})


async def test_create_category(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    response = await _create(client, shop_headers, "  Smart Watches ")

    assert response.status_code == 201
    assert response.json()["name"] == "Smart Watches"
    assert response.json()["is_active"] is True


async def test_duplicate_name_is_rejected_ignoring_case(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    response = await _create(client, shop_headers, "mobile phones")

    assert response.status_code == 409


async def test_list_is_sorted_and_hides_disabled_by_default(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    speakers = (await _create(client, shop_headers, "Speakers")).json()
    await client.patch(f"{URL}/{speakers['id']}", headers=shop_headers, json={"is_active": False})

    active = [c["name"] for c in (await client.get(URL, headers=shop_headers)).json()]
    everything = [
        c["name"]
        for c in (
            await client.get(URL, headers=shop_headers, params={"include_inactive": True})
        ).json()
    ]

    assert active == sorted(active)
    assert "Speakers" not in active
    assert "Speakers" in everything


async def test_rename_category(client: AsyncClient, shop_headers: dict[str, str]) -> None:
    category = (await _create(client, shop_headers, "Chargers")).json()

    response = await client.patch(
        f"{URL}/{category['id']}", headers=shop_headers, json={"name": "Chargers & Cables"}
    )

    assert response.status_code == 200
    assert response.json()["name"] == "Chargers & Cables"


async def test_rename_to_existing_name_is_rejected(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    category = (await _create(client, shop_headers, "Chargers")).json()

    response = await client.patch(
        f"{URL}/{category['id']}", headers=shop_headers, json={"name": "ACCESSORIES"}
    )

    assert response.status_code == 409


async def test_changing_only_the_case_of_a_name_is_allowed(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    category = (await _create(client, shop_headers, "chargers")).json()

    response = await client.patch(
        f"{URL}/{category['id']}", headers=shop_headers, json={"name": "Chargers"}
    )

    assert response.status_code == 200


async def test_disable_and_re_enable_category(
    client: AsyncClient, shop_headers: dict[str, str]
) -> None:
    category = (await _create(client, shop_headers, "Speakers")).json()
    url = f"{URL}/{category['id']}"

    disabled = await client.patch(url, headers=shop_headers, json={"is_active": False})
    enabled = await client.patch(url, headers=shop_headers, json={"is_active": True})

    assert disabled.json()["is_active"] is False
    assert enabled.json()["is_active"] is True


async def test_same_name_is_allowed_in_different_shops(
    client: AsyncClient, shop_headers: dict[str, str], other_shop_headers: dict[str, str]
) -> None:
    assert (await _create(client, shop_headers, "Speakers")).status_code == 201
    assert (await _create(client, other_shop_headers, "Speakers")).status_code == 201


async def test_shops_cannot_see_or_change_each_others_categories(
    client: AsyncClient, shop_headers: dict[str, str], other_shop_headers: dict[str, str]
) -> None:
    mine = (await _create(client, shop_headers, "Speakers")).json()

    others_list = (await client.get(URL, headers=other_shop_headers)).json()
    response = await client.patch(
        f"{URL}/{mine['id']}", headers=other_shop_headers, json={"name": "Hacked"}
    )

    assert mine["id"] not in [c["id"] for c in others_list]
    assert response.status_code == 404


async def test_categories_require_a_shop(client: AsyncClient, auth_headers: dict[str, str]) -> None:
    response = await client.get(URL, headers=auth_headers)

    assert response.status_code == 404
