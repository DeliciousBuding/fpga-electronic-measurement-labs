param(
    [string]$Output = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'task3.stp')
)

$ErrorActionPreference = 'Stop'

function Escape-XmlAttr([string]$Value) {
    return [System.Security.SecurityElement]::Escape($Value)
}

$signals = @(
    'clk',
    'nrst',
    'debug_toggle',
    'tx_dout',
    'u_counter|q[0]',
    'u_counter|q[1]',
    'u_counter|q[2]',
    'u_counter|q[3]',
    'u_counter|cout',
    'slow_div[0]',
    'slow_div[1]',
    'slow_div[2]',
    'slow_div[3]',
    'slow_div[4]',
    'slow_div[5]',
    'slow_div[6]',
    'slow_div[7]',
    'slow_div[8]',
    'slow_div[9]',
    'slow_div[10]',
    'slow_div[11]',
    'slow_div[12]',
    'slow_div[13]',
    'slow_div[14]',
    'slow_div[15]',
    'slow_div[16]',
    'slow_div[17]',
    'slow_div[18]',
    'slow_div[19]',
    'slow_div[20]',
    'slow_div[21]',
    'slow_div[22]',
    'slow_div[23]',
    'wr_fifo_wrreq',
    'rd_fifo_rdreq',
    'u_uart_tx|tx_busy',
    'u_uart_tx|tx_done'
)

$wireList = foreach ($signal in $signals) {
    '          <wire name="{0}" tap_mode="classic"/>' -f (Escape-XmlAttr $signal)
}

$nodeList = for ($i = 0; $i -lt $signals.Count; $i++) {
    $signal = Escape-XmlAttr $signals[$i]
    $selected = if ($signals[$i] -in @('u_counter|cout', 'wr_fifo_wrreq', 'rd_fifo_rdreq', 'u_uart_tx|tx_done')) { 'true' } else { 'false' }
    '          <node data_index="{0}" duplicate_name_allowed="false" is_data_input="true" is_node_valid="true" is_selected="{1}" is_storage_input="true" is_trigger_input="true" level-0="dont_care" name="{2}" pwr_level-0="dont_care" pwr_storage-0="dont_care" pwr_storage-1="dont_care" pwr_storage-2="dont_care" storage-0="dont_care" storage-1="dont_care" storage-2="dont_care" storage_index="{0}" tap_mode="classic" trigger_index="{0}" type="unknown"/>' -f $i, $selected, $signal
}

$netList = for ($i = 0; $i -lt $signals.Count; $i++) {
    $signal = Escape-XmlAttr $signals[$i]
    $selected = if ($signals[$i] -in @('u_counter|cout', 'wr_fifo_wrreq', 'rd_fifo_rdreq', 'u_uart_tx|tx_done')) { 'true' } else { 'false' }
    '          <net data_index="{0}" duplicate_name_allowed="false" is_data_input="true" is_node_valid="true" is_selected="{1}" is_storage_input="true" is_trigger_input="true" level-0="dont_care" name="{2}" pwr_level-0="dont_care" pwr_storage-0="dont_care" pwr_storage-1="dont_care" pwr_storage-2="dont_care" storage-0="dont_care" storage-1="dont_care" storage-2="dont_care" storage_index="{0}" tap_mode="classic" trigger_index="{0}" type="unknown"/>' -f $i, $selected, $signal
}

$ones = '1' * $signals.Count
$wireXml = $wireList -join [Environment]::NewLine
$nodeXml = $nodeList -join [Environment]::NewLine
$netXml = $netList -join [Environment]::NewLine

$xml = @"
<session jtag_chain="Please Select" jtag_device="" sof_file="">
  <display_tree gui_logging_enabled="0">
    <display_branch instance="task3_auto" log="USE_GLOBAL_TEMP" signal_set="USE_GLOBAL_TEMP" trigger="USE_GLOBAL_TEMP"/>
  </display_tree>
  <instance enabled="true" entity_name="sld_signaltap" is_auto_node="yes" is_expanded="true" name="task3_auto" source_file="sld_signaltap.vhd">
    <node_ip_info instance_id="0" mfg_id="110" node_id="0" version="6"/>
    <signal_set global_temp="1" is_expanded="true" name="signal_set: 2026/05/21 13:20:00 #0">
      <clock name="clk" polarity="posedge" tap_mode="classic"/>
      <config ram_type="AUTO" reserved_data_nodes="0" reserved_storage_qualifier_nodes="0" reserved_trigger_nodes="0" sample_depth="2048" trigger_in_enable="no" trigger_out_enable="no"/>
      <top_entity/>
      <signal_vec>
        <trigger_input_vec>
$wireXml
        </trigger_input_vec>
        <data_input_vec>
$wireXml
        </data_input_vec>
        <storage_qualifier_input_vec>
$wireXml
        </storage_qualifier_input_vec>
      </signal_vec>
      <presentation>
        <unified_setup_data_view>
$nodeXml
        </unified_setup_data_view>
        <data_view>
$netXml
        </data_view>
        <setup_view>
$netXml
        </setup_view>
        <trigger_in_editor/>
        <trigger_out_editor/>
      </presentation>
      <trigger CRC="00000000" attribute_mem_mode="false" gap_record="true" global_temp="1" is_expanded="true" name="trigger: 2026/05/21 13:20:00 #0" position="pre" power_up_trigger_mode="true" record_data_gap="true" segment_size="64" storage_mode="off" storage_qualifier_disabled="no" storage_qualifier_port_is_pin="false" storage_qualifier_port_name="auto_stp_external_storage_qualifier" storage_qualifier_port_tap_mode="classic" trigger_type="circular">
        <power_up_trigger position="pre" storage_qualifier_disabled="no"/>
        <events use_custom_flow_control="no">
          <level enabled="yes" name="condition1" type="basic">
            <power_up enabled="yes"></power_up><op_node/>
          </level>
        </events>
        <storage_qualifier_events>
          <transitional>$ones
            <pwr_up_transitional>$ones</pwr_up_transitional>
          </transitional>
          <storage_qualifier_level type="basic"><power_up></power_up><op_node/></storage_qualifier_level>
        </storage_qualifier_events>
      </trigger>
    </signal_set>
    <position_info>
      <single attribute="active tab" value="0"/>
      <single attribute="data horizontal scroll position" value="0"/>
      <single attribute="data vertical scroll position" value="0"/>
      <single attribute="setup horizontal scroll position" value="0"/>
      <single attribute="setup vertical scroll position" value="0"/>
      <single attribute="zoom level denominator" value="1"/>
      <single attribute="zoom level numerator" value="1"/>
      <single attribute="zoom offset denominator" value="1"/>
      <single attribute="zoom offset numerator" value="0"/>
    </position_info>
  </instance>
  <mnemonics/>
</session>
"@

Set-Content -LiteralPath $Output -Encoding ASCII -Value $xml
Write-Host "Generated $Output with $($signals.Count) SignalTap data bits."
