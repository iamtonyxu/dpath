read_verilog {
  rtl/tfir_gain_scale.v
  rtl/tfir_filter_rtl.v
  rtl/thb1_filter_rtl.v
  rtl/thb2_filter_rtl.v
  rtl/thb3_filter_rtl.v
  rtl/int5_filter_rtl.v
  rtl/tx_dpath_rtl.v
}
synth_design -top tx_dpath_rtl -part xc7a35tcpg236-1
report_utilization -file tmp/check_tx_synth_util.rpt
quit
