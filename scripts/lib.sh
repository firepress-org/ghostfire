# shellcheck shell=bash
# shellcheck disable=SC2154 # the caller sets name
# Shared by test-image.sh and lane.sh. The caller sets name (the container) and
# calls parse_url, which sets host (the Host header), proto (sent as
# X-Forwarded-Proto), and path.

port=
proto=
started=

# Sets proto, host, and path, with a trailing slash, from a url such as
# https://example.com/blog.
parse_url() {
	local rest=${1#*://}
	proto=${1%%://*}
	host=${rest%%/*}
	path=/
	if [[ $rest == */* ]]; then path=/${rest#*/}; fi
	path=${path%/}/
}

fail() {
	echo "FAIL: $*" >&2
	echo "--- container logs ($name) ---" >&2
	podman logs "$name" >&2 || true
	exit 1
}

# Prints the response body, then the HTTP status on its own last line.
fetch() {
	curl -sS --max-time 10 -H "Host: $host" ${proto:+-H "X-Forwarded-Proto: $proto"} \
		-w '\n%{http_code}' "http://127.0.0.1:$port$1" 2>/dev/null || printf '\n000'
}

status_of() { tail -n 1 <<<"$1"; }

start() {
	started=$EPOCHREALTIME
	podman run -d --name "$name" -p 127.0.0.1::2368 "$@" >/dev/null
	port=$(podman port "$name" 2368/tcp)
	port=${port##*:}
}

# Waits for HTTP 200 on a path, then prints the response.
wait_for_200() {
	local path=$1 timeout=$2 response deadline=$((SECONDS + $2))
	while :; do
		response=$(fetch "$path")
		if [[ $(status_of "$response") == 200 ]]; then
			printf '%s' "$response"
			return
		fi
		[[ $(podman inspect -f '{{.State.Running}}' "$name") == true ]] ||
			fail "container exited before HTTP 200 on $path"
		((SECONDS < deadline)) || fail "no HTTP 200 on $path after ${timeout}s"
		sleep 1
	done
}

print_timing() {
	local elapsed_us=$((${EPOCHREALTIME/./} - ${started/./}))
	printf 'timing: first HTTP 200 after %d.%ds\n' \
		$((elapsed_us / 1000000)) $((elapsed_us / 100000 % 10))
}

# Checks that <base>ghost/ and the admin site API answer 200, and sets version
# from the API response.
check_admin() {
	local base=$1 path response status
	for path in "${base}ghost/" "${base}ghost/api/admin/site/"; do
		response=$(fetch "$path")
		status=$(status_of "$response")
		[[ $status == 200 ]] || fail "$path answered $status"
		echo "$path 200"
	done
	version=$(sed -n 's/.*"version":"\([^"]*\)".*/\1/p' <<<"$response")
	[[ -n $version ]] || fail "${base}ghost/api/admin/site/ has no version"
}
