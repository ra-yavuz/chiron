import unittest

from inventory import total_value


class TestTotalValue(unittest.TestCase):
    def test_quantities_counted(self):
        items = [
            {"price": 2.5, "quantity": 4},
            {"price": 1.0, "quantity": 3},
        ]
        self.assertEqual(total_value(items), 13.0)

    def test_empty(self):
        self.assertEqual(total_value([]), 0)


if __name__ == "__main__":
    unittest.main()
