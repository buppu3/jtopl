/* This file is part of JTOPL

    JTOPL program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTOPL program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTOPL.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-6-2020 

*/

module jtopl_reg(
    input                      rst,
    input                      clk,
    input                      cen,
    input  [7:0]               din,
    input                      write,
    // Pipeline order
    output                     zero,
    output [GROUP_WIDTH-1:0]   group,
    output [OP_WIDTH-1:0]      op,          // 0 for modulator operators
    output [SLOTS-1:0]         slot,        // hot one encoding of active slot
    
    input  [CH_WIDTH-1:0]      sel_ch,      // channel to update
    input  [GROUP_WIDTH-1:0]   sel_group,   // group to update
    input  [2:0]               sel_sub,     // subslot to update

    input  [5:0]               consel,
    input                      new_en,

    input                      rhy_en[MODULE_COUNT-1:0],  // rhythm enable
    input                [4:0] rhy_kon[MODULE_COUNT-1:0], // key-on for each rhythm instrument

    //input           csm,
    //input           flag_A,
    //input           overflow_A,

    input                      up_fbcon,
    input                      up_fnumlo,
    input                      up_fnumhi,
    input                      up_mult,
    input                      up_ksl_tl,
    input                      up_ar_dr,
    input                      up_sl_rr,
    input                      up_wav,
    
    // PG
    output               [9:0] fnum_I,
    output               [2:0] block_I,
    // channel configuration
    output [FB_WIDTH-1:0]      fb_I,
    
    output               [3:0] mul_II,  // frequency multiplier
    output               [1:0] ksl_IV,  // key shift level
    output                     amen_IV,
    output                     viben_I,
    // OP
    output [WAVESEL_WIDTH-1:0] wavsel_I,
    input                      wave_mode,
    // EG
    output           keyon_I,
    output     [5:0] tl_IV,
    output           en_sus_I, // enable sustain
    output     [3:0] arate_I,  // attack  rate
    output     [3:0] drate_I,  // decay   rate
    output     [3:0] rrate_I,  // release rate
    output     [3:0] sl_I,     // sustain level
    output           ks_II,    // key scale
    output     [CON_WIDTH-1:0] con_I,
    output     [3:0]           dac_en_I,
    output                     hh_en_I,
    output                     sd_en_I,
    output                     tc_en_I,
    output                     rhy_oen_I,
    input                      am_dep[MODULE_COUNT-1:0],
    input                      vib_dep[MODULE_COUNT-1:0],
    output                     am_dep_I,
    output                     vib_dep_I
);

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

localparam CH=CHANNELS;

wire [2:0] subslot;
               
wire       bd0_en_I;
wire       update_op_I  = !write && sel_group == group && sel_sub == subslot;
reg        update_op_II, update_op_III, update_op_IV;

jtopl_slot_cnt #(
    .OPL_TYPE(OPL_TYPE),
    .SLOTS(SLOTS),
    //.CHANNELS(CHANNELS),
    //.CH_WIDTH(CH_WIDTH),
    .GROUP_WIDTH(GROUP_WIDTH),
    .OP_WIDTH(OP_WIDTH)
    //.CON_WIDTH(CON_WIDTH),
    //.FB_WIDTH(FB_WIDTH)
    //.WAVESEL_WIDTH(WAVESEL_WIDTH)
) u_slot_cnt(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen       ),
    .consel     ( consel    ),
    .new_en     ( new_en    ),

    // Pipeline order
    .zero       ( zero      ),
    .group      ( group     ),
    .op         ( op        ),   // 0 for modulator operators
    .subslot    ( subslot   ),
    .slot       ( slot      )    // hot one encoding of active slot
);

always @(posedge clk) begin
    if(write) begin
        update_op_II   <= 0;
        update_op_III  <= 0;
        update_op_IV   <= 0;
    end else if( cen ) begin
        update_op_II   <= update_op_I;
        update_op_III  <= update_op_II;
        update_op_IV   <= update_op_III;
    end
end

localparam OPCFGW = 4*8 + (OPL_TYPE!=1 ? WAVESEL_WIDTH : 0);

wire [OPCFGW-1:0] shift_out;
wire              en_sus;

// Sustained is disabled in rhythm mode for channels in group 2 (i.e. 6,7,8)
assign            en_sus_I = rhy_oen_I ? 1'b0 : en_sus;

jtopl_csr #(.LEN(CH*2),.W(OPCFGW), .OPL_TYPE(OPL_TYPE), .WAVESEL_WIDTH(WAVESEL_WIDTH)) u_csr(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen            ( cen           ),
    .din            ( din           ),
    .shift_out      ( shift_out     ),
    .up_mult        ( up_mult       ),
    .up_ksl_tl      ( up_ksl_tl     ),
    .up_ar_dr       ( up_ar_dr      ),
    .up_sl_rr       ( up_sl_rr      ), 
    .up_wav         ( up_wav        ),
    .update_op_I    ( update_op_I   ),
    .update_op_II   ( update_op_II  ),
    .update_op_IV   ( update_op_IV  )
);

assign { amen_IV, viben_I, en_sus, ks_II, mul_II,
         ksl_IV, tl_IV,
         arate_I, drate_I, 
         sl_I, rrate_I  } = shift_out[4*8-1:0];

generate
    wire [WAVESEL_WIDTH-1:0] wavemask;
    assign wavsel_I = shift_out[OPCFGW-1:OPCFGW-WAVESEL_WIDTH] & wavemask;

    if( OPL_TYPE==1 )
        assign mavemask = 0;
    else if( OPL_TYPE==3 )
        assign wavemask = {new_en, wave_mode, wave_mode};
    else
        assign wavemask = {WAVESEL_WIDTH{wave_mode}};
endgenerate

// Memory for CH registers
wire                 pre_keyon, rhyon_csr;
wire [CON_WIDTH-1:0] pre_con;
wire                 disable_con;

assign disable_con = rhy_oen_I && !bd0_en_I && !hh_en_I;
assign con_I       = !rhy_oen_I || !disable_con ? pre_con : 1'b1;
assign keyon_I = rhy_oen_I ? rhyon_csr : pre_keyon;

jtopl_reg_ch #(
    .OPL_TYPE(OPL_TYPE),
    .MODULE_COUNT(MODULE_COUNT),
    .SLOTS(SLOTS),
    .CHANNELS(CHANNELS),
    .CH_WIDTH(CH_WIDTH),
    .GROUP_WIDTH(GROUP_WIDTH),
    //.OP_WIDTH(OP_WIDTH),
    .CON_WIDTH(CON_WIDTH),
    .FB_WIDTH(FB_WIDTH)
    //.WAVESEL_WIDTH(WAVESEL_WIDTH)
) u_reg_ch(
    .rst         ( rst          ),
    .clk         ( clk          ),
    .cen         ( cen          ),
    .zero        ( zero         ),
    .rhy_en      ( rhy_en       ),
    .rhy_kon     ( rhy_kon      ),
    .slot        ( slot         ),

    .din         ( din          ),
    .up_ch       ( sel_ch       ),
    .up_fnumhi   ( up_fnumhi    ),
    .up_fnumlo   ( up_fnumlo    ),
    .up_fbcon    ( up_fbcon     ),

    .group       ( group        ),
    .sub         ( subslot      ),
    .consel      ( consel       ),
    .new_en      ( new_en       ),

    .fnum        ( fnum_I       ),
    .block       ( block_I      ),
    .con         ( pre_con      ),
    .dac_en      ( dac_en_I     ),
    .fb          ( fb_I         ),
    .keyon       ( pre_keyon    ),
    .rhy_oen     ( rhy_oen_I    ),
    .bd0_en      ( bd0_en_I     ),
    .hh_en       ( hh_en_I      ),
    .sd_en       ( sd_en_I      ),
    .tc_en       ( tc_en_I      ),
    .rhyon_csr   ( rhyon_csr    ),
    .am_dep      ( am_dep       ),
    .vib_dep     ( vib_dep      ),
    .am_dep_I    ( am_dep_I     ),
    .vib_dep_I   ( vib_dep_I    )
);

endmodule
