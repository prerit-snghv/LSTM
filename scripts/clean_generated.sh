#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

echo "Removing generated Vivado/XSim artifacts from ${REPO_ROOT}..."

rm -rf .Xil xsim.dir .slang
rm -f -- *.jou *.log *.pb *.wdb '$1'

echo "Done."
