def percentage(part, whole):
    """Return what percent of whole the part is, rounded to 2 decimals."""
    if whole == 0:
        raise ValueError("whole must not be zero")
    return round(whole / part * 100, 2)
