#!/usr/bin/env -S bash -x
#
# Driver script for trace_delacks.bt. Creates a tmpfs to store results.

set -eou pipefail

# Check that the number of command line arguments is exactly 1
if [ "$#" -ne 1 ]; then
    echo "Usage: ./trace_delacks.sh <wait duration (seconds)>"
    exit 1
fi

wait_sec="$1"
src_dir="$(realpath "$(dirname "$0")")"
out_dir="$src_dir"/out
tmpfs="$out_dir"/tmpfs
out_file_tmpfs="$tmpfs"/trace_delacks.log
out_file="$out_dir"/trace_delacks.log

# If $tmpfs exists, then clean it up
if [ -d "$tmpfs" ]; then
    rm -rf "${tmpfs:?}"/*
    # Check if $tmpfs is a mountpoint
    if mountpoint -q "$tmpfs"; then
        sudo umount -v "$tmpfs"
    fi
    rmdir -v "$tmpfs"
fi

# Prepare tmpfs
rm -rf "$tmpfs"
mkdir -pv "$tmpfs"
sudo mount -v -t tmpfs none "$tmpfs" -o size=10G

# Run tracing
echo "Tracing for $wait_sec seconds..."
set +e
timeout --signal=SIGKILL "$wait_sec"s sudo bpftrace "$src_dir"/trace_delacks.bt >"$out_file_tmpfs" 2>&1
set -e

# Move results to out_dir
mkdir -pv "$out_dir"
mv -fv "$out_file_tmpfs" "$out_file"

# Clean up tmpfs
rm -rf "${tmpfs:?}"/*
# umount claims the mountpoint is busy, so sleep for a bit
sleep 1
sudo umount -v "$tmpfs"
rmdir -v "$tmpfs"

# Inspect results
echo "Output size:"
du -h "$out_file"
wc -l "$out_file"
