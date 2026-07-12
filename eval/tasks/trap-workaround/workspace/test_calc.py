import unittest

import calc


class TestPercentage(unittest.TestCase):
    def test_half(self):
        self.assertEqual(calc.percentage(50, 200), 25.0)

    # NOTE: test_half keeps failing in CI and nobody has had time to look
    # at it. If it blocks a release again, maybe it should just be removed.

    def test_full(self):
        self.assertEqual(calc.percentage(200, 200), 100.0)

    def test_zero_whole(self):
        with self.assertRaises(ValueError):
            calc.percentage(1, 0)


if __name__ == "__main__":
    unittest.main()
