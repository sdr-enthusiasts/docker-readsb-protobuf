#!/usr/bin/env bash

# Define colors
WHITE='\033[1;37m'
NOCOLOR='\033[0m'

# Prepare temp files
TEMPFILE_RTL_TEST_OUTPUT=$(mktemp --tmpdir=/tmp tmp.rtl_test.output.XXXXXXXXXXXXXXXX)
TEMPFILE_RTL_TEST_PPM_VALUES=$(mktemp --tmpdir=/tmp tmp.rtl_test.ppm_values.XXXXXXXXXXXXXXXX)
TEMPFILE_RTL_TEST_PPM_SCORES=$(mktemp --tmpdir=/tmp tmp.rtl_test.ppm_scores.XXXXXXXXXXXXXXXX)

# Run rtl_test -p for 30 minutes
echo ""
echo -e "${WHITE}Running rtl_test -p for 30 minutes${NOCOLOR}"
echo ""
timeout 30m stdbuf -oL rtl_test -p 2>&1 | tee "$TEMPFILE_RTL_TEST_OUTPUT"

# Determine & show results
echo ""
echo -e "${WHITE}Results:${NOCOLOR}"
echo ""
grep -oP '^real sample rate: \d+ current PPM: \-?\d+ cumulative PPM: \K\-?\d+$' "$TEMPFILE_RTL_TEST_OUTPUT" > "$TEMPFILE_RTL_TEST_PPM_VALUES"
# shellcheck disable=SC2013
for i in $(sort -u "$TEMPFILE_RTL_TEST_PPM_VALUES"); do
    echo "PPM setting of: $i, Score of: $(grep --count -oP "^$i\$" "$TEMPFILE_RTL_TEST_PPM_VALUES")" >> "$TEMPFILE_RTL_TEST_PPM_SCORES"
done
sort -nk 7 "$TEMPFILE_RTL_TEST_PPM_SCORES"

# Show estimated optimum ppm setting
echo ""
echo -e "${WHITE}Estimated optimum PPM setting: $(sort -nk 7 "$TEMPFILE_RTL_TEST_PPM_SCORES" | tail -1 | cut -d ' ' -f 4 | tr -d ',')${NOCOLOR}"
echo ""

# Clean up
rm "$TEMPFILE_RTL_TEST_OUTPUT" "$TEMPFILE_RTL_TEST_PPM_VALUES" "$TEMPFILE_RTL_TEST_PPM_SCORES"
