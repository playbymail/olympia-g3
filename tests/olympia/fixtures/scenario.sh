#!/bin/bash
###########################################################################
# Shared helpers for regress fixtures stored as a patch over one base world
# (issue #121). Source this file; do not run it.
#
# A one-turn fixture's pre-turn `lib` is nearly all the post-init world, so
# instead of a full scenario.tgz each fixture commits a plain-text
# scenario.patch against world.tgz (this directory; built by build-world.sh):
#
#   scenario_unpack <fixture dir> <work dir>
#       extract world.tgz into <work dir> and apply <fixture dir>/scenario.patch;
#       fails (exit status 2) with a clear message when the patch was taken
#       against a different world, i.e. world.tgz was re-baselined and the
#       fixture was not rebuilt.
#
#   scenario_write <work dir> <fixture dir>
#       write <fixture dir>/scenario.patch as the diff from world.tgz to
#       <work dir>/lib, then unpack it again and check that it reproduces
#       <work dir>/lib byte for byte (fails with exit status 2 if not).
#
# The patch's first line, `world-sha256: <hash>`, pins the base it was taken
# against: a hash over every file in world.tgz's lib (scenario_world_id).
# patch(1) skips it as leading text. It is checked before applying, because a
# world change outside the patch's hunks would otherwise apply cleanly and
# silently change the fixture's input. The rest is one `diff -u` per changed
# file, in sorted path order, with fixed labels (a/lib/... b/lib/..., /dev/null
# for an added or removed file) and no timestamps, so rebuilding an unchanged
# fixture rewrites it unchanged.
###########################################################################

SCENARIO_FIXTURES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO_WORLD="${SCENARIO_FIXTURES}/world.tgz"

scenario_world_id() {	# args: dir holding an extracted lib
	( cd "$1" && find lib -type f | LC_ALL=C sort | xargs shasum -a 256 ) | shasum -a 256 | cut -c1-64
}

scenario_unpack() {	# args: fixture-dir work-dir
	local fx work="$2" want have
	fx="$(cd "$1" && pwd)" || return 2
	[ -f "${SCENARIO_WORLD}" ] || { echo "error: missing ${SCENARIO_WORLD} (run tests/olympia/fixtures/build-world.sh)"; return 2; }
	[ -f "${fx}/scenario.patch" ] || { echo "error: missing ${fx}/scenario.patch (run ./build-scenario.sh)"; return 2; }
	tar zxf "${SCENARIO_WORLD}" -C "${work}" || return 2
	want="$(sed -n '1s/^world-sha256: //p' "${fx}/scenario.patch")"
	have="$(scenario_world_id "${work}")"
	if [ "${want}" != "${have}" ]; then
		echo "error: ${fx}/scenario.patch was taken against a different world.tgz"
		echo "       (world.tgz was re-baselined? re-run that fixture's build-scenario.sh)"
		echo "       patch: ${want:-(no world-sha256 line)}"
		echo "       world: ${have}"
		return 2
	fi
	if ! patch -s -t -N -E -F 0 -p1 -d "${work}" -i "${fx}/scenario.patch" </dev/null >"${work}/patch.log" 2>&1; then
		echo "error: ${fx}/scenario.patch does not apply cleanly to world.tgz"
		echo "       (world.tgz was re-baselined? re-run that fixture's build-scenario.sh)"
		sed 's/^/       /' "${work}/patch.log"
		return 2
	fi
	rm -f "${work}/patch.log"
}

scenario_write() {	# args: work-dir fixture-dir
	local work="$1" fx="$2" base chk f rc
	[ -f "${SCENARIO_WORLD}" ] || { echo "error: missing ${SCENARIO_WORLD} (run tests/olympia/fixtures/build-world.sh)"; return 2; }
	base="$(mktemp -d)"
	tar zxf "${SCENARIO_WORLD}" -C "${base}" || { rm -rf "${base}"; return 2; }

	printf 'world-sha256: %s\n' "$(scenario_world_id "${base}")" > "${fx}/scenario.patch"
	while IFS= read -r f; do
		# diff exits 1 when the files differ; `|| rc=$?` keeps a caller's set -e
		rc=0
		if [ ! -f "${base}/${f}" ]; then
			diff -u --label /dev/null --label "b/${f}" /dev/null "${work}/${f}" || rc=$?
		elif [ ! -f "${work}/${f}" ]; then
			diff -u --label "a/${f}" --label /dev/null "${base}/${f}" /dev/null || rc=$?
		else
			diff -u --label "a/${f}" --label "b/${f}" "${base}/${f}" "${work}/${f}" || rc=$?
		fi >> "${fx}/scenario.patch"
		[ "${rc}" -le 1 ] || { echo "error: diff failed on ${f}"; rm -rf "${base}"; return 2; }
	done < <( { (cd "${base}" && find lib -type f); (cd "${work}" && find lib -type f); } | LC_ALL=C sort -u )

	# round trip: the patch must rebuild the exact lib it was taken from
	chk="$(mktemp -d)"
	if ! scenario_unpack "${fx}" "${chk}" || ! diff -r "${work}/lib" "${chk}/lib" >/dev/null; then
		echo "error: ${fx}/scenario.patch does not reproduce the built lib"
		diff -r "${work}/lib" "${chk}/lib" | head -20
		rm -rf "${base}" "${chk}"
		return 2
	fi
	rm -rf "${base}" "${chk}"
}
