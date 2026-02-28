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

module jtopl_mmr(
    input               rst,
    input               clk,
    input               cen,
    output              cenop,
    input       [ 7:0]  din,
    input               write,
    input       [1:0]   addr,
    // location
    output                        zero,
    output      [GROUP_WIDTH-1:0] group,
    output      [OP_WIDTH-1:0]    op,
    output      [SLOTS-1:0]       slot,
    // Timers
    output  reg [ 7:0]  value_A[MODULE_COUNT-1:0],
    output  reg [ 7:0]  value_B[MODULE_COUNT-1:0],
    output  reg         load_A[MODULE_COUNT-1:0],
    output  reg         load_B[MODULE_COUNT-1:0],
    output  reg         flagen_A[MODULE_COUNT-1:0],
    output  reg         flagen_B[MODULE_COUNT-1:0],
    output  reg         clr_flag_A[MODULE_COUNT-1:0],
    output  reg         clr_flag_B[MODULE_COUNT-1:0],
    input               flag_A[MODULE_COUNT-1:0],
    input               overflow_A[MODULE_COUNT-1:0],
    // Phase Generator
    output      [ 9:0]  fnum_I,
    output      [ 2:0]  block_I,
    output      [ 3:0]  mul_II,
    output              viben_I,
    output              note_sel_I,
    // Operator
    output      [WAVESEL_WIDTH-1:0] wavsel_I,
    // Envelope Generator
    output              keyon_I,
    output              en_sus_I, // enable sustain
    output      [ 3:0]  arate_I,  // attack  rate
    output      [ 3:0]  drate_I,  // decay   rate
    output      [ 3:0]  rrate_I,  // release rate
    output      [ 3:0]  sl_I,     // sustain level
    output              ks_II,    // key scale
    output      [ 5:0]  tl_IV,
    output              amen_IV,
    // global values
    output              am_dep,
    output              vib_dep,
    output      [ 1:0]  ksl_IV,
    // Operator configuration
    output      [FB_WIDTH-1:0]  fb_I,
    output      [CON_WIDTH-1:0] con_I,
    //
    output      [ 3:0]          dac_en_I,
    output                      rhy_oen_I,
    output                      hh_en_I,
    output                      sd_en_I,
    output                      tc_en_I,
    //
    output  reg                 new_en
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
parameter CLKDIV=2;

jtopl_div #(
    .OPL_TYPE(OPL_TYPE),
    .CLKDIV(CLKDIV)
) u_div  (
    .rst            ( rst             ),
    .clk            ( clk             ),
    .cen            ( cen             ),
    .cenop          ( cenop           )
);

localparam [8:0] REG_TESTYM  = 9'h001,
                 REG_CLKA    = 9'h002,
                 REG_CLKA_2  = 9'h102,
                 REG_CLKB    = 9'h003,
                 REG_CLKB_2  = 9'h103,
                 REG_TIMER   = 9'h004,
                 REG_TIMER_2 = 9'h104,
                 REG_CSM     = 9'h008,
                 REG_CSM_2   = 9'h108,
                 REG_RYTHM   = 9'h0BD,
                 REG_RYTHM_2 = 9'h1BD,
                 REG_NEW     = 9'h105,
                 REG_CONSEL  = 9'h104;

reg  [ 8:0]            selreg;       // selected register
reg  [ 7:0]            din_copy;
reg                    csm, effect;
reg  [CH_WIDTH-1:0]    sel_ch;
reg  [GROUP_WIDTH-1:0] sel_group;     // group to update
reg  [ 2:0]            sel_sub;       // subslot to update
reg                    up_fnumlo, up_fnumhi, up_fbcon,
                       up_mult, up_ksl_tl, up_ar_dr, up_sl_rr,
                       up_wav;
reg                    wave_mode,     // 1 if waveform selection is enabled (OPL2)
                       reg_csm_en[MODULE_COUNT-1:0],
                       reg_note_sel[MODULE_COUNT-1:0];  // keyboard split, not implemented
reg                    rhy_en[MODULE_COUNT-1:0];
reg  [ 4:0]            rhy_kon[MODULE_COUNT-1:0];
reg  [ 5:0]            consel;
reg                    wrt_en;
reg                    reg_am_dep[MODULE_COUNT-1:0];
reg                    reg_vib_dep[MODULE_COUNT-1:0];

`ifdef SIMULATION
always @(posedge clk) if( write && rst ) begin
    $display("WARNING [JTOPL]: detected write request while in reset.\nThis is likely a glue-logic error in the CPU-FM module.");
    $finish;
end

integer fdump,line_cnt=0;
initial begin
    fdump=$fopen("opl_wr.log","w");
    if( fdump==0 ) begin
        $display("Cannot create opl_wr.log");
        $finish;
    end
end
always @(posedge write) if(addr[0]) begin
    $fdisplay(fdump,"%d,%X,%X",line_cnt,selreg,din);
    line_cnt <= line_cnt+1;
end
`endif

// this runs at clk speed, no clock gating here
// if I try to make this an async rst it fails to map it
// as flip flops but uses latches instead. So I keep it as sync. reset
always @(posedge clk) begin
    if( rst ) begin
        selreg    <= 8'h0;
        sel_group <= 2'd0;
        sel_ch    <= 0;
        sel_sub   <= 3'd0;
        // Updaters
        up_fbcon  <= 0;
        up_fnumlo <= 0;
        up_fnumhi <= 0;
        up_mult   <= 0;
        up_ksl_tl <= 0;
        up_ar_dr  <= 0;
        up_sl_rr  <= 0;
        up_wav    <= 0;
        // Rhythms
        rhy_en[0]  <= 0;
        rhy_kon[0] <= 5'd0;
        // sensitivity to LFO
        reg_am_dep  [0] <= 0;
        reg_vib_dep [0] <= 0;
        reg_csm_en  [0] <= 0;
        reg_note_sel[0] <= 0;
        // OPL2 waveforms
        wave_mode <= 0;
        // timers
        { value_A[0], value_B[0] } <= 16'd0;
        { clr_flag_B[0], clr_flag_A[0], load_B[0], load_A[0] } <= 4'd0;
        flagen_A[0]   <= 1;
        flagen_B[0]   <= 1;

        din_copy   <= 8'd0;
        //
        wrt_en <= 0;
        new_en <= 0;
        consel <= 0;
        //
        if(MODULE_COUNT > 1) begin
            rhy_en      [1] <= 0;
            rhy_kon     [1] <= 5'd0;
            reg_am_dep  [1] <= 0;
            reg_vib_dep [1] <= 0;
            reg_csm_en  [1] <= 0;
            reg_note_sel[1] <= 0;
            { value_A[1], value_B[1] } <= 16'd0;
            { clr_flag_B[1], clr_flag_A[1], load_B[1], load_A[1] } <= 4'd0;
            flagen_A[1]   <= 1;
            flagen_B[1]   <= 1;
        end
    end else begin
        // WRITE IN REGISTERS
        if( write ) begin
            if( !addr[0] ) begin
                selreg <= {addr[1], din};
                wrt_en <= ~addr[0] | new_en | ({addr[1], din} == REG_NEW) || (MODULE_COUNT > 1);
            end else begin
                // Global registers
                din_copy  <= din;
                up_fnumhi <= 0;
                up_fnumlo <= 0;
                up_fbcon  <= 0;
                up_mult   <= 0;
                up_ksl_tl <= 0;
                up_ar_dr  <= 0;
                up_sl_rr  <= 0;
                up_wav    <= 0;

                // General control (<0x20 registers)
                if(wrt_en) begin
                    casez( selreg )
                        REG_TESTYM: if(OPL_TYPE>1) wave_mode <= din[5];
                        REG_CLKA:   value_A[0] <= din;
                        REG_CLKA_2: if(MODULE_COUNT > 1 && !new_en) value_A[1] <= din;
                        REG_CLKB:   value_B[0] <= din;
                        REG_CLKB_2: if(MODULE_COUNT > 1 && !new_en) value_B[1] <= din;
                        REG_TIMER: begin
                            clr_flag_A[0] <= din[7] | din[6];
                            clr_flag_B[0] <= din[7] | din[5];
                            if (~din[7]) begin
                                flagen_A[0]   <= ~din[6];
                                flagen_B[0]   <= ~din[5];
                                { load_B[0], load_A[0]   } <= din[1:0];
                            end
                        end
                        REG_CONSEL:if(new_en) begin
                            consel <= din[5:0];
                        end
                        else if(MODULE_COUNT > 1 && !new_en) begin
                            clr_flag_A[1] <= din[7] | din[6];
                            clr_flag_B[1] <= din[7] | din[5];
                            if (~din[7]) begin
                                flagen_A[1]   <= ~din[6];
                                flagen_B[1]   <= ~din[5];
                                { load_B[1], load_A[1]   } <= din[1:0];
                            end
                        end
                        REG_CSM:   {reg_csm_en[0], reg_note_sel[0]} <= din[7:6];
                        REG_CSM_2: if(MODULE_COUNT > 1 && !new_en) {reg_csm_en[1], reg_note_sel[1]} <= din[7:6];
                        REG_NEW:   new_en <= din[0];
                        default:;
                    endcase
                end

                // Operator registers
                // Mapping done according to Table 2-3, page 7 of YM3812 App. Manual
                if( selreg[7:0] >= 8'h20 &&
                    (selreg[7:0] < 8'hA0 || (selreg[7:0]>=8'hE0 && OPL_TYPE>1) ) &&
                    selreg[2:0]<=3'd5 && selreg[4:3]!=2'b11) begin
                    if( OPL_TYPE == 3) begin
                        sel_group <= selreg[8] ? (selreg[4:3] + 3) : selreg[4:3];
                    end
                    else begin
                        sel_group <= selreg[4:3];
                    end
                    sel_sub   <= selreg[2:0];
                    case( selreg[7:5] )
                        3'b001: up_mult   <= wrt_en;
                        3'b010: up_ksl_tl <= wrt_en;
                        3'b011: up_ar_dr  <= wrt_en;
                        3'b100: up_sl_rr  <= wrt_en;
                        3'b111: up_wav    <= OPL_TYPE!=1 && wrt_en;
                        default:;
                    endcase
                end

                // Channel registers
                if( selreg[3:0]<=4'd8) begin
                    case( selreg[7:4] )
                        4'hA: up_fnumlo <= wrt_en;
                        4'hB: up_fnumhi <= wrt_en;
                        4'hC: up_fbcon  <= wrt_en;
                        default:;
                    endcase
                end
                if( selreg[7:4]>=4'hA && selreg[7:4]<4'hd
                    && selreg[3:0]<=8 ) begin
                    // Each group has three channels
                    // Channels 0-2 -> group 0
                    // Channels 3-5 -> group 1
                    // Channels 6-8 -> group 2
                    // other        -> group 3 - ignored
                    if( OPL_TYPE == 3) begin
                        sel_ch    <= selreg[8] ? (selreg[3:0] + 4'd9) : selreg[3:0];
                        case ({selreg[8], selreg[3:0]})
                            5'b0_0000: sel_group <= 3'd0;
                            5'b0_0001: sel_group <= 3'd0;
                            5'b0_0010: sel_group <= 3'd0;
                            5'b0_0011: sel_group <= 3'd1;
                            5'b0_0100: sel_group <= 3'd1;
                            5'b0_0101: sel_group <= 3'd1;
                            5'b0_0110: sel_group <= 3'd2;
                            5'b0_0111: sel_group <= 3'd2;
                            5'b0_1000: sel_group <= 3'd2;
                            5'b1_0000: sel_group <= 3'd3;
                            5'b1_0001: sel_group <= 3'd3;
                            5'b1_0010: sel_group <= 3'd3;
                            5'b1_0011: sel_group <= 3'd4;
                            5'b1_0100: sel_group <= 3'd4;
                            5'b1_0101: sel_group <= 3'd4;
                            5'b1_0110: sel_group <= 3'd5;
                            5'b1_0111: sel_group <= 3'd5;
                            5'b1_1000: sel_group <= 3'd5;
                            default:   sel_group <= 3'd6;
                        endcase
                    end
                    else begin
                        sel_ch    <= selreg[3:0];
                        sel_group <= selreg[3:0] < 4'd3 ? 2'd0 :
                                     selreg[3:0] < 4'd6 ? 2'd1 :
                                     selreg[3:0] < 4'd9 ? 2'd2 : 2'd3;
                    end
                    sel_sub <= selreg[3:0] < 4'd6 ? selreg[2:0] :
                        { 1'b0, ~&selreg[2:1], selreg[0] };
                end

                // Global register
                if( selreg==REG_RYTHM ) begin
                    reg_am_dep [0] <= din[7];
                    reg_vib_dep[0] <= din[6];
                    rhy_en     [0] <= din[5];
                    rhy_kon    [0] <= din[4:0];
                end
                else if(MODULE_COUNT > 1 && !new_en && selreg == REG_RYTHM_2) begin
                    reg_am_dep [1] <= din[7];
                    reg_vib_dep[1] <= din[6];
                    rhy_en     [1] <= din[5];
                    rhy_kon    [1] <= din[4:0];
                end
            end
        end
        else if(cenop) begin /* clear once-only bits */
            { clr_flag_B[0], clr_flag_A[0] } <= 2'd0;
        end
    end
end

jtopl_reg #(
    .OPL_TYPE(OPL_TYPE),
    .MODULE_COUNT(MODULE_COUNT),
    .SLOTS(SLOTS),
    .CHANNELS(CHANNELS),
    .CH_WIDTH(CH_WIDTH),
    .GROUP_WIDTH(GROUP_WIDTH),
    .OP_WIDTH(OP_WIDTH),
    .CON_WIDTH(CON_WIDTH),
    .FB_WIDTH(FB_WIDTH),
    .WAVESEL_WIDTH(WAVESEL_WIDTH)
) u_reg(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cenop         ),
    .din        ( din_copy      ),
    .write      ( write         ),
    // Pipeline order
    .zero       ( zero          ),
    .group      ( group         ),
    .op         ( op            ),
    .slot       ( slot          ),

    .sel_ch     ( sel_ch        ),
    .sel_group  ( sel_group     ),     // group to update
    .sel_sub    ( sel_sub       ),     // subslot to update

    .consel     ( consel        ),
    .new_en     ( new_en        ),

    .rhy_en     ( rhy_en        ),
    .rhy_kon    ( rhy_kon       ),

    //input           csm,
    //input           flag_A,
    //input           overflow_A,

    .up_fbcon   ( up_fbcon      ),
    .up_fnumlo  ( up_fnumlo     ),
    .up_fnumhi  ( up_fnumhi     ),

    .up_mult    ( up_mult       ),
    .up_ksl_tl  ( up_ksl_tl     ),
    .up_ar_dr   ( up_ar_dr      ),
    .up_sl_rr   ( up_sl_rr      ),
    .up_wav     ( up_wav        ),

    // PG
    .fnum_I     ( fnum_I        ),
    .block_I    ( block_I       ),
    .mul_II     ( mul_II        ),
    .viben_I    ( viben_I       ),
    // OP
    .wavsel_I   ( wavsel_I      ),
    .wave_mode  ( wave_mode     ),
    // EG
    .keyon_I    ( keyon_I       ),
    .en_sus_I   ( en_sus_I      ),
    .arate_I    ( arate_I       ),
    .drate_I    ( drate_I       ),
    .rrate_I    ( rrate_I       ),
    .sl_I       ( sl_I          ),
    .ks_II      ( ks_II         ),
    .ksl_IV     ( ksl_IV        ),
    .amen_IV    ( amen_IV       ),
    .tl_IV      ( tl_IV         ),
    // Timbre - Neiro
    .fb_I       ( fb_I          ),
    .con_I      ( con_I         ),

    .dac_en_I   ( dac_en_I      ),
    .rhy_oen_I  ( rhy_oen_I     ),
    .hh_en_I    ( hh_en_I       ),
    .sd_en_I    ( sd_en_I       ),
    .tc_en_I    ( tc_en_I       ),

    .am_dep     ( reg_am_dep    ),
    .vib_dep    ( reg_vib_dep   ),
    .am_dep_I   ( am_dep        ),
    .vib_dep_I  ( vib_dep       )
);

generate
if(MODULE_COUNT > 1) assign note_sel_I = (new_en || group < 3) ? reg_note_sel[0] : reg_note_sel[1];
else                 assign note_sel_I = reg_note_sel[0];
endgenerate

endmodule
