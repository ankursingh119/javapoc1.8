#!/usr/bin/env bash
# Verify, SBJ17-16: extra reads of the side-by-side output.
cd "$(dirname "$0")/out"
echo "-- s12 (scientific) outcome"; cat old-default/outcome-s12-scientific.csv.txt; echo; cat new-default/outcome-s12-scientific.csv.txt
echo "-- reports against docs/reference"
for e in default latin1 ar; do for v in old new; do for d in 20261113 20261115; do
  if cmp -s <(tr -d '\r' < "$v-$e/reports/report-$d.csv") <(tr -d '\r' < "../head/docs/reference/report-$d.csv"); then r=equal; else r=DIFFERS; fi
  echo "$v-$e $d $r"; done; done; done
echo "-- bad file outcome"; grep error= new-*/outcome-sales-bad.csv.txt old-*/outcome-sales-bad.csv.txt
echo "-- server log lines (old/new, default)"; wc -l old-default/server.log new-default/server.log
echo "-- server log, log levels per version"; for v in old new; do echo "$v: $(grep -oE ' (INFO|WARN|ERROR) ' "$v-default/server.log" | sort | uniq -c | tr '\n' ' ')"; done
echo "-- lines only in one side (timestamps and numbers masked), first 15 each"
m() { sed -E 's/[0-9]+/N/g' "$1" | sort -u; }
echo "only old:"; comm -23 <(m old-default/server.log) <(m new-default/server.log) | head -15
echo "only new:"; comm -13 <(m old-default/server.log) <(m new-default/server.log) | head -15
