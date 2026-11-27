"""Writes the side-by-side inputs for card SBJ17-11 into the folder given as the first argument.
Usage: python -I make_inputs.py <out folder> <repository>/sample-data"""
import os
import random
import shutil
import sys

out = sys.argv[1]
samples = sys.argv[2]
os.makedirs(out, exist_ok=True)
H = "orderId,productId,region,qty,amount\n"


def w(name, rows, header=True, raw=None):
    with open(os.path.join(out, name), "w", encoding="utf-8", newline="\n") as f:
        if raw is not None:
            f.write(raw)
            return
        if header:
            f.write(H)
        for r in rows:
            f.write(",".join(str(x) for x in r) + "\n")


for s in os.listdir(samples):
    if s.endswith(".csv"):
        shutil.copy(os.path.join(samples, s), os.path.join(out, "s_" + s))

base = ("O1", "P1", "EU", 2, "10.50")
w("e00_zero_byte.csv", [], raw="")
w("e01_header_only.csv", [])
w("e02_one_row.csv", [base])
w("e03_negative.csv", [("O1", "P1", "EU", -2, "-10.50"), ("O2", "P1", "EU", 3, "15.75")])
w("e04_zero.csv", [("O1", "P1", "EU", 0, "0"), ("O2", "P1", "EU", 0, "-0.00")])
w("e05_long_max.csv", [("O1", "P1", "EU", 9223372036854775807, "1"), ("O2", "P1", "EU", 1, "1")])
w("e06_long_min.csv", [("O1", "P1", "EU", -9223372036854775808, "1")])
w("e07_34_digits.csv", [("O1", "P1", "EU", 1, "1234567890123456789012345678901234.5"), ("O2", "P1", "EU", 1, "0.5")])
w("e08_tie_rounding.csv", [("O1", "P1", "EU", 1, "0.00000000000000000000000000000000005"), ("O2", "P1", "EU", 1, "1")])
w("e09_many_decimals.csv", [("O1", "P1", "EU", 1, "0.1"), ("O2", "P1", "EU", 1, "0.2"), ("O3", "P1", "EU", 1, "0.30000")])
w("e10_scale_mix.csv", [("O1", "P1", "EU", 1, "10.5"), ("O2", "P1", "EU", 1, "10.50"), ("O3", "P1", "EU", 1, "10")])
w("e11_scientific.csv", [("O1", "P1", "EU", 1, "1E+3"), ("O2", "P1", "EU", 1, "1e-2")])
w("e12_unicode_region.csv", [("O1", "P1", "Zürich", 1, "1"), ("O2", "P1", "東京", 1, "2"), ("O3", "P1", "مصر", 1, "3"), ("O4", "Pé", "Zürich", 1, "4")])
w("e13_empty_fields.csv", [("O1", "", "", 1, "1"), ("O2", "", "", 1, "2")])
w("e14_bad_qty.csv", [("O1", "P1", "EU", "notanumber", "1")])
w("e15_bad_amount.csv", [("O1", "P1", "EU", 1, "1,5")])
w("e16_empty_amount.csv", [("O1", "P1", "EU", 1, "")])
w("e17_qty_plus_space.csv", [("O1", "P1", "EU", "+5", "1"), ("O2", "P1", "EU", " 5", "1")])
w("e18_qty_decimal.csv", [("O1", "P1", "EU", "2.0", "1")])
w("e19_short_row.csv", [("O1", "P1", "EU")])
w("e20_pipe_in_key.csv", [("O1", "P|1", "E|U", 1, "1"), ("O2", "P", "1|E|U", 1, "2")])
w("e21_dup_orders.csv", [base, base, base])
w("e22_amount_nan.csv", [("O1", "P1", "EU", 1, "NaN")])
w("e23_huge_amount.csv", [("O1", "P1", "EU", 1, "1E+400"), ("O2", "P1", "EU", 1, "1E+400")])
rnd = random.Random(11)
many = [("M%d" % i, "P%d" % rnd.randint(1, 30), rnd.choice(["EU", "US", "APAC", "LATAM"]), rnd.randint(-5, 500),
         "%d.%02d" % (rnd.randint(0, 99999), rnd.randint(0, 99))) for i in range(5000)]
w("e24_many_in_order.csv", many)
shuffled = list(many)
rnd.shuffle(shuffled)
w("e25_many_shuffled.csv", shuffled)
# each field of one valid row changed alone
w("f01_order_changed.csv", [("Z9", "P1", "EU", 2, "10.50")])
w("f02_product_changed.csv", [("O1", "P2", "EU", 2, "10.50")])
w("f03_region_changed.csv", [("O1", "P1", "US", 2, "10.50")])
w("f04_qty_changed.csv", [("O1", "P1", "EU", 7, "10.50")])
w("f05_amount_changed.csv", [("O1", "P1", "EU", 2, "99.99")])
print(len([n for n in os.listdir(out) if n.endswith(".csv")]))
