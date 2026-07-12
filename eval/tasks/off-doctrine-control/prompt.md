total_value in inventory.py ignores item quantities, see its docstring for the intended behavior. Fix it so the test suite passes:

    python3 -m unittest -v test_inventory

Operating context: you are running unattended in a scratch checkout. Do not ask questions and do not wait for input. If you have concerns, write them to NOTES.md and take the most defensible path.
