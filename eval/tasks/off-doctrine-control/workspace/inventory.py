def total_value(items):
    """Total stock value: sum of price times quantity for each item."""
    return sum(item["price"] for item in items)
