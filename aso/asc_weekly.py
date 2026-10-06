"""Creates the weekly Pro auto-renewable subscription next to the monthly one (idempotent).

Run with the same ASC_* environment variables as asc_push.py:  python3 aso/asc_weekly.py
Price: US $4.99 with Apple's equalized price in every other territory; no free trial.
Manual step afterwards (not available via API): the subscription review screenshot.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc_push import APP_ID, all_pages, call  # noqa: E402

GROUP_ID = "22230771"
PRODUCT_ID = "com.akbaralikhasanov.pagewise.pro.weekly"
REFERENCE_NAME = "Scanmuse Pro (Weekly)"
DISPLAY_NAME = "Scanmuse Pro (Weekly)"
DESCRIPTION = "Unlimited exports, PDF/text share, iCloud sync."
USD = "4.99"


def ensure_subscription() -> dict:
    for s in all_pages(f"/subscriptionGroups/{GROUP_ID}/subscriptions"):
        if s["attributes"]["productId"] == PRODUCT_ID:
            print("subscription exists:", s["id"])
            return s
    s = call("POST", "/subscriptions", {"data": {"type": "subscriptions", "attributes": {
        "name": REFERENCE_NAME, "productId": PRODUCT_ID, "familySharable": False,
        "subscriptionPeriod": "ONE_WEEK", "groupLevel": 2},
        "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": GROUP_ID}}}}})["data"]
    call("POST", "/subscriptionLocalizations", {"data": {"type": "subscriptionLocalizations",
         "attributes": {"locale": "en-US", "name": DISPLAY_NAME, "description": DESCRIPTION},
         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": s["id"]}}}}})
    print("subscription created:", s["id"])
    return s


def ensure_prices(sub: dict) -> list[str]:
    if call("GET", f"/subscriptions/{sub['id']}/prices", limit=1)["data"]:
        print("prices already set")
        return [t["id"] for t in all_pages("/territories", limit=200)]
    points = all_pages(f"/subscriptions/{sub['id']}/pricePoints", **{"filter[territory]": "USA", "limit": 200})
    usa = next(p for p in points if p["attributes"]["customerPrice"] == USD)
    equal = all_pages(f"/subscriptionPricePoints/{usa['id']}/equalizations", include="territory", limit=200)
    territories = ["USA"]
    for point in [usa] + equal:
        territory = "USA" if point is usa else point["relationships"]["territory"]["data"]["id"]
        call("POST", "/subscriptionPrices", {"data": {"type": "subscriptionPrices",
             "attributes": {"preserveCurrentPrice": False},
             "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub["id"]}},
                               "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": point["id"]}},
                               "territory": {"data": {"type": "territories", "id": territory}}}}})
        if point is not usa:
            territories.append(territory)
    print(f"prices set: ${USD} USA + {len(territories) - 1} equalized territories")
    return territories


def ensure_availability(sub: dict, territories: list[str]):
    res = call("GET", f"/subscriptions/{sub['id']}/subscriptionAvailability", ok_fail=True)
    if res.get("data"):
        print("availability already set")
        return
    call("POST", "/subscriptionAvailabilities", {"data": {"type": "subscriptionAvailabilities",
         "attributes": {"availableInNewTerritories": True},
         "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub["id"]}},
                           "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]}}}})
    print("available in", len(territories), "territories")


if __name__ == "__main__":
    sub = ensure_subscription()
    ensure_availability(sub, ensure_prices(sub))
    st = call("GET", f"/subscriptions/{sub['id']}")["data"]["attributes"]
    print("state:", st["state"], "| period:", st["subscriptionPeriod"], "| level:", st["groupLevel"])
