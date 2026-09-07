#!/bin/bash
set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd "$script_dir/../../.." && pwd)
build_dir="${TMPDIR:-/tmp}/rhea_net_xsim"

mkdir -p "$build_dir"
cd "$build_dir"

python3 "$repo_root/tools/generate_net_test_vectors.py" .

xvlog --sv \
  "$repo_root/src/net/gmii_rx_frame.v" \
  "$repo_root/src/net/gmii_tx_frame.v" \
  "$repo_root/src/net/tcp_tx_replay_buffer.v" \
  "$repo_root/src/net/rbcp_cdc_bridge.v" \
  "$repo_root/src/net/arp_icmp_server.v" \
  "$repo_root/src/net/tcp_tx_async_adapter.v" \
  "$repo_root/src/net/tb/arp_icmp_tb.sv" \
  "$repo_root/src/net/tb/tcp_benchmark_tb.sv" \
  "$repo_root/src/net/tb/tcp_retransmit_tb.sv" \
  "$repo_root/src/net/tb/tcp_tx_async_adapter_tb.sv" \
  "$repo_root/src/net/tb/tcp_tx_replay_buffer_tb.sv" \
  "$repo_root/src/net/tb/rbcp_cdc_bridge_tb.sv" \
  "$repo_root/src/net/tb/rbcp_udp_tb.sv"

xvhdl --2008 \
  "$repo_root/src/vhdl/rbcp_transfer_from_sitcp.vhd" \
  "$repo_root/src/vhdl/rbcp_transfer_to_sitcp.vhd" \
  "$repo_root/src/vhdl/tb/rbcp_transfer_toggle_tb.vhd"

xelab rbcp_transfer_toggle_tb -s rbcp_transfer_toggle_sim
xsim rbcp_transfer_toggle_sim -runall
xelab rbcp_cdc_bridge_tb -s rbcp_cdc_bridge_sim
xsim rbcp_cdc_bridge_sim -runall
xelab rbcp_udp_tb -s rbcp_udp_sim
xsim rbcp_udp_sim -runall

for test_name in arp_icmp tcp_benchmark tcp_retransmit \
    tcp_tx_async_adapter tcp_tx_replay_buffer; do
  xelab "${test_name}_tb" -s "${test_name}_sim"
  xsim "${test_name}_sim" -runall
done
