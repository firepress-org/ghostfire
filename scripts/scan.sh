#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: scripts/scan.sh [--help]

Save IMAGE as an OCI archive, scan it with Grype, and write the JSON report
to .cache/scan/<image>.grype.json. Print the Critical, High, Medium, and Low
counts, and the fixable ones, for the OS layer (every package type but npm)
and for the npm layer. Write the Critical and High counts to
.cache/scan/summary for `just check`.

Environment:
  IMAGE  image to scan (default ghostfire:local)

Options:
  --help  print this help and exit
EOF
}

case ${1:-} in
"") ;;
-h | --help)
	usage
	exit 0
	;;
*)
	usage >&2
	exit 2
	;;
esac

image=${IMAGE:-ghostfire:local}
out=.cache/scan
slug=${image//[^A-Za-z0-9._-]/_}
archive=$out/$slug.oci.tar
report=$out/$slug.grype.json

mkdir -p "$out"
rm -f -- "$archive"
podman save -q --format oci-archive -o "$archive" "$image"
grype "oci-archive:$archive" -o json --file "$report" --quiet
rm -f -- "$archive"

# Counts per layer, keyed by severity initial; fixC to fixL count those with a fix.
counts=$(jq -c '
  def layer: if .artifact.type == "npm" then "npm" else "os" end;
  {grype: .descriptor.version, db: .descriptor.db.status.built}
  + reduce (.matches[] | select(.vulnerability.severity
      | IN("Critical", "High", "Medium", "Low"))) as $m
    ({os: {}, npm: {}};
      ($m | layer) as $l | ($m.vulnerability.severity[0:1]) as $s
      | .[$l][$s] += 1
      | if ($m.vulnerability.fix.versions // []) != [] then .[$l]["fix" + $s] += 1 else . end)
' "$report")

jq -r '
  "grype \(.grype), db built \(.db)",
  (("os", "npm") as $l | .[$l]
    | "\($l): C\(.C // 0)/H\(.H // 0)/M\(.M // 0)/L\(.L // 0), fixable C\(.fixC // 0)/H\(.fixH // 0)/M\(.fixM // 0)/L\(.fixL // 0)")
' <<<"$counts"
jq -r '"os C\(.os.C // 0)/H\(.os.H // 0), npm C\(.npm.C // 0)/H\(.npm.H // 0)"' <<<"$counts" >"$out/summary"
echo "scan: report $report"
