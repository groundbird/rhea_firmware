#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "${script_dir}/../../.." && pwd)
sim_dir=$(mktemp -d /tmp/rhea-trigger-rbcp.XXXXXX)
trap 'rm -rf "${sim_dir}"' EXIT

cd "${sim_dir}"
xvhdl --2008 \
  "${repo_root}/src/vhdl/rhea_pkg.vhd" \
  "${repo_root}/src/vhdl/trigger.vhd" \
  "${repo_root}/src/vhdl/tb/trigger_rbcp_tb.vhd"
xelab trigger_rbcp_tb -s trigger_rbcp_tb_sim
xsim trigger_rbcp_tb_sim -runall
