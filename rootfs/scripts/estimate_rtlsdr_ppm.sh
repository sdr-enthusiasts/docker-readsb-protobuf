#!/usr/bin/with-contenv bash
# shellcheck shell=bash

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
timeout 30m rtl_test -p | tee "$TEMPFILE_RTL_TEST_OUTPUT"

# Determine & show results
echo ""
echo -e "${WHITE}Results:${NOCOLOR}"
grep -oP '^real sample rate: \d+ current PPM: \-?\d+ cumulative PPM: \K\-?\d+$' "$TEMPFILE_RTL_TEST_OUTPUT" > "$TEMPFILE_RTL_TEST_PPM_VALUES"
for i in $(sort -u ppm_values "$TEMPFILE_RTL_TEST_PPM_VALUES"); do
    echo "PPM setting of: $i, Score of: $(grep --count -oP "^$i\$" "$TEMPFILE_RTL_TEST_PPM_VALUES")" >> "$TEMPFILE_RTL_TEST_PPM_SCORES"
done
echo -e "${WHITE}"
cat "$TEMPFILE_RTL_TEST_PPM_SCORES" | sort -nk 7
echo -e "${NOCOLOR}"

# Show estimated optimum ppm setting
echo ""
echo "${WHITE}Estimated optimum PPM setting: $(cat ppm_scores | sort -nk 7 | tail -1 | cut -d ' ' -f 4 | tr -d ',')${NOCOLOR}"
echo ""

# Clean up
rm "$TEMPFILE_RTL_TEST_OUTPUT" "$TEMPFILE_RTL_TEST_PPM_VALUES" "$TEMPFILE_RTL_TEST_PPM_SCORES"
