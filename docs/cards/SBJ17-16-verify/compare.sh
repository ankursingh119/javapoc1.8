#!/usr/bin/env bash
# Verify, SBJ17-16: compare out/old-<env> with out/new-<env> per input: outcome (status, error, approval, report),
# report bytes (CRLF-insensitive), and the sales_agg scan (cell timestamps masked). Writes summary.txt.
set -uo pipefail
cd "$(dirname "$0")/out"
{
for e in default latin1 ar; do
  o=old-$e; n=new-$e; total=0; diff=0
  echo "== environment $e"
  for f in "$o"/outcome-*.txt; do
    b=$(basename "$f"); total=$((total + 1))
    d=$(grep -m1 '^businessDate=' "$f" | cut -d= -f2)
    od=""; cmp -s "$f" "$n/$b" || od="outcome"
    ro="$o/reports/report-$d.csv"; rn="$n/reports/report-$d.csv"
    if [ -f "$ro" ] || [ -f "$rn" ]; then
      cmp -s <(tr -d '\r' < "$ro" 2>/dev/null) <(tr -d '\r' < "$rn" 2>/dev/null) || od="$od report"
    fi
    st=$(grep '^status=' "$f" | cut -d= -f2)
    if [ -n "$od" ]; then diff=$((diff + 1)); echo "DIFF $b ($od): old[$(grep -E '^(status|error)=' "$f" | tr '\n' ' ')] new[$(grep -E '^(status|error)=' "$n/$b" | tr '\n' ' ')]"
    else echo "same $b $st"; fi
  done
  mask() { sed -E 's/timestamp=[0-9]+/timestamp=T/; s/[0-9.]+ seconds//' "$1" | grep -E 'column=' | sort; }
  if cmp -s <(mask "$o/hbase-sales_agg.txt") <(mask "$n/hbase-sales_agg.txt"); then echo "sales_agg: same ($(mask "$o/hbase-sales_agg.txt" | wc -l) cells)"
  else diff=$((diff + 1)); echo "sales_agg: DIFF"; diff <(mask "$o/hbase-sales_agg.txt") <(mask "$n/hbase-sales_agg.txt") | head -10; fi
  echo "java: old $(grep -m1 version "$o/java-version.txt" | tr -d '\r') / new $(grep -m1 version "$n/java-version.txt" | tr -d '\r')"
  echo "job java (stand-in log): old $(grep -ho 'version "[^"]*"' "$o/spark-standin.log" | sort -u | tr '\n' ' ') / new $(grep -ho 'version "[^"]*"' "$n/spark-standin.log" | sort -u | tr '\n' ' ')"
  echo "inputs $total, differing $diff"
done
} > ../summary.txt
cat ../summary.txt
