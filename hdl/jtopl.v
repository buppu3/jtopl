/*  This file is part of JTOPL.

    JTOPL is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTOPL is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTOPL.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 10-6-2020

    */

module jtopl(
    input                  rst,        // rst should be at least 6 clk&cen cycles long
    input                  clk,        // CPU clock
    input                  cen,        // optional clock enable, it not needed leave as 1'b1
    input           [ 7:0] din,
    input           [ 1:0] addr,
    input                  cs_n,
    input                  wr_n,
    output          [ 7:0] dout,
    output                 irq_n,
    // combined output
    output  signed  [OUTW-1:0] snd_a,
    output  signed  [OUTW-1:0] snd_b,
    output  signed  [OUTW-1:0] snd_c,
    output  signed  [OUTW-1:0] snd_d,
    output                 sample
);

parameter STATUS_BITS = 5'd6;
parameter OPL_TYPE=1;
parameter MODULE_COUNT = 1;
parameter SLOTS = 18;
parameter CHANNELS = 9;
parameter CH_WIDTH = 4;
parameter GROUP_WIDTH = 2;
parameter OP_WIDTH = 1;
parameter CON_WIDTH = 1;
parameter FB_WIDTH = 3;
parameter WAVESEL_WIDTH = 2;
parameter CLKDIV=2;
parameter MONO = 0;
parameter ACCW = 17;
parameter OUTW = 16;

wire                    cenop;
wire                    write;
wire  [GROUP_WIDTH-1:0] group;
wire  [SLOTS-1:0]       slot;
wire  [ 4:0]            trem;

// Timers
wire          flag_A[MODULE_COUNT-1:0], flag_B[MODULE_COUNT-1:0], flagen_A[MODULE_COUNT-1:0], flagen_B[MODULE_COUNT-1:0];
wire  [ 7:0]  value_A[MODULE_COUNT-1:0];
wire  [ 7:0]  value_B[MODULE_COUNT-1:0];
wire          load_A[MODULE_COUNT-1:0], load_B[MODULE_COUNT-1:0];
wire          clr_flag_A[MODULE_COUNT-1:0], clr_flag_B[MODULE_COUNT-1:0];
wire          overflow_A[MODULE_COUNT-1:0];
wire          w_irq_n[MODULE_COUNT-1:0];
wire          zero; // Single-clock pulse at the begginig of s1_enters

// Phase
wire  [ 9:0]  fnum_I;
wire  [ 2:0]  block_I;
wire  [ 3:0]  mul_II;
wire  [ 9:0]  phase_IV;
wire          pg_rst_II;
wire          note_sel_I;
wire          viben_I;
wire  [ 2:0]  vib_cnt;
// envelope configuration
wire          en_sus_I; // enable sustain
wire  [ 3:0]  keycode_II;
wire  [ 3:0]  arate_I; // attack  rate
wire  [ 3:0]  drate_I; // decay   rate
wire  [ 3:0]  rrate_I; // release rate
wire  [ 3:0]  sl_I;   // sustain level
wire          ksr_II;    // key scale rate - affects rates
wire  [ 1:0]  ksl_IV;   // key scale level - affects amplitude
// envelope operation
wire          keyon_I;
wire          eg_stop;
// envelope number
wire          amen_IV;
wire  [ 5:0]  tl_IV;
wire  [ 9:0]  eg_V;
//
wire          rhy_oen_I;
// Global values
wire          am_dep, vib_dep;
// Operator
wire  [FB_WIDTH-1:0]      fb_I;
wire  [WAVESEL_WIDTH-1:0] wavsel_I;
wire  [OP_WIDTH-1:0]      op;
wire  [CON_WIDTH-1:0]     con_I;
wire  [ 3:0]              dac_en_I, dac_en_out;
wire                      sum_en_out, rhy2x_out;
wire                      hh_en_I, sd_en_I, tc_en_I;
wire [7:0]                st[MODULE_COUNT-1:0];
wire                      new_en;

wire signed [12:0]        op_result;

assign          write   = !cs_n && !wr_n;
assign          st[0] = { ~w_irq_n[0], flag_A[0], flag_B[0], STATUS_BITS[4:0] };
assign          eg_stop = 0;

generate if(MODULE_COUNT > 1) begin
    assign st[1] = { ~w_irq_n[1], flag_A[1], flag_B[1], STATUS_BITS[4:0] };
    assign dout  = new_en ? st[0] : st[addr[1]];
    assign irq_n = new_en ? w_irq_n[0] : (w_irq_n[0] & w_irq_n[1]);
end else begin
    assign dout  = st[0];
    assign irq_n = w_irq_n[0];
end endgenerate

jtopl_mmr #(
    .OPL_TYPE(OPL_TYPE),
    .MODULE_COUNT(MODULE_COUNT),
    .SLOTS(SLOTS),
    .CHANNELS(CHANNELS),
    .CH_WIDTH(CH_WIDTH),
    .GROUP_WIDTH(GROUP_WIDTH),
    .OP_WIDTH(OP_WIDTH),
    .CON_WIDTH(CON_WIDTH),
    .FB_WIDTH(FB_WIDTH),
    .WAVESEL_WIDTH(WAVESEL_WIDTH),
    .CLKDIV(CLKDIV)
) u_mmr(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen           ),  // external clock enable
    .cenop      ( cenop         ),  // internal clock enable
    .din        ( din           ),
    .write      ( write         ),
    .addr       ( addr          ),
    .zero       ( zero          ),
    .group      ( group         ),
    .op         ( op            ),
    .slot       ( slot          ),
    // Timers
    .value_A    ( value_A       ),
    .value_B    ( value_B       ),
    .load_A     ( load_A        ),
    .load_B     ( load_B        ),
    .flagen_A   ( flagen_A      ),
    .flagen_B   ( flagen_B      ),
    .clr_flag_A ( clr_flag_A    ),
    .clr_flag_B ( clr_flag_B    ),
    .flag_A     ( flag_A        ),
    .overflow_A ( overflow_A    ),
    // Phase Generator
    .fnum_I     ( fnum_I        ),
    .block_I    ( block_I       ),
    .mul_II     ( mul_II        ),
    .note_sel_I ( note_sel_I    ),
    // Operator
    .wavsel_I   ( wavsel_I      ),
    // Envelope Generator
    .keyon_I    ( keyon_I       ),
    .en_sus_I   ( en_sus_I      ),
    .arate_I    ( arate_I       ),
    .drate_I    ( drate_I       ),
    .rrate_I    ( rrate_I       ),
    .sl_I       ( sl_I          ),
    .ks_II      ( ksr_II        ),
    .tl_IV      ( tl_IV         ),
    .ksl_IV     ( ksl_IV        ),
    .amen_IV    ( amen_IV       ),
    .viben_I    ( viben_I       ),
    // Global Values
    .am_dep     ( am_dep        ),
    .vib_dep    ( vib_dep       ),
    // Timbre
    .fb_I       ( fb_I          ),
    .con_I      ( con_I         ),
    //
    .dac_en_I   ( dac_en_I      ),
    .rhy_oen_I  ( rhy_oen_I     ),
    .hh_en_I    ( hh_en_I       ),
    .sd_en_I    ( sd_en_I       ),
    .tc_en_I    ( tc_en_I       ),
    //
    .new_en     ( new_en        )
);

jtopl_timers u_timers(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cenop      ( cenop         ),
    .zero       ( zero          ),
    .value_A    ( value_A[0]    ),
    .value_B    ( value_B[0]    ),
    .load_A     ( load_A[0]     ),
    .load_B     ( load_B[0]     ),
    .flagen_A   ( flagen_A[0]   ),
    .flagen_B   ( flagen_B[0]   ),
    .clr_flag_A ( clr_flag_A[0] ),
    .clr_flag_B ( clr_flag_B[0] ),
    .flag_A     ( flag_A[0]     ),
    .flag_B     ( flag_B[0]     ),
    .overflow_A ( overflow_A[0] ),
    .irq_n      ( w_irq_n[0]    )
);

generate if(MODULE_COUNT > 1) begin
jtopl_timers u_timers_2 (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cenop      ( cenop & ~new_en), // OPL3 モードの時はタイマー停止
    .zero       ( zero          ),
    .value_A    ( value_A[1]    ),
    .value_B    ( value_B[1]    ),
    .load_A     ( load_A[1]     ),
    .load_B     ( load_B[1]     ),
    .flagen_A   ( flagen_A[1]   ),
    .flagen_B   ( flagen_B[1]   ),
    .clr_flag_A ( clr_flag_A[1] ),
    .clr_flag_B ( clr_flag_B[1] ),
    .flag_A     ( flag_A[1]     ),
    .flag_B     ( flag_B[1]     ),
    .overflow_A ( overflow_A[1] ),
    .irq_n      ( w_irq_n[1]    )
);
end
endgenerate

jtopl_lfo #(
    .OPL_TYPE(OPL_TYPE),
    .SLOTS(SLOTS)
    //.CHANNELS(CHANNELS),
    //.CH_WIDTH(CH_WIDTH),
    //.GROUP_WIDTH(GROUP_WIDTH),
    //.OP_WIDTH(OP_WIDTH),
    //.CON_WIDTH(CON_WIDTH),
    //.FB_WIDTH(FB_WIDTH),
    //.WAVESEL_WIDTH(WAVESEL_WIDTH)
) u_lfo(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cenop      ( cenop         ),
    .slot       ( slot          ),
    .vib_cnt    ( vib_cnt       ),
    .trem       ( trem          )
);

jtopl_pg #(
    .OPL_TYPE(OPL_TYPE),
    .CHANNELS(CHANNELS)
    //.CH_WIDTH(CH_WIDTH),
    //.GROUP_WIDTH(GROUP_WIDTH),
    //.OP_WIDTH(OP_WIDTH),
    //.CON_WIDTH(CON_WIDTH),
    //.FB_WIDTH(FB_WIDTH),
    //.WAVESEL_WIDTH(WAVESEL_WIDTH)
) u_pg(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cenop      ( cenop         ),
    // Channel frequency
    .fnum_I     ( fnum_I        ),
    .block_I    ( block_I       ),
    //
    .note_sel_I ( note_sel_I    ),
    // Operator multiplying
    .mul_II     ( mul_II        ),
    // phase modulation from LFO (vibrato at 6.4Hz)
    .vib_cnt    ( vib_cnt       ),
    .vib_dep    ( vib_dep       ),
    .viben_I    ( viben_I       ),
    // phase operation
    .pg_rst_II  ( pg_rst_II     ),
    //
    .rhy_oen_I  ( rhy_oen_I     ),
    .hh_en_I    ( hh_en_I       ),
    .sd_en_I    ( sd_en_I       ),
    .tc_en_I    ( tc_en_I       ),
    
    .keycode_II ( keycode_II    ),
    .phase_IV   ( phase_IV      )
);

jtopl_eg #(
    //.OPL_TYPE(OPL_TYPE),
    .SLOTS(SLOTS)
    //.CHANNELS(CHANNELS),
    //.CH_WIDTH(CH_WIDTH),
    //.GROUP_WIDTH(GROUP_WIDTH),
    //.OP_WIDTH(OP_WIDTH),
    //.CON_WIDTH(CON_WIDTH),
    //.FB_WIDTH(FB_WIDTH),
    //.WAVESEL_WIDTH(WAVESEL_WIDTH)
) u_eg(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cenop      ( cenop         ),
    .zero       ( zero          ),
    .eg_stop    ( eg_stop       ),
    // envelope configuration
    .en_sus_I   ( en_sus_I      ), // enable sustain
    .keycode_II ( keycode_II    ),
    .arate_I    ( arate_I       ), // attack  rate
    .drate_I    ( drate_I       ), // decay   rate
    .rrate_I    ( rrate_I       ), // release rate
    .sl_I       ( sl_I          ), // sustain level
    .ksr_II     ( ksr_II        ), // key scale
    // envelope operation
    .keyon_I    ( keyon_I       ),
    // envelope number
    .fnum_I     ( fnum_I        ),
    .block_I    ( block_I       ),
    .lfo_mod    ( trem          ),
    .amsen_IV   ( amen_IV       ),
    .ams_IV     ( am_dep        ),
    .tl_IV      ( tl_IV         ),
    .ksl_IV     ( ksl_IV        ),
    .eg_V       ( eg_V          ),
    .pg_rst_II  ( pg_rst_II     )
);

jtopl_op #(
    .OPL_TYPE(OPL_TYPE),
    .GROUP_WIDTH(GROUP_WIDTH),
    .OP_WIDTH(OP_WIDTH),
    .CON_WIDTH(CON_WIDTH),
    .FB_WIDTH(FB_WIDTH),
    .WAVESEL_WIDTH(WAVESEL_WIDTH)
) u_op(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cenop      ( cenop         ),

    // location of current operator
    .group      ( group         ),
    .op         ( op            ),
    .zero       ( zero          ),

    .pg_phase_I ( phase_IV      ),
    .eg_atten_II( eg_V          ), // output from envelope generator
    .fb_I       ( fb_I          ), // voice feedback
    .wavsel_I   ( wavsel_I      ), // sine mask (OPL2)
    
    .rhy_oen_I  ( rhy_oen_I     ),
    .con_I      ( con_I         ),
    .dac_en_I   ( dac_en_I      ),
    .op_result  ( op_result     ),
    .dac_en_out ( dac_en_out    ),
    .sum_en_out ( sum_en_out    ),
    .rhy2x_out  ( rhy2x_out     )
);

jtopl_acc #(
    .OPL_TYPE(OPL_TYPE),
    .OP_WIDTH(OP_WIDTH),
    .CON_WIDTH(CON_WIDTH),
    .MONO(MONO),
    .ACCW(ACCW),
    .OUTW(OUTW)
)u_acc(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cenop      ( cenop         ),
    .zero       ( slot[2+6]     ),
    .rhy2x      ( rhy2x_out     ),
    .op_result  ( op_result     ),
    .dac_en     ( dac_en_out    ),
    .sum_en     ( sum_en_out    ),
    .snd_a      ( snd_a         ),
    .snd_b      ( snd_b         ),
    .snd_c      ( snd_c         ),
    .snd_d      ( snd_d         ),
    .sample     ( sample        )
);

`ifdef SIMULATION
integer fsnd;
initial begin
    fsnd=$fopen("jtopl.raw","wb");
end

always @(posedge zero) begin
    $fwrite(fsnd,"%u", {snd, snd});
end
`endif

endmodule
    