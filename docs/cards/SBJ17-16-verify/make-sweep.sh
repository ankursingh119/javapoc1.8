#!/usr/bin/env bash
# Verify, SBJ17-16: the input sweep for the side-by-side run (main on Java 8 against the PR head on Java 17).
# Writes sweep/<file> and sweep/inputs-all.txt / inputs-env.txt ("file date" lines, one date per input).
set -euo pipefail
cd "$(dirname "$0")"
S=sweep; rm -rf "$S"; mkdir -p "$S"
H='orderId,productId,region,qty,amount'
cp head/sample-data/sales-20261113.csv head/sample-data/sales-20261115.csv head/sample-data/sales-bad.csv "$S/"
w() { printf '%b' "$2" > "$S/$1"; }
w s01-empty.csv            ''
w s02-header-only.csv      "$H\n"
w s03-one-row.csv          "$H\nA1,P1,EU,1,1.00\n"
w s04-neg-qty.csv          "$H\nA1,P1,EU,-2,10.50\nA2,P1,EU,3,15.75\n"
w s05-neg-amount.csv       "$H\nA1,P1,EU,2,-10.50\nA2,P1,EU,3,15.75\n"
w s06-zero.csv             "$H\nA1,P1,EU,0,0.00\n"
w s07-qty-int-overflow.csv "$H\nA1,P1,EU,2147483647,1.00\nA2,P1,EU,1,1.00\n"
w s08-large-amount.csv     "$H\nA1,P1,EU,1,999999999999999.99\nA2,P1,EU,1,0.01\n"
w s09-ties.csv             "$H\nA1,P1,EU,1,0.125\nA2,P2,EU,1,0.005\nA3,P3,EU,1,2.675\nA4,P4,EU,1,1.005\nA5,P5,EU,1,0.015\n"
w s10-extra-decimals.csv   "$H\nA1,P1,EU,1,10.123456789\nA2,P1,EU,1,0.333333333\nA3,P1,EU,1,0.1\nA4,P1,EU,1,0.2\n"
w s11-no-decimals.csv      "$H\nA1,P1,EU,1,10\nA2,P1,US,2,7\n"
w s12-scientific.csv       "$H\nA1,P1,EU,1,1e3\nA2,P1,EU,1,2.5E-1\n"
w s13-reordered.csv        "$H\nA4,P1,US,5,30.00\nA3,P2,US,1,4.00\nA2,P1,EU,3,15.75\nA1,P1,EU,2,10.50\n"
w s14-crlf.csv             "$H\r\nA1,P1,EU,2,10.50\r\nA2,P1,EU,3,15.75\r\nA3,P2,US,1,4.00\r\n"
w s15-spaces.csv           "$H\nA1, P1 , EU ,2, 10.50\nA2,P1,EU, 3 ,15.75 \n"
w s16-unicode-region.csv   "$H\nA1,P1,Ünïcødé,2,10.50\nA2,P1,日本,3,15.75\nA3,P1,İstanbul,1,1.00\nA4,P1,istanbul,1,1.00\n"
w s17-lowercase-region.csv "$H\nA1,P1,eu,2,10.50\nA2,P1,EU,3,15.75\n"
w s18-empty-qty.csv        "$H\nA1,P1,EU,,10.50\n"
w s19-empty-amount.csv     "$H\nA1,P1,EU,2,\n"
w s20-empty-region.csv     "$H\nA1,P1,,2,10.50\n"
w s21-extra-column.csv     "$H\nA1,P1,EU,2,10.50,extra\n"
w s22-missing-column.csv   "$H\nA1,P1,EU,2\n"
w s23-quoted.csv           "$H\n\"A1\",\"P1\",\"EU\",2,10.50\n"
w s24-decimal-qty.csv      "$H\nA1,P1,EU,2.5,10.50\n"
w s25-comma-decimal.csv    "$H\nA1,P1,EU,2,\"10,50\"\n"
w s26-dup-order.csv        "$H\nA1,P1,EU,2,10.50\nA1,P1,EU,2,10.50\n"
w s27-bom.csv              "\xef\xbb\xbf$H\nA1,P1,EU,2,10.50\n"
w s28-header-reordered.csv "orderId,region,productId,amount,qty\nA1,EU,P1,10.50,2\n"
w s29-arabic-digits.csv    "$H\nA1,P1,EU,٢,١٠.٥٠\n"
w s30-no-trailing-nl.csv   "$H\nA1,P1,EU,2,10.50"
{ echo "$H"; for i in $(seq 1 1000); do echo "O$i,P$((i % 7)),R$((i % 5)),$((i % 13 + 1)),$((i * 37 % 1000)).$((i % 100 / 10))$((i % 10))"; done; } > "$S/s31-many-rows.csv"

{
  echo "sales-20261113.csv 20261113"; echo "sales-20261115.csv 20261115"; echo "sales-bad.csv 20261116"
  n=0; for f in $(cd "$S" && ls s[0-9][0-9]-*.csv); do n=$((n + 1)); printf '%s 202701%02d\n' "$f" "$n"; done
} > "$S/inputs-all.txt"
grep -E '^(sales-|s0[5789]-|s10-|s14-|s16-|s27-|s29-|s31-)' "$S/inputs-all.txt" > "$S/inputs-env.txt"
wc -l "$S/inputs-all.txt" "$S/inputs-env.txt"
