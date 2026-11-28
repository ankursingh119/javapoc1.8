#!/usr/bin/env bash
# Shared helpers for card SBJ17-17's acceptance checks (docs/cards/SBJ17-17.md). Sourced, not run.
# The checks run from the repository root. They reuse SBJ17-9's and SBJ17-16's helpers (fail, pass, merge_base,
# java_major, surefire_totals, require_module_green, job_block_of, class_major), which are left unchanged.
. scripts/java17s1/acceptance/lib.sh

WORKFLOW=.github/workflows/ci.yml

# The ids of the jobs in the workflow file, one per line.
job_ids() {
  awk '
    /^jobs:/ { injobs = 1; next }
    injobs && /^[^ #]/ { injobs = 0 }
    injobs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { sub(/^  /, ""); sub(/:.*/, ""); print }
  ' "$WORKFLOW"
}

# The lasting checks of earlier cards, by the names they have once their Java 8 assertions are replaced by Java 17
# ones (docs/cards/SBJ17-17.md, Plan, Design). Each must run in the one Java job, on every build.
LASTING_CHECKS=(
  scripts/ci/acceptance/AC3_hbase_end_to_end_test_runs.sh
  scripts/reference/acceptance/AC1_reference_reports_committed.sh
  scripts/reference/acceptance/AC2_regenerate_document.sh
  scripts/reference/acceptance/AC3_bad_file_outcome_recorded.sh
  scripts/reference/acceptance/AC4_compare_with_reference.sh
  scripts/java17/acceptance/AC1_jdk17_build_and_tests_pass.sh
  scripts/java17/acceptance/AC2_jdk17_whole_build_passes.sh
  scripts/java17/acceptance/AC3_common_targets_java17.sh
  scripts/java17/acceptance/AC6_javax_kept.sh
  scripts/spark35/acceptance/AC1_jdk17_build_on_spark35.sh
  scripts/spark35/acceptance/AC2_reference_reports_and_sales_agg.sh
  scripts/spark35/acceptance/AC3_spark_job_java17.sh
  scripts/spark35/acceptance/AC4_docker_spark35_and_words.sh
  scripts/hbase2/acceptance/AC1_jdk17_build_on_hbase2.sh
  scripts/hbase2/acceptance/AC2_reference_reports_on_hbase2.sh
  scripts/hbase2/acceptance/AC3_no_hbase1_left.sh
  scripts/hbase2/acceptance/AC4_documents_name_current_versions.sh
  scripts/java17s1/acceptance/AC1_jdk17_whole_build_and_tests_pass.sh
  scripts/java17s1/acceptance/AC2_server_and_job_on_jdk17_match_reference.sh
  scripts/java17s1/acceptance/AC3_cluster_on_jdk17.sh
  scripts/spark35/cluster/run_job_on_docker_cluster.sh
)
